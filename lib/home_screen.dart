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
  String fileId = "";
  final int _readStreamChunkSize = 16 * 10000;
  final _algorithm = AesGcm.with256bits();
  bool loadingBar = false;
  Uint8List aesKeyB = EncryptApi().generateAesKey();
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
                          "Name.mp4",
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
    final input = FileUploadInputElement();
    input.onChange.listen((e) async {
      final files = input.files;

      if (files!.isNotEmpty) {
        setState(() {
          file = files[0];
          loadingBar = true;
        });

        print(file!.size);
        print(file!.name);

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

        // Do the encryption here:
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
          print("ENCRYPT start=$start end=$end");
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
            if (start == 0) {
              print(byteBuffer.asUint8List().sublist(0, 16));
            }
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
           // if (start == 0) {
              print(byteBuffer.asUint8List().sublist(0, 16));
              print("Original File Bytes");
              print(result.sublist(0,16));
              print("Decrypted File Bytes");
              // TODO: Remove this
              final decryptedByteBuffer = await web_crypto.decrypt(
                web_crypto.AesGcmParams(
                  name: "AES-GCM",
                  iv: jsArrayBufferFrom(nonce),
                  additionalData: jsArrayBufferFrom([]),
                  tagLength: AesGcm.aesGcmMac.macLength * 8,
                ),
                jsCryptoKey,
                jsArrayBufferFrom(byteBuffer.asUint8List()),
              );
              print(decryptedByteBuffer.asUint8List().sublist(0, 16));
          //  }
          }
          start += _readStreamChunkSize;
        }

        // EventSink<List<int>> requestSink = request.sink;
        // encryptStream.listen((chunk) {
        //   print(chunk.length);
        //   requestSink.add(chunk);
        // }).onDone(() {
        request.sink.close();
        // });

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

    final downloadResponse = await http.get(
      Uri.parse(url),
   //   headers: {"Authorization": token},
    );
    print("File Downloaded");

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
    print("Response start");
    print(encryptedBytes.sublist(0, 16));
    final encryptedByteBuffer = encryptedBytes.buffer;

    print("Did this stuff");

    // Decryption in chunks
    const int chunkSize = 16 * 10000; // same chunk size as in encryption
    List<int> decryptedBytes = [];

    int start = 0;
    print("Starting Chunks");

    while (start < encryptedByteBuffer.lengthInBytes) {
      print("Stage 1");
      int end = start + chunkSize > encryptedByteBuffer.lengthInBytes
          ? encryptedByteBuffer.lengthInBytes
          : start + chunkSize;
      print("Stage 2");

      final slice = encryptedByteBuffer.asUint8List(start, end);
      print("Stage 3 start=$start end=$end");

      if (start == 0) {
        print(slice.sublist(0, 16));
      }
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
      print("Stage 4");

      decryptedBytes.addAll(decryptedByteBuffer.asUint8List());
      print("Stage 5");

      start += chunkSize;
    }

    // Initiating the download of the decrypted file
    final blob = Blob([Uint8List.fromList(decryptedBytes)]);
    final test = Url.createObjectUrlFromBlob(blob);
    AnchorElement(href: test)
      ..setAttribute("download", fileName)
      ..click();
    Url.revokeObjectUrl(test);
    print("Done Chunks");
  }

  String prettyPrint(Map<String, dynamic> json) {
    JsonEncoder encoder = const JsonEncoder.withIndent("  ");
    String prettyString = encoder.convert(json);
    return prettyString;
  }
}
