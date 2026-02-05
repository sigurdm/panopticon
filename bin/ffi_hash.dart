import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:http/http.dart';
import 'package:panopticon/generated_bindings.dart' as bindings;
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart' as ff;
import 'package:sqlite3/sqlite3.dart';

main() async {
  final lib = bindings.NativeLibrary(
    ffi.DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libcrypto.so.1.1'),
  );

  final c = ff.calloc<bindings.SHA256_CTX>();
  final copy = ff.calloc<bindings.SHA256_CTX>();
  final db = sqlite3.open('verify_hashes.sqlite');
  final problems = db.select('''
SELECT name, listingHash FROM hashes where same == "false";
''');
  for (final row in problems) {
    final name = row[0] as String;
    final listingHash = row[1] as String;
    print('Searching for $listingHash in $name');

    final bytes = await readBytes(
      Uri.parse('https://pub.dev/api/archives/${name}.tar.gz'),
    );

    lib.SHA256_Init(c);
    final hash = ff.calloc<ffi.Uint8>(bindings.SHA256_DIGEST_LENGTH);
    final bytesmen = ff.malloc<ffi.Uint8>(bytes.length);
    bytesmen.asTypedList(bytes.length).setRange(0, bytes.length, bytes);
    final listing = hex.decode(listingHash);
    outer:
    for (var i = 0; i < bytes.length; i++) {
      // if (i % 1000 == 0) print(i);
      lib.SHA256_Update(
        c,
        ffi.Pointer.fromAddress(bytesmen.cast().address + i),
        1,
      );

      copy
          .cast<ffi.Uint8>()
          .asTypedList(ffi.sizeOf<bindings.SHA256state_st>())
          .setRange(
            0,
            ffi.sizeOf<bindings.SHA256state_st>(),
            c.cast<ffi.Uint8>().asTypedList(
              ffi.sizeOf<bindings.SHA256state_st>(),
            ),
          );
      lib.SHA256_Final(hash.cast(), copy);

      for (var j = 0; j < bindings.SHA256_DIGEST_LENGTH; j++) {
        if (hash[j] != listing[j]) {
          continue outer;
        }
      }
      print('Found match at $i');
    }

    print(hex.encode(hash.asTypedList(bindings.SHA256_DIGEST_LENGTH)));
  }
}
