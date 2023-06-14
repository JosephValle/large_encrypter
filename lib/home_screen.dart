import "dart:convert";
import "dart:typed_data";
import "package:cryptography/cryptography.dart";
import "_javascript_bindings.dart" show jsArrayBufferFrom;
import "_javascript_bindings.dart" as web_crypto;
import "browser_key.dart";
import "dart:async";
import "package:large_encryption/encrypter.dart";
import "package:universal_html/html.dart";
import "package:http/http.dart" as http;
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String host = "devapi.privacyvault.ai";
  final String url = "";
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  bool loading = true;
  String token = "";
  String folderId = "";
  File? file;
  File? decryptedFile;
  final int _readStreamChunkSize = 128 * 100000;
  final _algorithm = AesGcm.with256bits();
  final bool loadingBar = true;

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: loadingBar
                        ? const LinearProgressIndicator()
                        : const SizedBox.shrink(),
                  ),
                  ElevatedButton(
                    onPressed: () => pickFile(),
                    child: const Text("Upload File"),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> getData() async {
    var params = {"username": "viselozo@tutuapp.bid", "password": "Test123!"};
    final response = await http
        .get(Uri.https(host, "${url}auth/login", params), headers: {});
    if (jsonDecode(utf8.decode(response.bodyBytes))["error"] != null) {
      throw jsonDecode(utf8.decode(response.bodyBytes))["error"];
    }
    setState(() {
      token = "Bearer ${jsonDecode(utf8.decode(response.bodyBytes))["sessionToken"]}";
      folderId = jsonDecode(utf8.decode(response.bodyBytes))["user"]["accounts"]
          [0]["rootFolderId"];
      loading = false;
    });
  }

  Future<void> pickFile() async {
    final input = FileUploadInputElement();

    input.onChange.listen((e) async {
      final files = input.files;

      if (files!.isNotEmpty) {
        setState(() {
          file = files[0];
        });
        print(file!.size);
        print(file!.name);

        Uint8List aesKeyB = EncryptApi().generateAesKey();
        String aesKeyS = EncryptApi().bytesToString(aesKeyB);

        final response = await http.post(
          Uri.https(
            host,
            "${url}file/initUpload",
          ),
          body: {
            "folderId": folderId,
            "filename": file!.name,
            "encryptedKey": aesKeyS,
          },
          headers: {"Authorization": token},
        );
        final String uniqueId =
            jsonDecode(utf8.decode(response.bodyBytes))["fileVersion"]
                ["unique_id"];
        // Open the request
        http.StreamedRequest request = http.StreamedRequest(
          "POST",
          Uri.parse("https://$host/${url}file/upload/$uniqueId"),
        );

        request.headers["Authorization"] = token;
        request.headers["Content-Type"] = "application/octet-stream";

        // Do the encryption here:
        final secretKey = SecretKey(aesKeyB);
        final nonce = _algorithm.newNonce();

        final jsCryptoKey = await BrowserSecretKey.jsCryptoKeyForAes(
          secretKey,
          secretKeyLength: 32,
          webCryptoAlgorithm: "AES-GCM",
          isExtractable: false,
          allowEncrypt: true,
          allowDecrypt: false,
        );

        // Method in here to read the file a chunk at a time, print out the chunks

        // Use web crypto method 128*10 buffer

        // response is a byte buffer encrypted bytes
        final reader = FileReader();

        EventSink<List<int>> requestSink = request.sink;

        int start = 0;
        while (start < file!.size) {
          final end = start + _readStreamChunkSize > file!.size
              ? file!.size
              : start + _readStreamChunkSize;
          final blob = file!.slice(start, end);
          reader.readAsArrayBuffer(blob);
          await reader.onLoad.first;
          final result = reader.result;
          if (result is ByteBuffer) {

            final byteBuffer = await web_crypto.encrypt(
              web_crypto.AesGcmParams(
                name: "AES-GCM",
                iv: jsArrayBufferFrom(nonce),
                additionalData: jsArrayBufferFrom([]),
                tagLength: AesGcm.aesGcmMac.macLength * 8,
              ),
              jsCryptoKey,
              jsArrayBufferFrom(result.asUint8List()),
            );
            requestSink.add(byteBuffer.asUint8List());
          } else if (result is Uint8List) {
            final byteBuffer = await web_crypto.encrypt(
              web_crypto.AesGcmParams(
                name: "AES-GCM",
                iv: jsArrayBufferFrom(nonce),
                additionalData: jsArrayBufferFrom([]),
                tagLength: AesGcm.aesGcmMac.macLength * 8,
              ),
              jsCryptoKey,
              jsArrayBufferFrom(result),
            );
            requestSink.add(byteBuffer.asUint8List());
          }
          start += _readStreamChunkSize;
          print("Chunk $start");
        }

        // EventSink<List<int>> requestSink = request.sink;
        // encryptStream.listen((chunk) {
        //   print(chunk.length);
        //   requestSink.add(chunk);
        // }).onDone(() {
        request.sink.close();
        // });

        final uploadResponse = await request.send();
        print(uploadResponse.request);
        print("DONE AND SENT");
      }
    });

    input.click();
  }

}
