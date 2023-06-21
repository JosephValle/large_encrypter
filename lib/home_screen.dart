import "dart:convert";
import "dart:typed_data";
import "package:cryptography/cryptography.dart";
import "cryptography_extracts/_javascript_bindings.dart" show jsArrayBufferFrom;
import "cryptography_extracts/_javascript_bindings.dart" as web_crypto;
import "dart:async";
import "package:large_encryption/key_generator.dart";
import "package:universal_html/html.dart";
import "package:http/http.dart" as http;
import "package:flutter/material.dart";

import "cryptography_extracts/browser_key.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String host = "devapi.privacyvault.ai";
  final String url = "";
  bool loading = true;
  String token = "";
  String folderId = "";
  File? file;
  File? decryptedFile;
  String fileId = "";
  String fileName = "";
  final int _readStreamChunkSize = 16 * 10000;
  final _algorithm = AesGcm.with256bits();
  bool loadingBar = false;
  Uint8List aesKeyB = KeyGenerator().generateAesKey();
  bool uploaded = false;
  List<int> globalNonce = [];

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
                  if (loadingBar) const LinearProgressIndicator(),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () => pickFile(),
                      child: const Text("Upload File"),
                    ),
                  ),
                  if (uploaded)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () => downloadAndDecryptFile(
                          fileId,
                          SecretKey(aesKeyB),
                          fileName,
                          "0",
                        ),
                        child: const Text("Download File"),
                      ),
                    ),
                  const Spacer(),
                ],
              ),
      ),
    );
  }

  Future<void> getData() async {
    // Gets the proper auth token and ids for testing purposes
    var params = {"username": "viselozo@tutuapp.bid", "password": "Test123!"};
    final response = await http
        .get(Uri.https(host, "${url}auth/login", params), headers: {});
    if (jsonDecode(utf8.decode(response.bodyBytes))["error"] != null) {
      throw jsonDecode(utf8.decode(response.bodyBytes))["error"];
    }
    setState(() {
      token =
          "Bearer ${jsonDecode(utf8.decode(response.bodyBytes))["sessionToken"]}";
      folderId = jsonDecode(utf8.decode(response.bodyBytes))["user"]["accounts"]
          [0]["rootFolderId"];
      loading = false;
    });
  }

  Future<void> pickFile() async {
    setState(() {
      uploaded = false;
    });
    // Pick file using dart:html
    final input = FileUploadInputElement();
    // When file is picked:
    input.onChange.listen((e) async {
      final files = input.files;

      if (files!.isNotEmpty) {
        setState(() {
          file = files[0];
          fileName = file!.name;
          loadingBar = true;
        });
        print("File picked: ${file!.name}, size: ${file!.size}");

        String aesKeyS = KeyGenerator().bytesToString(aesKeyB);
        // Upload initialization method
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
        setState(() {
          fileId = jsonDecode(utf8.decode(response.bodyBytes))["fileVersion"]
              ["fileId"];
        });
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

        final secretKey = SecretKey(aesKeyB);
        final nonce = _algorithm.newNonce();
        setState(() {
          globalNonce = nonce;
          print("GLOBAL NONCE");
          print(globalNonce);
        });

        final jsCryptoKey = await BrowserSecretKey.jsCryptoKeyForAes(
          secretKey,
          secretKeyLength: 32,
          webCryptoAlgorithm: "AES-GCM",
          isExtractable: false,
          allowEncrypt: true,
          allowDecrypt: true,
        );

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

          final byteBuffer = await web_crypto.encrypt(
            web_crypto.AesGcmParams(
              name: "AES-GCM",
              iv: jsArrayBufferFrom(nonce),
              additionalData: jsArrayBufferFrom([]),
              tagLength: AesGcm.aesGcmMac.macLength * 8,
            ),
            jsCryptoKey,
            jsArrayBufferFrom(result as Uint8List),
          );
          print(
            "ENCRYPT start=$start end=$end length=${byteBuffer.lengthInBytes}",
          );
          requestSink.add(byteBuffer.asUint8List());
          start += _readStreamChunkSize;
        }

        request.sink.close();

        await request.send();
        print("DONE AND SENT");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 1),
            content: Text("Done Upload"),
          ),
        );
        setState(() {
          uploaded = true;
          loadingBar = false;
        });
      }
    });

    input.click();
  }

  Future<void> downloadAndDecryptFile(
    String fileId,
    SecretKey secretKey,
    String fileName,
    String version,
  ) async {
    print("Starting download");
    var params = {
      "fileId": fileId,
      "version": version,
    };
    final response = await http.get(
      Uri.https(host, "${this.url}file/$fileId/$version", params),
      headers: {"Authorization": token},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to download the file");
    }

    String url = jsonDecode(utf8.decode(response.bodyBytes))["fileInfo"]["url"];
    print("Got File URL $url");
    // Downloading the actual file
    final downloadResponse = await http.get(
      Uri.parse(url),
    );
    print("File Downloaded");
    // Getting the key
    final jsCryptoKey = await BrowserSecretKey.jsCryptoKeyForAes(
      secretKey,
      secretKeyLength: 32,
      webCryptoAlgorithm: "AES-GCM",
      isExtractable: false,
      allowEncrypt: false,
      allowDecrypt: true,
    );

    print("Got key");

    final encryptedBytes = downloadResponse.bodyBytes;
    final encryptedByteBuffer = encryptedBytes.buffer;

    print("Did this stuff");

    // Decryption in chunks
    const int chunkSize = 16 * 10000 + 16; // same chunk size as in encryption
    // Currently here is where the bytes are stored, in memory
    // TODO: Do this not in memory
    List<int> decryptedBytes = [];

    int start = 0;
    print("Starting Chunks");

    while (start < encryptedByteBuffer.lengthInBytes) {
      print("Stage 1");
      int end = start + chunkSize > encryptedByteBuffer.lengthInBytes
          ? encryptedByteBuffer.lengthInBytes
          : start + chunkSize;
      print("Stage 2");

      final slice = encryptedByteBuffer.asUint8List(start, end - start);
      print("Stage 3 start=$start end=$end length=${slice.length} ");

      print("BEFORE DECRYPT");
      final decryptedByteBuffer = await web_crypto.decrypt(
        web_crypto.AesGcmParams(
          name: "AES-GCM",
          iv: jsArrayBufferFrom(globalNonce),
          additionalData: jsArrayBufferFrom([]),
          tagLength: AesGcm.aesGcmMac.macLength * 8,
        ),
        jsCryptoKey,
        jsArrayBufferFrom(slice),
      );
      print("AFTER DECRYPT");

      decryptedBytes.addAll(decryptedByteBuffer.asUint8List());
      print("Stage 5");

      start += chunkSize;
    }

    final blob = Blob([Uint8List.fromList(decryptedBytes)]);
    final test = Url.createObjectUrlFromBlob(blob);
    AnchorElement(href: test)
      ..setAttribute("download", fileName)
      ..click();
    Url.revokeObjectUrl(test);
    print("Done Chunks");
  }
}
