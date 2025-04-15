// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library;

import 'package:panopticon/panopticon.dart';
import 'package:panopticon/utils.dart';
import 'dart:async';

import 'package:pub_semver/pub_semver.dart';

Future<void> main(List<String> args) async {
  withClient((client) async {
    final db = await analyze(
      'packages',
      columns: ['pubspec', 'major', 'minor', 'languageVersion', 'published'],
      (packageName) async {
        final listing = (await versionListing(client, packageName)) as Map;
        final latest = listing['latest'] as Map;
        final sdkConstraintString =
            latest['pubspec']['environment']['sdk'] as String;
        final pubspec = latest['pubspec'] as Map;

        final sdkConstraint =
            VersionConstraint.parse(sdkConstraintString) as VersionRange;
        final major = sdkConstraint.min?.major;
        final minor = sdkConstraint.min?.minor;
        final published = latest['published'] as String?;

        return [
          [pubspec, major, minor, '$major.$minor', published],
        ];
      },
      (await allPackageNames(client)),
      retryFailed: true,
      resetData: args.contains('reset'),
      parallelism: 40,
    );
  });
}
