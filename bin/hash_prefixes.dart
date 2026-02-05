import 'dart:convert';
import 'dart:typed_data';

import 'dart:io';

import 'package:convert/convert.dart';
import 'package:typed_data/typed_data.dart';
import 'dart:ffi' as ffi;

main() {
  final d = ffi.DynamicLibrary.executable();
  d.lookupFunction('EVP_sha256', isLeaf: true);
  final listing = hex.decode(
    '54e852c00c0f6d4717b235e71f30420eb9ce159719dda628b34bbb655d5b9cae',
  );
  final bytes = File('cherry_toast-1.6.3.tar.gz').readAsBytesSync();
  outer:
  for (var i = 0; i < bytes.length; i++) {
    if (i % 1000 == 0) print(i);
    final prefixHash = sha256.convert(bytes.sublist(0, i)).bytes;
    for (var j = 0; j < prefixHash.length; j++) {
      if (prefixHash[j] != listing[j]) {
        continue outer;
      }
    }
    print('Found match at $i');
  }
}

/// An implementation of the [SHA-256][rfc] hash function.
///
/// [rfc]: http://tools.ietf.org/html/rfc6234
const Hash sha256 = _Sha256._();

/// An implementation of the [SHA-256][rfc] hash function.
///
/// [rfc]: http://tools.ietf.org/html/rfc6234
///
/// Use the [sha256] object to perform SHA-256 hashing.
class _Sha256 extends Hash {
  @override
  final int blockSize = 16 * bytesPerWord;

  const _Sha256._();

  @override
  ByteConversionSink startChunkedConversion(Sink<Digest> sink) =>
      ByteConversionSink.from(_Sha256Sink(sink));
}

/// Data from a non-linear function that functions as reproducible noise.
const List<int> _noise = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

abstract class _Sha32BitSink extends HashSink {
  final Uint32List _digest;

  /// The sixteen words from the original chunk, extended to 64 words.
  ///
  /// This is an instance variable to avoid re-allocating, but its data isn't
  /// used across invocations of [updateHash].
  final _extended = Uint32List(64);

  _Sha32BitSink(Sink<Digest> sink, this._digest) : super(sink, 16);

  // The following helper functions are taken directly from
  // http://tools.ietf.org/html/rfc6234.

  int _rotr32(int n, int x) => (x >> n) | ((x << (32 - n)) & mask32);
  int _ch(int x, int y, int z) => (x & y) ^ ((~x & mask32) & z);
  int _maj(int x, int y, int z) => (x & y) ^ (x & z) ^ (y & z);
  int _bsig0(int x) => _rotr32(2, x) ^ _rotr32(13, x) ^ _rotr32(22, x);
  int _bsig1(int x) => _rotr32(6, x) ^ _rotr32(11, x) ^ _rotr32(25, x);
  int _ssig0(int x) => _rotr32(7, x) ^ _rotr32(18, x) ^ (x >> 3);
  int _ssig1(int x) => _rotr32(17, x) ^ _rotr32(19, x) ^ (x >> 10);

  @override
  void updateHash(Uint32List chunk) {
    assert(chunk.length == 16);

    // Prepare message schedule.
    for (var i = 0; i < 16; i++) {
      _extended[i] = chunk[i];
    }
    for (var i = 16; i < 64; i++) {
      _extended[i] = add32(
        add32(_ssig1(_extended[i - 2]), _extended[i - 7]),
        add32(_ssig0(_extended[i - 15]), _extended[i - 16]),
      );
    }

    // Shuffle around the bits.
    var a = _digest[0];
    var b = _digest[1];
    var c = _digest[2];
    var d = _digest[3];
    var e = _digest[4];
    var f = _digest[5];
    var g = _digest[6];
    var h = _digest[7];

    for (var i = 0; i < 64; i++) {
      var temp1 = add32(
        add32(h, _bsig1(e)),
        add32(_ch(e, f, g), add32(_noise[i], _extended[i])),
      );
      var temp2 = add32(_bsig0(a), _maj(a, b, c));
      h = g;
      g = f;
      f = e;
      e = add32(d, temp1);
      d = c;
      c = b;
      b = a;
      a = add32(temp1, temp2);
    }

    // Update hash values after iteration.
    _digest[0] = add32(a, _digest[0]);
    _digest[1] = add32(b, _digest[1]);
    _digest[2] = add32(c, _digest[2]);
    _digest[3] = add32(d, _digest[3]);
    _digest[4] = add32(e, _digest[4]);
    _digest[5] = add32(f, _digest[5]);
    _digest[6] = add32(g, _digest[6]);
    _digest[7] = add32(h, _digest[7]);
  }
}

/// The concrete implementation of `Sha256`.
///
/// This is separate so that it can extend [HashSink] without leaking additional
/// public members.
class _Sha256Sink extends _Sha32BitSink {
  @override
  Uint32List get digest => _digest;

