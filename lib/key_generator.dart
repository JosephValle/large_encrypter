import "dart:convert";
import "dart:math";
import "dart:typed_data";

class KeyGenerator {
  // static final Random _random = Random.secure();

  Uint8List generateAesKey([int length = 32]) {
    final random = Random(42);
    // Setting the same key every time for testing purposes
    return Uint8List.fromList(
      List<int>.generate(length, (i) => random.nextInt(256)),
    );
  }


  String bytesToString(Uint8List bytes) {
    return base64.encode(bytes);
  }


}
