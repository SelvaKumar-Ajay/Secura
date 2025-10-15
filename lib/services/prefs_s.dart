import 'package:shared_preferences/shared_preferences.dart';

/// [Prefs] is used for to store simple/frequent usable data
class Prefs {
  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static void _ensureInitialized() {
    if (_prefs == null) {
      throw Exception('Prefs not initialized! Call Prefs.init() first.');
    }
  }

  static Future<bool> setString(String key, String value) async {
    return _prefs?.setString(key, value) ?? Future.value(false);
  }

  static Future<bool> setDouble(String key, double value) async {
    return _prefs?.setDouble(key, value) ?? Future.value(false);
  }

  static Future<bool> setBool(String key, bool value) async {
    return _prefs?.setBool(key, value) ?? Future.value(false);
  }

  static String getString(String key) {
    return _prefs?.getString(key) ?? "";
  }

  static double getDouble(String key) {
    return _prefs?.getDouble(key) ?? 0.0;
  }

  static bool getBool(String key) {
    return _prefs?.getBool(key) ?? false;
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    _ensureInitialized();
    return _prefs!.setStringList(key, value);
  }

  static List<String> getStringList(String key) {
    _ensureInitialized();
    return _prefs!.getStringList(key) ?? [];
  }

  static Future<bool> remove(String key) async {
    _ensureInitialized();
    return _prefs!.remove(key);
  }

  /// Clear all stored values
  static Future<bool> clearAll() async {
    return _prefs?.clear() ?? Future.value(false);
  }
}
