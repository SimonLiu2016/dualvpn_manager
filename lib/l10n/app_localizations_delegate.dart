import 'package:flutter/material.dart';
import 'app_zh.dart';
import 'app_en.dart';
import 'app_fr.dart';

/// 国际化资源管理器
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // 静态方法获取当前本地化实例
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // 定义支持的语言
  static const List<Locale> supportedLocales = [
    Locale('zh', ''), // 简体中文
    Locale('en', ''), // 英文
    Locale('fr', ''), // 法文
  ];

  // 获取本地化文本
  String get(String key) {
    final Map<String, Map<String, String>> localizedValues = {
      'zh': AppLocalizationsZh.localizedValues,
      'en': AppLocalizationsEn.localizedValues,
      'fr': AppLocalizationsFr.localizedValues,
    };

    final languageCode = locale.languageCode;
    final values =
        localizedValues[languageCode] ?? AppLocalizationsZh.localizedValues;
    return values[key] ?? key;
  }
}
