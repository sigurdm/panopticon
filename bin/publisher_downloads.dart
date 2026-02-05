// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library;

import 'dart:io';

import 'package:panopticon/panopticon.dart';
import 'package:panopticon/utils.dart';
import 'dart:async';

Future<void> main(List<String> args) async {
  withClient((client) async {
    await analyze(
      dbname: 'language_version_latest.sqlite',
      'scores',
      columns: ['grantedPoints', 'likeCount', 'downloadCount30Days', 'tags'],
      (packageName) async {
        final score = await scoreListing(client, packageName) as Map;
        return [
          [
            score['grantedPoints'],
            score['likeCount'],
            score['downloadCount30Days'],
            score['tags'],
          ],
        ];
      },
      (File('publishers2.txt').readAsLinesSync()),
      retryFailed: true,
      resetData: args.contains('reset'),
      parallelism: 40,
    );
  });
}
