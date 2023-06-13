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
  final int _readStreamChunkSize = 128 * 10;
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
        // http.StreamedRequest request = http.StreamedRequest(
        //   "POST",
        //   Uri.parse("https://$host/${url}file/upload/$uniqueId"),
        // )
        //   ..headers["Authorization"] = token
        //   ..headers["ctype"] = "application/octet-stream";

        // Do the encryption here:
        final secretKey = SecretKey(aesKeyB);
        final nonce = _algorithm.newNonce();
        // Method in here to read the file a chunk at a time, print out the chunks

        // Use web crypto method 128*10 buffer

        // response is a byte buffer encrypted bytes
        final reader = FileReader();

        int start = 0;
        while (start < file!.size) {
          final end = start + _readStreamChunkSize > file!.size
              ? file!.size
              : start + _readStreamChunkSize;
          final blob = file!.slice(start, end);
          reader.readAsArrayBuffer(blob);
          await reader.onLoad.first;
          final result = reader.result;
          await Future.delayed(const Duration(microseconds: 1));
          if (result is ByteBuffer) {
            print( result.asUint8List());
          } else if (result is Uint8List) {
            print( result);
          }
          start += _readStreamChunkSize;
        }


        // EventSink<List<int>> requestSink = request.sink;
        // encryptStream.listen((chunk) {
        //   print(chunk.length);
        //   requestSink.add(chunk);
        // }).onDone(() {
        //   request.sink.close();
        // });

        // final uploadResponse = await request.send();
        // print(uploadResponse.request);
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
      final result = reader.result;
      await Future.delayed(const Duration(microseconds: 1));
      if (result is ByteBuffer) {
        yield result.asUint8List();
      } else if (result is Uint8List) {
        yield result;
      }
      start += _readStreamChunkSize;
    }
  }
}
