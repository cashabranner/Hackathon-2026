import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PickedComputerImage {
  final List<int> bytes;
  final String mimeType;
  final String name;

  const PickedComputerImage({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });
}

Future<PickedComputerImage?> pickImageFromComputer() {
  final completer = Completer<PickedComputerImage?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..multiple = false;
  input.style.display = 'none';
  web.document.body?.append(input);

  input.addEventListener(
      'change',
      ((web.Event _) {
        final files = input.files;
        final file = files != null && files.length > 0 ? files.item(0) : null;
        if (file == null) {
          if (!completer.isCompleted) completer.complete(null);
          input.remove();
          return;
        }

        final reader = web.FileReader();
        reader.addEventListener(
            'error',
            ((web.Event _) {
              if (!completer.isCompleted) {
                completer.completeError('Could not read selected image.');
              }
              input.remove();
            }).toJS);
        reader.addEventListener(
            'load',
            ((web.Event _) {
              final result = reader.result;
              if (result == null) {
                if (!completer.isCompleted) {
                  completer.completeError('Selected image could not be read.');
                }
                input.remove();
                return;
              }

              final buffer = (result as JSArrayBuffer).toDart;
              if (!completer.isCompleted) {
                completer.complete(
                  PickedComputerImage(
                    bytes: Uint8List.view(buffer),
                    mimeType: file.type.isNotEmpty ? file.type : 'image/jpeg',
                    name: file.name,
                  ),
                );
              }
              input.remove();
            }).toJS);
        reader.readAsArrayBuffer(file);
      }).toJS);

  input.click();
  return completer.future;
}
