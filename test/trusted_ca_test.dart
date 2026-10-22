import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xfastsignal/services/relay_client.dart';
import 'package:xfastsignal/services/trusted_ca.dart';

// test/fixtures: test-only CA ("xFastSignal Test CA") and a localhost certificate it signed.
List<int> _fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

void main() {
  group('parseCaCertificate', () {
    test('приймає PEM як є', () {
      final pem = parseCaCertificate(_fixture('ca.pem'));
      expect(pem, startsWith('-----BEGIN CERTIFICATE-----'));
    });

    test('перетворює DER на той самий PEM', () {
      final fromDer = parseCaCertificate(_fixture('ca.der'));
      final fromPem = parseCaCertificate(_fixture('ca.pem'));
      String body(String pem) => pem.replaceAll(RegExp(r'\s'), '');
      expect(body(fromDer), body(fromPem));
    });

    test('відхиляє порожній файл і не сертифікат', () {
      expect(() => parseCaCertificate([]), throwsA(isA<TrustedCaException>()));
      expect(() => parseCaCertificate(utf8.encode('not a certificate')), throwsA(isA<TrustedCaException>()));
    });
  });

  group('RelayClient через HTTPS з внутрішнім CA', () {
    late HttpServer server;

    setUpAll(() async {
      final context = SecurityContext()
        ..useCertificateChainBytes(_fixture('server.pem'))
        ..usePrivateKeyBytes(_fixture('server.key'));
      server = await HttpServer.bindSecure('localhost', 0, context);
      server.listen((request) {
        final body = switch (request.uri.path) {
          '/templates' => [
              {'id': 'late', 'name': 'Запізнююсь', 'params': ['minutes']},
            ],
          '/recipients' => [
              {'id': 'me', 'kind': 'Contact', 'displayName': 'Собі'},
            ],
          _ => null,
        };
        request.response
          ..statusCode = body == null ? 404 : 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body))
          ..close();
      });
    });

    tearDownAll(() => server.close(force: true));

    String url() => 'https://localhost:${server.port}';

    test('з імпортованим CA — з\'єднання є', () async {
      final ca = TrustedCa(name: 'ca.pem', pem: parseCaCertificate(_fixture('ca.pem')));
      final catalog = await RelayClient(baseUrl: url(), apiKey: 'k', trustedCa: ca).catalog();
      expect(catalog.templates.single.id, 'late');
    });

    test('без CA — зрозуміла помилка про сертифікат', () async {
      await expectLater(
        RelayClient(baseUrl: url(), apiKey: 'k').catalog(),
        throwsA(isA<RelayException>().having((e) => e.message, 'message', contains('Сертифікат relay не довірений'))),
      );
    });
  });
}
