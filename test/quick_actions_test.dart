import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xfastsignal/app.dart';
import 'package:xfastsignal/models/catalog.dart';
import 'package:xfastsignal/models/quick_action.dart';
import 'package:xfastsignal/providers.dart';
import 'package:xfastsignal/screens/home_screen.dart';
import 'package:xfastsignal/services/quick_actions_store.dart';
import 'package:xfastsignal/services/relay_client.dart';
import 'package:xfastsignal/services/relay_settings.dart';

const _late = QuickAction(
  id: 'a1',
  templateId: 'running-late',
  templateName: 'Запізнююсь',
  recipientId: 'home',
  recipientName: 'Дружина',
  recipientKind: RecipientKind.contact,
  params: ['minutes'],
);

const _arrived = QuickAction(
  id: 'a2',
  templateId: 'arrived',
  templateName: 'На місці',
  recipientId: 'family',
  recipientName: 'Сім\'я',
  recipientKind: RecipientKind.group,
);

/// Відповідає 202 на будь-який запит і запам'ятовує тіла `POST /send`.
class _SendRecorder implements HttpClientAdapter {
  final sent = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path == '/send') sent.add(options.data as Map<String, dynamic>);
    return ResponseBody.fromString(jsonEncode({'sent': true}), 202, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<_SendRecorder> _pumpHome(WidgetTester tester, List<QuickAction> actions) async {
  SharedPreferences.setMockInitialValues({
    'relay_base_url': 'http://relay.test',
    'quick_actions': jsonEncode(actions),
  });
  FlutterSecureStorage.setMockInitialValues({'relay_api_key': 'k1'});
  final prefs = await SharedPreferences.getInstance();
  final recorder = _SendRecorder();
  final client = RelayClient(baseUrl: 'http://relay.test', apiKey: 'k1', dio: Dio()..httpClientAdapter = recorder);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      relayClientProvider.overrideWithValue(client),
    ],
    child: const XFastSignalApp(),
  ));
  await tester.pumpAndSettle();
  return recorder;
}

void main() {
  group('QuickAction', () {
    test('JSON туди й назад', () {
      const action = QuickAction(
        id: 'x',
        templateId: 't',
        templateName: 'Т',
        recipientId: 'r',
        recipientName: 'Р',
        recipientKind: RecipientKind.group,
        params: ['a', 'b'],
        fixed: {'a': '1'},
        label: 'Підпис',
      );
      final copy = QuickAction.fromJson(jsonDecode(jsonEncode(action)) as Map<String, dynamic>);
      expect(copy.toJson(), action.toJson());
      expect(copy.askedParams, ['b']);
      expect(copy.title, 'Підпис');
    });
  });

  test('сховище: додати, замінити, видалити — і все в SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    final store = container.read(quickActionsProvider.notifier);

    await store.put(_late);
    await store.put(_arrived);
    await store.put(QuickAction.fromJson({..._late.toJson(), 'label': 'Пізно'}));
    await store.remove(_arrived.id);

    expect(container.read(quickActionsProvider).single.title, 'Пізно');
    final saved = jsonDecode(prefs.getString('quick_actions')!) as List<dynamic>;
    expect(saved.single['label'], 'Пізно');
  });

  testWidgets('тап — відправка через sendDelay', (tester) async {
    final recorder = await _pumpHome(tester, [_arrived]);

    await tester.tap(find.text('На місці'));
    await tester.pump();
    expect(find.textContaining('Надсилаю «На місці»'), findsOneWidget);
    expect(recorder.sent, isEmpty);

    await tester.pump(sendDelay);
    await tester.pumpAndSettle();
    expect(recorder.sent.single, {'templateId': 'arrived', 'target': 'family'});
    expect(find.textContaining('✓ Надіслано'), findsOneWidget);
  });

  testWidgets('«Скасувати» — нічого не надсилається', (tester) async {
    final recorder = await _pumpHome(tester, [_arrived]);

    await tester.tap(find.text('На місці'));
    await tester.pump();
    // Snackbar виїжджає (~250 мс) — тапати, коли видно, як і людина
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Скасувати'));
    await tester.pump(sendDelay * 2);
    await tester.pumpAndSettle();

    expect(recorder.sent, isEmpty);
  });

  testWidgets('параметр «питати при тапі» — значення з діалогу', (tester) async {
    final recorder = await _pumpHome(tester, [_late]);

    await tester.tap(find.text('Запізнююсь'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '15');
    await tester.tap(find.widgetWithText(FilledButton, 'Надіслати'));
    await tester.pump();
    await tester.pump(sendDelay);
    await tester.pumpAndSettle();

    expect(recorder.sent.single['params'], {'minutes': '15'});
  });

  testWidgets('без кнопок — підказка додати першу', (tester) async {
    await _pumpHome(tester, []);
    expect(find.widgetWithText(FilledButton, 'Додати кнопку'), findsOneWidget);
  });
}
