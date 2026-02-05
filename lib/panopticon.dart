import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:console/console.dart' as console;
import 'package:pool/pool.dart';
import 'package:sqlite3/sqlite3.dart';

class Itemized {
  final List<PoolResource?> op = [];

  int insert(PoolResource r) {
    for (var i = 0; i < op.length; i++) {
      if (op[i] == null) {
        op[i] = r;
        return i;
      }
    }
    op.add(r);
    return op.length - 1;
  }

  void release(PoolResource r) {
    for (var i = 0; i < op.length; i++) {
      if (identical(op[i], r)) {
        op[i] = null;
        return;
      }
    }
  }
}

Future<Database> analyze(
  String jobName,
  Future<List<List<Object?>>> Function(String task) fn,
  Iterable<String> tasks, {
  int parallelism = 10,
  Duration? taskTimeout = const Duration(seconds: 30),
  bool resetData = false,
  bool retryFailed = false,
  List<String> columns = const ['result'],
  List<String> primaryKeys = const [],
  String? dbname,
}) async {
  final scriptname = Platform.script.pathSegments.last;

  final db = sqlite3.open(dbname ?? scriptname.replaceAll('.dart', '.sqlite'));
  final pool = Pool(parallelism, timeout: taskTimeout);
  final itemized = Itemized();
  final alreadyDone = <String>{};
  final error = <String>{};

  var last = 0;
  final stopwatch = Stopwatch()..start();
  final timer =
      stdout.hasTerminal
          ? Timer.periodic(Duration(seconds: 2), (timer) async {
            final doneSinceLast = alreadyDone.length - last;
            console.Cursor().save();
            String length = '';
            String eta = '';
            if (tasks is List) {
              length = '/${tasks.length}';
              final etaS =
                  doneSinceLast == 0
                      ? 0
                      : (tasks.length - alreadyDone.length) ~/
                          doneSinceLast *
                          2;
              final etaDuration = Duration(seconds: etaS);
              eta =
                  ' Eta ${etaDuration.inHours.toString().padLeft(2, '0')}:${(etaDuration.inMinutes % 60).toString().padLeft(2, '0')}:${etaDuration.inSeconds % 60}';
            }
            console.Cursor().write(
              '$jobName: ${alreadyDone.length}$length, ${error.length} errors. ${doneSinceLast / 2} j/s - Elapsed: ${stopwatch.elapsed.inSeconds}s.$eta'
                  .padRight(stdout.terminalColumns),
            );
            console.Cursor().restore();
            last = alreadyDone.length;
          })
          : null;

  db.execute('PRAGMA journal_mode=WAL;');
  if (resetData) {
    db.execute('''
drop table if exists $jobName ;
''');
  }
  db.execute('''
create table if not exists $jobName (
  name text,
  ${columns.map((c) => '$c').join(',\n')},
  error text,
  primary key (name${primaryKeys.isEmpty ? '' : ', ' + primaryKeys.join(', ')})
  )
''');
  final insertQuery = db.prepare(
    'insert or REPLACE into $jobName (name, ${columns.join(', ')}) values (?, ${columns.map((x) => '?').join(', ')});',
  );

  final doneTaskRows = db.select('select name, error from $jobName');
  for (final doneTask in doneTaskRows) {
    final taskName = doneTask.values[0] as String;
    if (doneTask.values[1] == null || retryFailed) {
      alreadyDone.add(taskName);
    }
    if (doneTask.values[1] != null) {
      error.add(taskName);
    }
  }
  if (stdout.hasTerminal) {
    for (var i = 0; i < parallelism + 1; i++) {
      print('');
    }
  }
  try {
    for (final task in tasks) {
      if (alreadyDone.contains(task)) continue;
      final resource = await pool.request();
      final item = itemized.insert(resource);
      scheduleMicrotask(() async {
        try {
          if (stdout.hasTerminal) {
            console.Cursor().save();

            console.Cursor().moveUp(itemized.op.length - item);
            console.Cursor().write(task.padRight(stdout.terminalColumns));
            console.Cursor().restore();
          }
          final t = await fn(task);
          for (final row in t) {
            insertQuery.execute([
              task,
              ...row.map((v) => v is int || v is String ? v : jsonEncode(v)),
            ]);
          }
        } catch (e, st) {
          db.execute(
            '''
insert or REPLACE into $jobName (name, error) values (?, ?)
''',
            [task, '$e\n$st'],
          );
        } finally {
          resource.release();
          itemized.release(resource);
          alreadyDone.add(task);
        }
      });
    }
  } finally {
    await pool.close();
    timer?.cancel();
    insertQuery.dispose();
  }
  print(
    '${stopwatch.elapsed.inSeconds} seconds. ${alreadyDone.length} tasks. ${error.length} errors.',
  );
  return db;
}
