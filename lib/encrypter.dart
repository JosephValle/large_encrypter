import "dart:convert";
import "dart:math";
import "dart:typed_data";
import "package:cryptography/cryptography.dart";

import "_javascript_bindings.dart" show jsArrayBufferFrom;
import "_javascript_bindings.dart" as web_crypto;
import "browser_key.dart";

class EncryptApi {
  // static final Random _random = Random.secure();

  Uint8List generateAesKey([int length = 32]) {
    final random = Random(42);

    return Uint8List.fromList(
      List<int>.generate(length, (i) => random.nextInt(256)),
    );
  }


  String bytesToString(Uint8List bytes) {
    return base64.encode(bytes);
  }

  Future<void> encrypt(Uint8List key, Uint8List chunk) async {
    final algorithm = AesGcm.with256bits();
    SecretKey secretKey = SecretKey(key);
    final jsCryptoKey = await BrowserSecretKey.jsCryptoKeyForAes(
      secretKey,
      secretKeyLength: 32,
      webCryptoAlgorithm: "AES-GCM",
      isExtractable: false,
      allowEncrypt: true,
      allowDecrypt: false,
    );
    final nonce = algorithm.newNonce();
    final byteBuffer = await web_crypto.encrypt(
      web_crypto.AesGcmParams(
        name: "AES-GCM",
        iv: jsArrayBufferFrom(nonce),
        additionalData: jsArrayBufferFrom([]),
        tagLength: AesGcm.aesGcmMac.macLength * 8,
      ),
      jsCryptoKey,
      jsArrayBufferFrom(chunk),
    );

    print(byteBuffer.lengthInBytes);
  }
}
