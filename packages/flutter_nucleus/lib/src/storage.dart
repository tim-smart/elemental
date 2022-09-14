import 'dart:convert';

import 'package:flutter_nucleus/flutter_nucleus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsStorage implements NucleusStorage {
  const SharedPrefsStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  Object? get(String key) {
    final json = _prefs.getString(key);
    if (json == null) return null;
    return jsonDecode(json);
  }

  @override
  void set(String key, Object? value) {
    _prefs.setString(key, jsonEncode(value));
  }
}