  // Initial value of the hash parts. First 32 bits of the fractional parts
  // of the square roots of the first 8 prime numbers.
  _Sha256Sink(Sink<Digest> sink)
    : super(
        sink,
        Uint32List.fromList([
          0x6a09e667,
          0xbb67ae85,
          0x3c6ef372,
          0xa54ff53a,
          0x510e527f,
          0x9b05688c,
          0x1f83d9ab,
          0x5be0cd19,
        ]),
      );
}

/// A bitmask that limits an integer to 32 bits.
const mask32 = 0xFFFFFFFF;

/// The number of bits in a byte.
const bitsPerByte = 8;

/// The number of bytes in a 32-bit word.
const bytesPerWord = 4;

/// Adds [x] and [y] with 32-bit overflow semantics.
int add32(int x, int y) => (x + y) & mask32;

/// Bitwise rotates [val] to the left by [shift], obeying 32-bit overflow
/// semantics.
int rotl32(int val, int shift) {
  var modShift = shift & 31;
  return ((val << modShift) & mask32) | ((val & mask32) >> (32 - modShift));
}

/// A base class for [Sink] implementations for hash algorithms.
///
/// Subclasses should override [updateHash] and [digest].
abstract class HashSink implements Sink<List<int>> {
  /// The inner sink that this should forward to.
  final Sink<Digest> _sink;

  /// Whether the hash function operates on big-endian words.
  final Endian _endian;

  /// The words in the current chunk.
  ///
  /// This is an instance variable to avoid re-allocating, but its data isn't
  /// used across invocations of [_iterate].
  final Uint32List _currentChunk;

  /// Messages with more than 2^53-1 bits are not supported.
  ///
  /// This is the largest value that is precisely representable
  /// on both JS and the Dart VM.
  /// So the maximum length in bytes is (2^53-1)/8.
  static const _maxMessageLengthInBytes = 0x0003ffffffffffff;

  /// The length of the input data so far, in bytes.
  int _lengthInBytes = 0;

  /// Data that has yet to be processed by the hash function.
  final _pendingData = Uint8Buffer();

  /// Whether [close] has been called.
  bool _isClosed = false;

  /// The words in the current digest.
  ///
  /// This should be updated each time [updateHash] is called.
  Uint32List get digest;

  /// The number of signature bytes emitted at the end of the message.
  ///
  /// An encrypted message is followed by a signature which depends
  /// on the encryption algorithm used. This value specifies the
  /// number of bytes used by this signature. It must always be
  /// a power of 2 and no less than 8.
  final int _signatureBytes;

  /// Creates a new hash.
  ///
  /// [chunkSizeInWords] represents the size of the input chunks processed by
  /// the algorithm, in terms of 32-bit words.
  HashSink(
    this._sink,
    int chunkSizeInWords, {
    Endian endian = Endian.big,
    int signatureBytes = 8,
  }) : _endian = endian,
       assert(signatureBytes >= 8),
       _signatureBytes = signatureBytes,
       _currentChunk = Uint32List(chunkSizeInWords);

  /// Runs a single iteration of the hash computation, updating [digest] with
  /// the result.
  ///
  /// [chunk] is the current chunk, whose size is given by the
  /// `chunkSizeInWords` parameter passed to the constructor.
  void updateHash(Uint32List chunk);

  @override
  void add(List<int> data) {
    if (_isClosed) throw StateError('Hash.add() called after close().');
    _lengthInBytes += data.length;
    _pendingData.addAll(data);
    _iterate();
  }

  @override
  void close() {
    if (_isClosed) return;
    _isClosed = true;

    _finalizeData();
    _iterate();
    assert(_pendingData.isEmpty);
    _sink.add(Digest(_byteDigest()));
    _sink.close();
  }

  Uint8List _byteDigest() {
    if (_endian == Endian.host) return digest.buffer.asUint8List();

    // Cache the digest locally as `get` could be expensive.
    final cachedDigest = digest;
    final byteDigest = Uint8List(cachedDigest.lengthInBytes);
    final byteData = byteDigest.buffer.asByteData();
    for (var i = 0; i < cachedDigest.length; i++) {
      byteData.setUint32(i * bytesPerWord, cachedDigest[i]);
    }
    return byteDigest;
  }

  /// Iterates through [_pendingData], updating the hash computation for each
  /// chunk.
  void _iterate() {
    var pendingDataBytes = _pendingData.buffer.asByteData();
    var pendingDataChunks = _pendingData.length ~/ _currentChunk.lengthInBytes;
    for (var i = 0; i < pendingDataChunks; i++) {
      // Copy words from the pending data buffer into the current chunk buffer.
      for (var j = 0; j < _currentChunk.length; j++) {
        _currentChunk[j] = pendingDataBytes.getUint32(
          i * _currentChunk.lengthInBytes + j * bytesPerWord,
          _endian,
        );
      }

      // Run the hash function on the current chunk.
      updateHash(_currentChunk);
    }

    // Remove all pending data up to the last clean chunk break.
    _pendingData.removeRange(
      0,
      pendingDataChunks * _currentChunk.lengthInBytes,
    );
  }

