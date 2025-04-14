// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This is a manual test that can be run to test the .tar.gz decoding.
/// It will save progress in `statusFileName` such that it doesn't have to be
/// finished in a single run.
library;

import 'package:http/http.dart';
import 'package:panopticon/panopticon.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:pool/pool.dart';
import 'package:pub/src/io.dart';
import 'package:tar/tar.dart';
import 'package:yaml/yaml.dart';

const statusFilename = 'extract_all_pub_status.json';

final client = Client();

Future<List<String>> allPackageNames() async {
  final nextUrl = Uri.https('pub.dev', 'api/packages', {'compact': '1'});
  final response = await client.get(nextUrl);
  final result = json.decode(response.body);
  return List<String>.from((result as Map)['packages'] as List);
}

Future<Object?> versionListing(String packageName) async {
  final url = Uri.https('pub.dev', 'api/packages/$packageName');
  return jsonDecode(await client.read(url));
}

Future<void> main() async {
  analyze(
    'packages',
    (packageName) async {
      final pubspecFile = File(
        p.join('../all_latest_version', packageName, 'pubspec.yaml'),
      );
      final listing = (await versionListing(packageName)) as Map;
      final latest = listing['latest'] as Map;
      final latestVersion = latest['pubspec']['version'];
      final archiveUrl = latest['archive_url'];
      final archiveSha256 = latest['archive_sha256'];

      if (pubspecFile.existsSync()) {
        final pubspec = loadYaml(pubspecFile.readAsStringSync());
        if (pubspec['version'] != latestVersion) {
          Directory(
            p.join('../all_latest_version', packageName),
          ).deleteSync(recursive: true);
          // print('Redownloading $packageName');
        } else {
          return {
            'version': latestVersion,
            'pubspec': pubspec,
            'archive_sha256': archiveSha256,
          };
        }
      }
      final response = await client.send(Request('get', Uri.parse(archiveUrl)));
      await extractTarGz(
        response.stream,
        p.join('../all_latest_version', packageName),
      );
      // print('Downloading $packageName');

      final pubspec = loadYaml(pubspecFile.readAsStringSync());
      return {'version': latestVersion, 'pubspec': pubspec};
    },
    await allPackageNames(),
    retryFailed: true,
  );
}
