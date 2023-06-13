import "dart:convert";
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
      token = jsonDecode(utf8.decode(response.bodyBytes))["sessionToken"];
      folderId = jsonDecode(utf8.decode(response.bodyBytes))["user"]["accounts"]
          [0]["rootFolderId"];
      loading = false;
    });
  }

  Future<void> pickFile() async {
    final input = FileUploadInputElement();

    input.onChange.listen((e) {
      final files = input.files;

      if (files!.isNotEmpty) {
        setState(() {
          file = files[0];
        });
        print(file!.size);
        print(file!.name);

        // Open http client
        // Generate a Key
        final Uint8List key = EncryptApi().generateAesKey();
        // Encrypt the Key

        // Init the Upload

        const chunkSize = 1024 * 1024 * 50; // 50MB chunk size
        final totalChunks = (file!.size / chunkSize).ceil();

        for (var i = 0; i < totalChunks; i++) {
          final start = i * chunkSize;
          final end = (start + chunkSize >= file!.size)
              ? file!.size
              : start + chunkSize;

          final chunk = file!.slice(start, end);
          final reader = FileReader();

          reader.onLoadEnd.listen((event) {
            if (reader.readyState == FileReader.DONE) {
              final chunkData = reader.result;


              if (i == totalChunks - 1) {

              }
            }
          });

          reader.readAsArrayBuffer(chunk);
        }
        // Get a Chunk
        // Encrypt that Chunk
        // Upload that chunk

        // End For Loop
        // Close Client?
      }
    });

    // Trigger the file picker dialog
    input.click();
  }

  Uint8List encryptChunk(Uint8List chunk, Uint8List key) {
    throw UnimplementedError();
  }
//
// void encryptFileInChunks(File file) {
//   final reader = FileReader();
//   final chunkSize = 1024; // Adjust the chunk size as per your requirement
//
//   reader.onLoad.listen((e) {
//     final fileContent = reader.result as List<int>;
//     final encryptedContent = encryptData(fileContent);
//     // Do something with the encrypted content, such as sending it to a server
//   });
//
//   int offset = 0;
//   void readChunk() {
//     final blob = file.slice(offset, offset + chunkSize);
//     reader.readAsArrayBuffer(blob);
//     offset += chunkSize;
//
//     if (offset < file.size) {
//       window.requestAnimationFrame((_) => readChunk());
//     }
//   }
//
//   readChunk();
// }
//
// List<int> encryptData(List<int> data) {
//   // Perform encryption using the crypto library
//   // Example: using AES encryption
//   final key = generateEncryptionKey(); // Generate your encryption key
//   // final cipher = AES(key);
//   final encryptedData = cipher.encrypt(data);
//   return encryptedData;
// }
//
// List<int> generateEncryptionKey() {
//   final random = Random.secure();
//   const keyLength = 32;
//   return List<int>.generate(keyLength, (_) => random.nextInt(256));
// }
//
}
