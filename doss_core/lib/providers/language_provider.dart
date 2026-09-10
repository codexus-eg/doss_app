import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _key = 'doss_lang';
  bool _isArabic = false;

  bool get isArabic => _isArabic;
  Locale get locale => _isArabic ? const Locale('ar') : const Locale('en');
  TextDirection get textDirection =>
      _isArabic ? TextDirection.rtl : TextDirection.ltr;

  LanguageProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isArabic = prefs.getString(_key) == 'ar';
    notifyListeners();
  }

  Future<void> setArabic(bool val) async {
    _isArabic = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, val ? 'ar' : 'en');
    notifyListeners();
  }

  Future<void> toggle() => setArabic(!_isArabic);

  /// Shorthand: t('English text', 'نص عربي')
  String t(String en, String ar) => _isArabic ? ar : en;
}
