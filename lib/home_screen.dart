// ignore_for_file: prefer_interpolation_to_compose_strings

import "dart:async";
import "dart:convert";
import "package:cryptography/cryptography.dart";
import "package:large_encryption/encrypter.dart";
import "package:universal_html/html.dart";
import "dart:typed_data";
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
  final int _readStreamChunkSize = 1000 * 1000; // 1 MB
  final _algorithm = AesGcm.with256bits();

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
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
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
      token = "Bearer " +
          jsonDecode(utf8.decode(response.bodyBytes))["sessionToken"];
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
        )
          ..headers["Authorization"] = token
          ..headers["ctype"] = "application/octet-stream";

        // Do the encryption here:
        final secretKey = SecretKey(aesKeyB);
        final nonce = _algorithm.newNonce();
        Stream<List<int>> encryptStream = _algorithm.encryptStream(
          _openFileReadStream(file!),
          secretKey: secretKey,
          nonce: nonce,
          onMac: (mac) {
            print(mac.bytes);
          },
        );
        EventSink<List<int>> requestSink = request.sink;
        await encryptStream.listen((chunk) {
          requestSink.add(chunk);
        }).asFuture();

        request.sink.close();

        final uploadResponse = await request.send();
        print(uploadResponse.request);
      }
    });

    input.click();
  }

  Stream<List<int>> _openFileReadStream(File file) async* {
    final reader = FileReader();

    int start = 0;
    while (start < file.size) {
      final end = start + _readStreamChunkSize > file.size
          ? file.size
          : start + _readStreamChunkSize;
      final blob = file.slice(start, end);
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;
      yield reader.result as List<int>;
      start += _readStreamChunkSize;
    }
  }
}
