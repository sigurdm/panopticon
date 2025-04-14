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
  Future<Object?> Function(String task) fn,
  Iterable<String> tasks, {
  int parallelism = 10,
  Duration? taskTimeout = const Duration(seconds: 30),
  bool resetData = false,
  bool retryFailed = false,
}) async {
  final scriptname = Platform.script.pathSegments.last;

  final db = sqlite3.open(scriptname.replaceAll('.dart', '.sqlite'));
  final pool = Pool(parallelism, timeout: taskTimeout);
  final itemized = Itemized();
  final alreadyDone = <String>{};
  final error = <String>{};

  var last = 0;

  final timer =
      stdout.hasTerminal
          ? Timer.periodic(Duration(seconds: 2), (timer) async {
            final doneSinceLast = alreadyDone.length - last;
            console.Cursor().save();
            console.Cursor().write(
              '$jobName: ${alreadyDone.length} out of ${tasks.length}. ${error.length} errors ${doneSinceLast / 2} jobs per second'
                  .padRight(stdout.terminalColumns),
            );
            console.Cursor().restore();
            last = alreadyDone.length;
          })
          : null;

  db.execute('PRAGMA journal_mode=WAL;');
  if (resetData) {
    db.execute('''
drop table $jobName ;
''');
  }
  db.execute('''
create table if not exists $jobName (
  name text primary key,
  result text,
  error text
  )
''');
  final doneTaskRows = db.select('select name, error, result from $jobName');
  for (final doneTask in doneTaskRows) {
    final taskName = doneTask.values[0] as String;
    if (doneTask.values[1] == null || retryFailed) {
      alreadyDone.add(taskName);
    }
    if (doneTask.values[1] != null) {
      error.add(taskName);
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
            console.Cursor().moveUp(item + 1);
            console.Cursor().write(task.padRight(stdout.terminalColumns));
            console.Cursor().restore();
          }
          final t = await fn(task);
          db.execute(
            '''
insert into $jobName (name, result) values (?, ?)
''',
            [task, jsonEncode(t)],
          );
        } catch (e) {
          db.execute(
            '''
insert into $jobName (name, error) values (?, ?)
''',
            [task, e.toString()],
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
  }
  return db;
}
