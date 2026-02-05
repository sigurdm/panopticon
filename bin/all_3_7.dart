import 'dart:convert';
import 'dart:io';
import 'package:panopticon/panopticon.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  var problem = 0;
  var all = 0;
  var error = 0;

  final tasks =
      Directory('../all_latest_version').listSync().map((d) => d.path).toList();

  final db = await analyze(
    'has_3_7',
    resetData: args.contains('--reset'),
    retryFailed: args.contains('--retry'),
    (task) async {
      print(task);
      final pubspec = loadYaml(
        File(p.join(task, 'pubspec.yaml')).readAsStringSync(),
      );
      final constraint =
          VersionConstraint.parse(pubspec['environment']['sdk'] as String)
              as VersionRange;
      if ((constraint.min!.minor == 7) && (constraint.min!.major == 3)) {
        return [[true]];
      } else {
        return [[false]];
      }
    },
    tasks,
  );
  final a = db.select('''
select count(*) from has_3_7 where result ->> '\$'
''');
  print(a.first);
  db.dispose();
}
