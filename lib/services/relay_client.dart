import 'dart:io';

import 'package:dio/dio.dart';

import '../models/catalog.dart';
import 'trusted_ca.dart';

/// Помилка звернення до relay з повідомленням, придатним для показу користувачу.
class RelayException implements Exception {
  const RelayException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'RelayException($statusCode): $message';
}

/// HTTP-клієнт до xSignalRelay. Контракт — `backend/xSignalRelay/README.md`.
/// [trustedCa] — CA, якому довіряти додатково до системних (relay за внутрішнім HTTPS).
class RelayClient {
  RelayClient({required String baseUrl, required String apiKey, TrustedCa? trustedCa, Dio? dio})
      : _dio = dio ?? Dio() {
    if (dio == null && trustedCa != null) _dio.httpClientAdapter = trustingAdapter(trustedCa);
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 5)
      ..receiveTimeout = const Duration(seconds: 15)
      ..headers['X-Api-Key'] = apiKey;
  }

  final Dio _dio;

  Future<List<RelayTemplate>> templates() async {
    final data = await _get<List<dynamic>>('/templates');
    return data.map((e) => RelayTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RelayRecipient>> recipients() async {
    final data = await _get<List<dynamic>>('/recipients');
    return data.map((e) => RelayRecipient.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Catalog> catalog() async =>
      Catalog(templates: await templates(), recipients: await recipients());

  /// `POST /send`. Успіх — `202`; інакше кидає [RelayException].
  Future<void> send({
    required String templateId,
    required String target,
    Map<String, String>? params,
  }) =>
      _call(() => _dio.post<void>('/send', data: {
            'templateId': templateId,
            'target': target,
            if (params != null && params.isNotEmpty) 'params': params,
          }));

  Future<T> _get<T>(String path) async {
    final response = await _call(() => _dio.get<T>(path));
    return response.data as T;
  }

  Future<Response<T>> _call<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static RelayException _map(DioException e) {
    final response = e.response;
    if (response == null) {
      return RelayException(switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'Relay не відповідає (тайм-аут)',
        DioExceptionType.badCertificate => 'Сертифікат relay не довірений — імпортуйте CA в налаштуваннях',
        _ when e.error is HandshakeException =>
          'Сертифікат relay не довірений — імпортуйте CA в налаштуваннях',
        _ => 'Немає з\'єднання з relay',
      });
    }

    final status = response.statusCode;
    final body = response.data;
    final serverMessage = body is Map && body['error'] is String ? body['error'] as String : null;
    return RelayException(
      switch (status) {
        401 => 'Невірний API-ключ',
        403 => serverMessage ?? 'Одержувач не в allowlist',
        404 => serverMessage ?? 'Не знайдено',
        502 => serverMessage ?? 'signal-cli не надіслав повідомлення',
        _ => serverMessage ?? 'Помилка relay (HTTP $status)',
      },
      statusCode: status,
    );
  }
}
