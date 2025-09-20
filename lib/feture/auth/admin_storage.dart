import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AdminStorage {
  static Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/admin.json');
  }

  // حفظ اسم المستخدم
  static Future<void> saveUsername(String username) async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode({"username": username}));
  }

  // قراءة اسم المستخدم
  static Future<String?> getUsername() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final data = jsonDecode(content);
      return data['username'];
    } catch (e) {
      return null;
    }
  }

  // حذف اسم المستخدم
  static Future<void> clear() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
