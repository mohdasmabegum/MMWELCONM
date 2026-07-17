import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  // Replace these with your Cloudinary credentials after signing up at cloudinary.com
  static const String _cloudName = 'doo2pelu8';
  static const String _uploadPreset = 'mmwelcon';

  static const String _baseUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Uploads a file (mobile) and returns the secure URL
  static Future<String> uploadFile(File file, String uid) async {
    final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = 'mmwelconm/users/$uid';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    return _send(request);
  }

  /// Uploads raw bytes (web) and returns the secure URL
  static Future<String> uploadBytes(Uint8List bytes, String uid, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = 'mmwelconm/users/$uid';
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _send(request);
  }

  static Future<String> _send(http.MultipartRequest request) async {
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }
}
