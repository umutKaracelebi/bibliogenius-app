import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bibliogenius/utils/language_constants.dart';

void main() {
  group('parseLocaleTag', () {
    test('parses simple language code', () {
      final locale = parseLocaleTag('en');
      expect(locale.languageCode, 'en');
      expect(locale.countryCode, isNull);
    });

    test('parses regional tag with hyphen', () {
      final locale = parseLocaleTag('zh-CN');
      expect(locale.languageCode, 'zh');
      expect(locale.countryCode, 'CN');
    });

    test('parses regional tag with underscore', () {
      final locale = parseLocaleTag('zh_TW');
      expect(locale.languageCode, 'zh');
      expect(locale.countryCode, 'TW');
    });

    test('parses pt-BR correctly', () {
      final locale = parseLocaleTag('pt-BR');
      expect(locale.languageCode, 'pt');
      expect(locale.countryCode, 'BR');
    });

    test('normalizes case: lowercase language, uppercase country', () {
      final locale = parseLocaleTag('PT-br');
      expect(locale.languageCode, 'pt');
      expect(locale.countryCode, 'BR');
    });
  });

  group('localeToTag', () {
    test('returns simple code for language-only locale', () {
      expect(localeToTag(const Locale('en')), 'en');
      expect(localeToTag(const Locale('fr')), 'fr');
    });

    test('returns hyphenated tag for regional locale', () {
      expect(localeToTag(const Locale('zh', 'CN')), 'zh-CN');
      expect(localeToTag(const Locale('zh', 'TW')), 'zh-TW');
      expect(localeToTag(const Locale('pt', 'BR')), 'pt-BR');
    });

    test('round-trips with parseLocaleTag', () {
      for (final tag in ['en', 'fr', 'pt-BR', 'pt-PT', 'zh-CN', 'zh-TW']) {
        expect(localeToTag(parseLocaleTag(tag)), tag);
      }
    });
  });

  group('normalizeLanguageCode', () {
    test('strips regional suffix', () {
      expect(normalizeLanguageCode('zh-CN'), 'zh');
      expect(normalizeLanguageCode('zh-TW'), 'zh');
      expect(normalizeLanguageCode('pt-BR'), 'pt');
    });

    test('passes through simple codes', () {
      expect(normalizeLanguageCode('en'), 'en');
      expect(normalizeLanguageCode('fr'), 'fr');
    });
  });

  group('kLanguageNativeNames', () {
    test('contains Chinese regional variants', () {
      expect(kLanguageNativeNames['zh-CN'], '中文 (简体)');
      expect(kLanguageNativeNames['zh-TW'], '中文 (繁體)');
    });

    test('does not contain generic zh', () {
      expect(kLanguageNativeNames.containsKey('zh'), isFalse);
    });

    test('contains Portuguese regional variants', () {
      expect(kLanguageNativeNames['pt'], 'Português');
      expect(kLanguageNativeNames['pt-BR'], 'Português (Brasil)');
      expect(kLanguageNativeNames['pt-PT'], 'Português (Portugal)');
    });

    test('still contains all simple-code languages', () {
      expect(kLanguageNativeNames['en'], 'English');
      expect(kLanguageNativeNames['fr'], 'Français');
      expect(kLanguageNativeNames['de'], 'Deutsch');
      expect(kLanguageNativeNames['es'], 'Español');
      expect(kLanguageNativeNames['ja'], '日本語');
      expect(kLanguageNativeNames['ko'], '한국어');
    });
  });
}
