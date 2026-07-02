import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads [file] to chat-images/{chatId}/{fileName} and returns the download URL.
  /// [onProgress] receives 0.0–1.0 upload progress.
  Future<String> uploadChatImage(
    String chatId,
    File file, {
    void Function(double)? onProgress,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = _storage.ref('chat-images/$chatId/$fileName');
    final task = ref.putFile(file);
    task.snapshotEvents.listen((snap) {
      if (onProgress != null && snap.totalBytes > 0) {
        onProgress(snap.bytesTransferred / snap.totalBytes);
      }
    });
    await task;
    return await ref.getDownloadURL();
  }
}
