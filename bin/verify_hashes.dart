// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library;

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:panopticon/panopticon.dart';
import 'package:panopticon/utils.dart';
import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  final db = sqlite3.open('all_versions_api.sqlite');
  final versions = Map.fromIterable(
    db.select('''
select name, version, listing from packages order by name, version
'''),
    key: (row) => '${row[0]}-${row[1]}',
  );
  final elements = versions.keys.toList();
  shuffle(elements);
  withClient((client) async {
    await analyze(
      'hashes',
      columns: ['listingHash', 'actualHash', 'same'],
      (packageVersion) async {
        final listing = jsonDecode(versions[packageVersion][2]);
        final archiveUrl = listing['archive_url'] as String;
        final listingHash = listing['archive_sha256'] as String;
        final actualHash = hex.encode(
          sha256.convert(await client.readBytes(Uri.parse(archiveUrl))).bytes,
        );
        return [
          [listingHash, actualHash, listingHash == actualHash],
        ];
      },
      ['vietmap_flutter_navigation-1.5.4', ...elements],
      retryFailed: true,
      resetData: args.contains('reset'),
      parallelism: 20,
      taskTimeout: Duration(seconds: 120),
    );
  });
}
