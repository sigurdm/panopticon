// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// import 'package:http/http.dart';
// import 'package:pool/pool.dart';
// import 'package:pub/src/http.dart';

// const statusFilename = 'file_status.json';

// void main() async {
//   final files = <String, Object?>{};

//   final statusPool = Pool(1);

//   Future<void> writeStatus() async {
//     await statusPool.withResource(() async {
//       await File(statusFilename).writeAsString(
//         const JsonEncoder.withIndent('  ').convert({'files': files}),
//       );
//     });
//   }

//   ProcessSignal.sigint.watch().listen((_) {
//     writeStatus();
//     exit(1);
//   });
//   final c = Client();
//   final pool = Pool(40);
//   if (File(statusFilename).existsSync()) {
//     final json = jsonDecode(File(statusFilename).readAsStringSync()) as Map;
//     files.addAll(json['files'] as Map<String, Object?>);
//   }
//   final allFiles = Directory('../image_responses').listSync();

//   var last = files.length;
//   Timer.periodic(const Duration(seconds: 2), (t) async {
//     final diff = files.length - last;
//     print(
//       'saving status ${files.length} / ${(allFiles as List).length} (${diff / 2} / s)',
//     );
//     await writeStatus();
//     last = files.length;
//   });
//   try {
//     for (final e in allFiles) {
//       if (e is! File) return;
//       final resource = await pool.request();
//       scheduleMicrotask(() async {
//         try {
//           final result = await Process.run('file', [
//             '--mime',
//             '--brief',
//             e.path,
//           ]);
//           if (result.exitCode != 0) {
//             files[e.path] = {
//               'error': 'file exited non-zero',
//               'code': result.exitCode,
//               'stdout': result.stdout,
//               'stderror': result.stderr,
//             };
//             return;
//           }
//           files[e.path] = {'mime': result.stdout};
//         } catch (error) {
//           files[e.path] = {'error': error.toString()};
//         } finally {
//           resource.release();
//         }
//       });
//     }
//   } finally {
//     await writeStatus();
//     c.close();
//   }
// }
