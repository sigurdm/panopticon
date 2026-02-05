import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:html/dom.dart';
import 'package:http/http.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:html/parser.dart' as parser;
import 'package:pana/models.dart';
import 'package:panopticon/panopticon.dart';
import 'package:panopticon/utils.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:pana/src/repository/repository_url_parser.dart';

const statusFilename = 'single_package_convention.json';

main(List<String> args) async {
  final db = await analyze(
    columns: ['breaksConvention', 'filename'],
    'single_package_convention',
    (packageName) async {
      final packagePath = p.join('..', 'all_latest_version', packageName);
      if (!Directory(p.join(packagePath, 'lib')).existsSync()) {
        return [
          [false, null],
        ];
      }

      final publicFiles = (await Directory(
            p.join(packagePath, 'lib'),
          ).list(recursive: true).toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final breaksConvention =
          (publicFiles.length == 1 &&
              !publicFiles.single.path.endsWith('/$packageName.dart'));
      return [
        [
          breaksConvention,
          breaksConvention ? p.basename(publicFiles.single.path) : null,
        ],
      ];
    },
    resetData: args.contains('--reset'),
    retryFailed: args.contains('--retry'),
    await allPackageNames(Client()),
  );

  final a = db.select('''
select count(*) from single_package_convention where breaksConvention = true
''');
  print(a.first);
  db.dispose();
}
