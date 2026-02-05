import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:pool/pool.dart';
import 'package:pub/src/http.dart';

const statusFilename = 'test_images_status.json';

void main() async {
  final images = <String, Object?>{};

  final statusPool = Pool(1);

  Future<void> writeStatus() async {
    await statusPool.withResource(() async {
      await File(statusFilename).writeAsString(
        const JsonEncoder.withIndent('  ').convert({'images': images}),
      );
    });
  }

  ProcessSignal.sigint.watch().listen((_) {
    writeStatus();
    exit(1);
  });
  final c = Client();
  final pool = Pool(40);
  if (File(statusFilename).existsSync()) {
    final json = jsonDecode(File(statusFilename).readAsStringSync()) as Map;
    images.addAll(json['images'] as Map<String, Object?>);
  }
  final imageUrls =
      jsonDecode(
        File('validate_images_status.json').readAsStringSync(),
      )['images'];
  await Directory('../image_responses').create(recursive: true);

  var last = images.length;
  Timer.periodic(const Duration(seconds: 2), (t) async {
    final diff = images.length - last;
    print(
      'saving status ${images.length} / ${(imageUrls as List).length} (${diff / 2} / s)',
    );
    await writeStatus();
    last = images.length;
  });
  try {
    for (final e in imageUrls as Iterable) {
      if (e is! String) return;
      if (images.containsKey(e)) continue;
      final resource = await pool.request();
      scheduleMicrotask(() async {
        try {
          print('downloading $e');
          await retryForHttp('downloading $e', () async {
            final response = await c
                .get(Uri.parse(e))
                .timeout(const Duration(seconds: 10));
            final bytes = response.bodyBytes;

            File(
              '../image_responses/${Uri.encodeComponent(e)}',
            ).writeAsBytesSync(bytes);
            images[e] = {
              'status': response.statusCode,
              'size': bytes.lengthInBytes,
              'headers': response.headers,
              'file': '../image_responses/${Uri.encodeComponent(e)}',
            };
          });
        } catch (error) {
          images[e] = {'error': error.toString()};
        } finally {
          resource.release();
        }
      });
    }
  } finally {
    await writeStatus();
    c.close();
  }
}