  /// Finalizes [_pendingData].
  ///
  /// This adds a 1 bit to the end of the message, and expands it with 0 bits to
  /// pad it out.
  void _finalizeData() {
    // Pad out the data with 0x80, eight or sixteen 0s, and as many more 0s
    // as we need to land cleanly on a chunk boundary.
    _pendingData.add(0x80);

    final contentsLength = _lengthInBytes + 1 /* 0x80 */ + _signatureBytes;
    final finalizedLength = _roundUp(
      contentsLength,
      _currentChunk.lengthInBytes,
    );

    for (var i = 0; i < finalizedLength - contentsLength; i++) {
      _pendingData.add(0);
    }

    if (_lengthInBytes > _maxMessageLengthInBytes) {
      throw UnsupportedError(
        'Hashing is unsupported for messages with more than 2^53 bits.',
      );
    }

    var lengthInBits = _lengthInBytes * bitsPerByte;

    // Add the full length of the input data as a 64-bit value at the end of the
    // hash. Note: we're only writing out 64 bits, so skip ahead 8 if the
    // signature is 128-bit.
    final offset = _pendingData.length + (_signatureBytes - 8);

    _pendingData.addAll(Uint8List(_signatureBytes));
    var byteData = _pendingData.buffer.asByteData();

    // We're essentially doing byteData.setUint64(offset, lengthInBits, _endian)
    // here, but that method isn't supported on dart2js so we implement it
    // manually instead.
    var highBits = lengthInBits ~/ 0x100000000; // >> 32
    var lowBits = lengthInBits & mask32;
    if (_endian == Endian.big) {
      byteData.setUint32(offset, highBits, _endian);
      byteData.setUint32(offset + bytesPerWord, lowBits, _endian);
    } else {
      byteData.setUint32(offset, lowBits, _endian);
      byteData.setUint32(offset + bytesPerWord, highBits, _endian);
    }
  }

  /// Rounds [val] up to the next multiple of [n], as long as [n] is a power of
  /// two.
  int _roundUp(int val, int n) => (val + n - 1) & -n;
}

/// An interface for cryptographic hash functions.
///
/// Every hash is a converter that takes a list of ints and returns a single
/// digest. When used in chunked mode, it will only ever add one digest to the
/// inner [Sink].
abstract class Hash extends Converter<List<int>, Digest> {
  /// The internal block size of the hash in bytes.
  ///
  /// This is exposed for use by the `Hmac` class,
  /// which needs to know the block size for the [Hash] it uses.
  int get blockSize;

  const Hash();

  @override
  Digest convert(List<int> input) {
    var innerSink = DigestSink();
    var outerSink = startChunkedConversion(innerSink);
    outerSink.add(input);
    outerSink.close();
    return innerSink.value;
  }

  @override
  ByteConversionSink startChunkedConversion(Sink<Digest> sink);
}

/// A message digest as computed by a `Hash` or `HMAC` function.
class Digest {
  /// The message digest as an array of bytes.
  final List<int> bytes;

  Digest(this.bytes);

  /// Returns whether this is equal to another digest.
  ///
  /// This should be used instead of manual comparisons to avoid leaking
  /// information via timing.
  @override
  bool operator ==(Object other) {
    if (other is Digest) {
      final a = bytes;
      final b = other.bytes;
      final n = a.length;
      if (n != b.length) {
        return false;
      }
      var mismatch = 0;
      for (var i = 0; i < n; i++) {
        mismatch |= a[i] ^ b[i];
      }
      return mismatch == 0;
    }
    return false;
  }

  @override
  int get hashCode => Object.hashAll(bytes);

  /// The message digest as a string of hexadecimal digits.
  @override
  String toString() => _hexEncode(bytes);
}

String _hexEncode(List<int> bytes) {
  const hexDigits = '0123456789abcdef';
  var charCodes = Uint8List(bytes.length * 2);
  for (var i = 0, j = 0; i < bytes.length; i++) {
    var byte = bytes[i];
    charCodes[j++] = hexDigits.codeUnitAt((byte >> 4) & 0xF);
    charCodes[j++] = hexDigits.codeUnitAt(byte & 0xF);
  }
  return String.fromCharCodes(charCodes);
}

/// A sink used to get a digest value out of `Hash.startChunkedConversion`.
class DigestSink implements Sink<Digest> {
  /// The value added to the sink.
  ///
  /// A value must have been added using [add] before reading the `value`.
  Digest get value => _value!;

  Digest? _value;

  /// Adds [value] to the sink.
  ///
  /// Unlike most sinks, this may only be called once.
  @override
  void add(Digest value) {
    if (_value != null) throw StateError('add may only be called once.');
    _value = value;
  }

  @override
  void close() {
    if (_value == null) throw StateError('add must be called once.');
  }
}
