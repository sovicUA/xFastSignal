import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xfastsignal/models/catalog.dart';
import 'package:xfastsignal/services/relay_client.dart';

/// Відповідає заздалегідь заданими (status, body) і запам'ятовує запити.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final (int, Object?) Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(RelayClient, _FakeAdapter) _client((int, Object?) Function(RequestOptions) respond) {
  final adapter = _FakeAdapter(respond);
  final dio = Dio()..httpClientAdapter = adapter;
  return (RelayClient(baseUrl: 'http://relay.test', apiKey: 'k1', dio: dio), adapter);
}

void main() {
  test('catalog парсить шаблони й одержувачів і шле X-Api-Key', () async {
    final (client, adapter) = _client((o) => switch (o.path) {
          '/templates' => (200, [
              {'id': 'late', 'name': 'Запізнююсь', 'params': ['minutes']},
            ]),
          '/recipients' => (200, [
              {'id': 'g', 'kind': 'Group', 'displayName': 'Сім\'я'},
              {'id': 'me', 'kind': 'Contact', 'displayName': 'Собі'},
            ]),
          _ => (404, null),
        });

    final catalog = await client.catalog();

    expect(catalog.templates.single.params, ['minutes']);
    expect(catalog.recipients.map((r) => r.kind), [RecipientKind.group, RecipientKind.contact]);
    expect(adapter.requests.every((r) => r.headers['X-Api-Key'] == 'k1'), isTrue);
  });

  test('send передає params лише коли вони є', () async {
    final (client, adapter) = _client((_) => (202, {'sent': true}));

    await client.send(templateId: 'arrived', target: 'me');
    await client.send(templateId: 'late', target: 'me', params: {'minutes': '15'});

    expect(adapter.requests[0].data, {'templateId': 'arrived', 'target': 'me'});
    expect(adapter.requests[1].data, {
      'templateId': 'late',
      'target': 'me',
      'params': {'minutes': '15'},
    });
  });

  test('401 → «Невірний API-ключ»', () async {
    final (client, _) = _client((_) => (401, null));
    await expectLater(
      client.templates(),
      throwsA(isA<RelayException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', 'Невірний API-ключ')),
    );
  });

  test('помилка сервера показує поле error з тіла', () async {
    final (client, _) = _client((_) => (400, {'error': 'Не задано значення для плейсхолдера \'{minutes}\''}));
    await expectLater(
      client.send(templateId: 'late', target: 'me'),
      throwsA(isA<RelayException>().having((e) => e.message, 'message', contains('{minutes}'))),
    );
  });
}
