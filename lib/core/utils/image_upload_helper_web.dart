// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'image_upload_helper.dart';

Future<ImageFileResult?> pickImageImpl() async {
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'image/*';
  uploadInput.click();

  final completer = Completer<ImageFileResult?>();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete(ImageFileResult(bytes: result, fileName: file.name));
        } else if (result is ByteBuffer) {
          completer.complete(ImageFileResult(bytes: Uint8List.view(result), fileName: file.name));
        } else {
          completer.complete(null);
        }
      });
      reader.onError.listen((e) {
        completer.complete(null);
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
