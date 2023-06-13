import "dart:convert";
import "dart:math";
import "dart:typed_data";

class EncryptApi {
  static final Random _random = Random.secure();

  Uint8List generateAesKey([int length = 32]) {
    return Uint8List.fromList(
      List<int>.generate(length, (i) => _random.nextInt(256)),
    );
  }

  String bytesToString(Uint8List bytes) {
    return base64.encode(bytes);
  }
}
