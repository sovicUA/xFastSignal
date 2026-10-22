import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Кореневий сертифікат внутрішнього CA, якому довіряє клієнт relay — додатково до
/// системних. Потрібен, бо HttpClient Dart не бачить сертифікатів, встановлених
/// користувачем в Android (`network_security_config` на нього не діє).
class TrustedCa {
  const TrustedCa({required this.name, required this.pem});

  /// Назва імпортованого файлу — лише для показу в налаштуваннях.
  final String name;

  /// Сертифікат(и) у PEM.
  final String pem;
}

/// Помилка імпорту сертифіката з повідомленням для користувача.
class TrustedCaException implements Exception {
  const TrustedCaException(this.message);

  final String message;

  @override
  String toString() => 'TrustedCaException: $message';
}

const _pemBegin = '-----BEGIN CERTIFICATE-----';
const _pemEnd = '-----END CERTIFICATE-----';

/// Перетворює вміст файлу сертифіката (PEM або DER — `.crt` / `.cer` / `.pem`) на PEM
/// і перевіряє, що його можна завантажити як довірений. Кидає [TrustedCaException].
String parseCaCertificate(List<int> bytes) {
  if (bytes.isEmpty) throw const TrustedCaException('Файл порожній');

  final text = latin1.decode(bytes, allowInvalid: true);
  final pem = text.contains(_pemBegin) ? text.trim() : _derToPem(bytes);

  try {
    SecurityContext(withTrustedRoots: false).setTrustedCertificatesBytes(utf8.encode(pem));
  } on TlsException {
    throw const TrustedCaException('Це не сертифікат X.509 (очікується .crt / .cer / .pem)');
  }
  return pem;
}

String _derToPem(List<int> der) {
  final base64 = base64Encode(der);
  final lines = [for (var i = 0; i < base64.length; i += 64) base64.substring(i, (i + 64).clamp(0, base64.length))];
  return [_pemBegin, ...lines, _pemEnd].join('\n');
}

/// HTTP-адаптер dio, що довіряє системним сертифікатам і [ca].
HttpClientAdapter trustingAdapter(TrustedCa ca) => IOHttpClientAdapter(
      createHttpClient: () => HttpClient(
        context: SecurityContext(withTrustedRoots: true)..setTrustedCertificatesBytes(utf8.encode(ca.pem)),
      ),
    );
