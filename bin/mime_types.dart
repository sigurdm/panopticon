import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:pool/pool.dart';
import 'package:pub/src/http.dart';

void main() async {
  final files = <String, dynamic>{};
  final json = jsonDecode(File('file_status.json').readAsStringSync()) as Map;
  files.addAll(json['files'] as Map<String, dynamic>);
  print(files.values.map((e) => e!['mime']).toSet().toList().join());
}
