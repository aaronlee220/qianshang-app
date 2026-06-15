/// Web平台实现 - 使用dart:html
import 'dart:html' as html;
import 'dart:typed_data';

void openUrl(String url) {
  html.window.open(url, '_blank');
}

bool isMobileBrowser() {
  return html.window.navigator.userAgent.toLowerCase().contains('mobile');
}

typedef void FileCallback(List<int> bytes);

void pickAndReadFile(String accept, FileCallback onLoaded) {
  final input = html.FileUploadInputElement()..accept = accept;
  if (isMobileBrowser()) {
    input.setAttribute('capture', 'environment');
  }
  input.click();
  input.onChange.listen((e) {
    if (input.files!.isEmpty) return;
    final file = input.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      onLoaded(reader.result as Uint8List);
    });
  });
}

void takePhoto(FileCallback onLoaded) {
  pickAndReadFile('image/*', onLoaded);
}
