/// 平台适配器存根（移动端用 - 无操作或简单替代）
import 'package:flutter/foundation.dart' show kIsWeb;

void openUrl(String url) {
  // 移动端暂不支持打开URL
}

bool isMobileBrowser() => false;

typedef void FileCallback(List<int> bytes);

void pickAndReadFile(String accept, FileCallback onLoaded) {
  // 移动端暂不支持文件选择，后续可加file_picker/image_picker
}

void takePhoto(void Function(List<int> bytes) onLoaded) {
  // 移动端暂不支持，后续可加image_picker
}
