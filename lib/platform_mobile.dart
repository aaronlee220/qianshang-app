/// 移动端平台实现 - 使用 image_picker
import 'dart:io';
import 'package:flutter/material.dart';
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
  // 显示选择对话框：拍照 / 从相册选择
  final navigator = _getNavigator();
  if (navigator == null) {
    // 回退到仅拍照
    await _pickImage(ImageSource.camera, onLoaded);
    return;
  }

  final source = await showDialog<ImageSource>(
    context: navigator.context,
    builder: (ctx) => AlertDialog(
      title: const Text('选择图片方式'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, size: 32),
            title: const Text('拍照'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, size: 32),
            title: const Text('从相册选择'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;
  await _pickImage(source, onLoaded);
}

NavigatorState? _getNavigator() {
  // 通过 WidgetsBinding 获取当前 Navigator
  final ctx = WidgetsBinding.instance.rootElement;
  if (ctx == null) return null;
  return Navigator.maybeOf(ctx);
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
