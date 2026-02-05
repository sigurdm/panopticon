import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:html/dom.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:html/parser.dart' as parser;
import 'package:pana/models.dart';
import 'package:panopticon/panopticon.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:pana/src/repository/repository_url_parser.dart';

const statusFilename = 'validate_images_status.json';

main(List<String> args) async {
  final db = await analyze(
    'validate_images',
    (path) async {
      final images = await Isolate.run(() {
        final pubspec = loadYaml(
          File(p.join(path, 'pubspec.yaml')).readAsStringSync(),
        );
        final repositoryUrl = pubspec['repository'];
        Repository? repository;
        repository =
            repositoryUrl is String ? parseRepositoryUrl(repositoryUrl) : null;
        final images = <String>[];
        for (final f in Directory(path).listSync(recursive: true)) {
          if (f is File &&
              (f.path.endsWith('/README.md') ||
                  f.path.endsWith('/CHANGELOG.md'))) {
            final Document doc;

            doc = parser.parse(markdown.markdownToHtml(f.readAsStringSync()));

            for (final img in doc.getElementsByTagName('img')) {
              final src = img.attributes['src'];
              if (src != null) {
                final resolved =
                    repository == null ? src : repository.tryResolveUrl(src);
                if (resolved != null) {
                  images.add(resolved);
                }
              }
            }
          }
        }
        return images;
      });

      return {'images': images.toList()};
    },
    resetData: args.contains('--reset'),
    retryFailed: args.contains('--retry'),
    Directory('../all_latest_version').listSync().map((e) => e.path).toList(),
  );

  final a = db.select('''
select count(*) from validate_images where result ->> '\$'
''');
  print(a.first);
  db.dispose();
}
