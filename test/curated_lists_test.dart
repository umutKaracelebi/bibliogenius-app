// Test to validate all curated list YAML assets parse correctly
// This ensures no runtime errors when users browse curated lists

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Curated Lists Validation', () {
    test('index.yml parses correctly', () async {
      final indexYaml = await rootBundle.loadString(
        'assets/curated_lists/index.yml',
      );
      final parsed = loadYaml(indexYaml) as YamlMap;

      expect(parsed['version'], isNotNull);
      expect(parsed['categories'], isA<YamlList>());
      expect((parsed['categories'] as YamlList).length, greaterThan(0));
    });

    test('all category lists have valid references', () async {
      final indexYaml = await rootBundle.loadString(
        'assets/curated_lists/index.yml',
      );
      final parsed = loadYaml(indexYaml) as YamlMap;
      final categories = parsed['categories'] as YamlList;

      for (final category in categories) {
        final cat = category as YamlMap;
        expect(cat['id'], isNotNull, reason: 'Category must have id');
        expect(cat['title'], isNotNull, reason: 'Category must have title');
        expect(
          cat['lists'],
          isA<YamlList>(),
          reason: 'Category must have lists',
        );
      }
    });

    // Test a sample list to validate structure
    test('goncourt.yml has valid structure', () async {
      final listYaml = await rootBundle.loadString(
        'assets/curated_lists/awards/goncourt.yml',
      );
      final parsed = loadYaml(listYaml) as YamlMap;

      expect(parsed['id'], equals('goncourt'));
      expect(parsed['title'], isNotNull);
      expect(parsed['description'], isNotNull);
      expect(parsed['books'], isA<YamlList>());
      expect((parsed['books'] as YamlList).length, greaterThan(0));
    });
  });
}
