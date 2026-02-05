import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:html/parser.dart' as parser;
import 'package:pana/models.dart';
import 'package:panopticon/panopticon.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import 'package:pana/src/repository/repository_url_parser.dart';

const statusFilename = 'validate_format_status.json';

main(List<String> args) async {
  final db = await analyze(
    'validate_images',
    (path) async {
      final pubspec = loadYaml(
        File(p.join(path, 'pubspec.yaml')).readAsStringSync(),
      );
      final sdkConstraint =
          VersionConstraint.parse(pubspec['environment']['sdk'])
              as VersionRange;
      if (sdkConstraint.min?.major == 3 && sdkConstraint.min?.minor == 7) {
        final result = await Process.run(
          '/usr/local/google/home/sigurdm/projects/dart-sdk/sdk/out/ReleaseX64/dart-sdk/bin/dart',
          ['format', '--set-exit-if-changed'],
          workingDirectory: path,
        );

        return [
          [result.exitCode],
        ];
      } else {
        throw "Wrong sdk version";
      }
    },
    resetData: args.contains('--reset'),
    retryFailed: args.contains('--retry'),
    Directory('../all_latest_version').listSync().map((e) => e.path).toList(),
  );
}
