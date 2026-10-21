import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xfastsignal/app.dart';
import 'package:xfastsignal/services/relay_settings.dart';

void main() {
  group('normalizeBaseUrl', () {
    test('прибирає пробіли й кінцевий слеш', () {
      expect(normalizeBaseUrl('  http://10.0.2.2:5180/ '), 'http://10.0.2.2:5180');
    });

    test('відкидає не-http адреси', () {
      expect(normalizeBaseUrl('relay.example.com'), isNull);
      expect(normalizeBaseUrl('ftp://relay.example.com'), isNull);
      expect(normalizeBaseUrl(''), isNull);
    });
  });

  testWidgets('без налаштувань головний екран веде в налаштування', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const XFastSignalApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Вкажіть адресу relay і API-ключ'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Налаштувати'));
    await tester.pumpAndSettle();

    expect(find.text('Адреса relay'), findsOneWidget);
    expect(find.text('API-ключ'), findsOneWidget);
  });
}
