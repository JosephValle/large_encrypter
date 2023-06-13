import "dart:math";
import "dart:typed_data";
import "package:cryptography/cryptography.dart";

class EncryptApi {
  static final Random _random = Random.secure();
  final _algorithm = AesGcm.with256bits();

  Uint8List generateAesKey([int length = 32]) {
    return Uint8List.fromList(
      List<int>.generate(length, (i) => _random.nextInt(256)),
    );
  }

  Future<Uint8List> encryptChunk(Uint8List key, Uint8List data) async {
    final secretKey = SecretKey(key);
    final nonce = _algorithm.newNonce();
    SecretBox secretBox =
        await _algorithm.encrypt(data, secretKey: secretKey, nonce: nonce);
    return secretBox.concatenation();
  }


}
