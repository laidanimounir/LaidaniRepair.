import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class OfflineCache {
  static final OfflineCache _instance = OfflineCache._();
  factory OfflineCache() => _instance;
  OfflineCache._();

  Directory? _cacheDir;

  Future<Directory> get _directory async {
    if (_cacheDir != null) return _cacheDir!;
    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory('${tempDir.path}/laidani_cache');
    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }
    return _cacheDir!;
  }

  Future<void> set(String key, Map<String, dynamic> data) async {
    final dir = await _directory;
    final file = File('${dir.path}/${_sanitizeKey(key)}.json');
    await file.writeAsString(jsonEncode(data));
  }

  Future<Map<String, dynamic>?> get(String key) async {
    final dir = await _directory;
    final file = File('${dir.path}/${_sanitizeKey(key)}.json');
    if (!file.existsSync()) return null;
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<void> remove(String key) async {
    final dir = await _directory;
    final file = File('${dir.path}/${_sanitizeKey(key)}.json');
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final dir = await _directory;
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final result = <Map<String, dynamic>>[];
    for (final file in files) {
      final content = await file.readAsString();
      result.add(jsonDecode(content) as Map<String, dynamic>);
    }
    return result;
  }

  Future<void> clear() async {
    final dir = await _directory;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      _cacheDir = null;
    }
  }

  String _sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}
