import 'dart:typed_data';
import 'image_upload_helper_stub.dart'
    if (dart.library.html) 'image_upload_helper_web.dart' as impl;

class ImageFileResult {
  final Uint8List bytes;
  final String fileName;
  const ImageFileResult({required this.bytes, required this.fileName});
}

class ImageUploadHelper {
  static Future<ImageFileResult?> pickImage() => impl.pickImageImpl();
}
