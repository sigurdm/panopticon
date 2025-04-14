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
import 'package:pub_semver/pub_semver.dart';
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

Future<void> main(List<String> args) async {
  final db = await analyze(
    'packages',
    (packageName) async {
      final listing = (await versionListing(packageName)) as Map;
      final latest = listing['latest'] as Map;
      final sdkConstraintString =
          latest['pubspec']['environment']['sdk'] as String;

      final sdkConstraint =
          VersionConstraint.parse(sdkConstraintString) as VersionRange;
      final major = sdkConstraint.min?.major;
      final minor = sdkConstraint.min?.minor;

      return {
        'major': sdkConstraint.min?.major,
        'minor': minor,
        'language-version': '$major.$minor',
      };
    },
    (await allPackageNames()),
    retryFailed: true,
    resetData: args.contains('reset'),
    parallelism: 20,
  );
  db.execute('''
drop table if exists versions;
create table versions (
  name primary key,
  major,
  minor,
  languageVersion
)
''');
  db.execute('''
insert into versions 
select
  name,
  result -> '\$.major',
  result -> '\$.minor',
  result -> '\$.language-version'
from
  packages
''');
  client.close();
}
