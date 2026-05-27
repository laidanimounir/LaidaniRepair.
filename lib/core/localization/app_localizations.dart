import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, String>? _strings;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _supportedLocales = [
    Locale('fr'),
    Locale('ar'),
    Locale('en'),
  ];

  static const List<Locale> supportedLocales = _supportedLocales;

  Future<void> load() async {
    final path = 'lib/l10n/${locale.languageCode}.json';
    final jsonStr = await rootBundle.loadString(path);
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    _strings = map.map((k, v) => MapEntry(k, v.toString()));
  }

  String translate(String key) => _strings?[key] ?? key;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['fr', 'ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(covariant _AppLocalizationsDelegate old) => false;
}
