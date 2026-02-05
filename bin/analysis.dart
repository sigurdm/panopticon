import 'dart:convert';
import 'dart:io';
import 'dart:math';

main() async {
  final s =
      jsonDecode(File('test_images_status.json').readAsStringSync())['images']
          as Map;
  final contentTypes = <String>{};
  var maxSize = 0;
  var sum = 0;
  var i = 0;
  var errors = 0;
  String? maxImage;
  List<int> sizes = [];
  final hosts = <String, int>{};
  for (final k in s.keys) {
    final e = s[k];
    if (e is! Map) continue;

    if (e.containsKey('error')) {
      errors++;
    }
    final uri = Uri.tryParse(k as String);
    if (!e.containsKey('headers')) continue;
    if (uri != null) {
      final current = hosts[uri.host] ?? 0;
      hosts[uri.host] = current + 1;
      if (uri.host == '') print(uri);
    }
    final contentType = e['headers']['content-type'];
    if (contentType is! String) {
      continue;
    }
    contentTypes.add(contentType);
    if (!e.containsKey('size')) continue;
    final size = e['size'] as int;
    if (size > maxSize) {
      maxSize = size;
      maxImage = k as String;
    }
    sum += size;
    i++;
    sizes.add(size);
  }
  print(contentTypes);
  print('max size: $maxSize $maxImage');
  print('avg size: ${sum / i}');
  sizes.sort();
  print('median: ${sizes[sizes.length ~/ 2]}');
  for (var i = 0; i < 201; i++) {
    print('${1 / 200 * i},${sizes[(sizes.length ~/ 200) * i]}');
  }
  print('count $i');
  print('errors $errors');
  print('');
  print('hosts: ${hosts.length}');
  final l = hosts.entries.toList();
  l.sort((a, b) => -a.value.compareTo(b.value));
  print('top hosts:');
  print('${l.take(20).map((e) => '${e.key} ${e.value}').join('\n')}');
}
