/// 移动端平台实现 - 使用 image_picker
import 'dart:io';
import 'package:image_picker/image_picker.dart';

void openUrl(String url) {
  // 移动端暂不支持打开URL
}

bool isMobileBrowser() => false;

typedef void FileCallback(List<int> bytes);

void pickAndReadFile(String accept, FileCallback onLoaded) {
  // 移动端暂不支持文件选择
}

void takePhoto(FileCallback onLoaded) async {
  await _pickImage(ImageSource.camera, onLoaded);
}

void pickFromGallery(FileCallback onLoaded) async {
  await _pickImage(ImageSource.gallery, onLoaded);
}

Future<void> _pickImage(ImageSource source, FileCallback onLoaded) async {
  final picker = ImagePicker();
  try {
    final XFile? photo = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    onLoaded(bytes);
  } catch (e) {
    // 用户取消或出错
  }
}
