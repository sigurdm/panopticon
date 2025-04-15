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
    await analyze(
      'packages',
      columns: ['version', 'sdk', 'published', 'pubspec', 'languageVersion'],
      primaryKeys: ['version'],
      (packageName) async {
        final listing = (await versionListing(client, packageName)) as Map;
        final versions = listing['versions'] as List;
        languageVersion(String sdk) {
          final sdkConstraint = VersionConstraint.parse(sdk) as VersionRange;
          final major = sdkConstraint.min?.major;
          final minor = sdkConstraint.min?.minor;
          return '$major.$minor';
        }

        return [
          for (final version in versions)
            [
              version['version'],
              version['pubspec']['environment']['sdk'],
              version['published'],
              version['pubspec'],
              languageVersion(version['pubspec']['environment']['sdk']),
            ],
        ];
      },
      await allPackageNames(client),
      retryFailed: true,
      resetData: args.contains('reset'),
      parallelism: 20,
    );
  });
}
