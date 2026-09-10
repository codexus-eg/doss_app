import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../constants/constants.dart';

// ─── Custom Exception ──────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => 'ApiException($statusCode): $message';

  bool get isUnauthorized  => statusCode == 401;
  bool get isForbidden     => statusCode == 403;
  bool get isNotFound      => statusCode == 404;
  bool get isServerError   => (statusCode ?? 0) >= 500;
  bool get isNetworkError  => statusCode == null;
}

// ─── API Client ────────────────────────────────────────────────────────────
class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  String? _token; // in-memory auth token (hot path; avoids storage stalls)

  static ApiClient? _instance;
  static ApiClient get instance {
    _instance ??= ApiClient._internal();
    return _instance!;
  }

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout:    const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        var token = _token;
        if (token == null) {
          try {
            token = await _storage.read(key: 'auth_token')
                .timeout(const Duration(seconds: 2));
            _token = token;
          } catch (_) {/* storage stalled — proceed without header */}
        }
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (err, handler) {
        _log.e('API ← ${err.requestOptions.method} '
               '${err.requestOptions.path}',
               error: err.message);
        handler.next(err);
      },
    ));
  }

  String? _baseUrl;
  void configure(String baseUrl) {
    _baseUrl = baseUrl;
    _dio.options.baseUrl = baseUrl;
  }
  void _ensureBaseUrl() {
    if (_dio.options.baseUrl.isEmpty) {
      _dio.options.baseUrl = AppConstants.defaultApiUrl;
    }
  }
  String get baseUrl => _baseUrl ?? AppConstants.defaultApiUrl;

  // ── tRPC Query (GET) ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> query(
    String procedure, {
    Map<String, dynamic>? input,
  }) async {
    _ensureBaseUrl();
    try {
      final encoded = input != null
          ? Uri.encodeComponent(jsonEncode({'json': input}))
          : null;
      final path =
          '/api/trpc/$procedure${encoded != null ? '?input=$encoded' : ''}';
      final response = await _dio.get<Map<String, dynamic>>(path);
      return _unwrap(response.data!);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── tRPC Mutation (POST) ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> mutate(
    String procedure, {
    Map<String, dynamic>? input,
  }) async {
    _ensureBaseUrl();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/trpc/$procedure',
        data: {'json': input ?? {}},
      );
      return _unwrap(response.data!);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── Response Unwrapper ───────────────────────────────────────────────────
  Map<String, dynamic> _unwrap(Map<String, dynamic> raw) {
    if (raw.containsKey('result')) {
      final result = raw['result'] as Map<String, dynamic>;
      final data = result['data'];
      final payload = (data is Map<String, dynamic> && data.containsKey('json'))
          ? data['json']
          : data;
      if (payload is Map<String, dynamic>) return payload;
      // Procedures that return a bare array are exposed under 'items' so
      // callers always receive a map instead of a failed cast.
      if (payload is List) return {'items': payload};
      return {};
    }
    // Direct response (non-tRPC wrapper)
    return raw;
  }

  // ── Error Mapper ─────────────────────────────────────────────────────────
  // The server runs tRPC with `transformer: superjson`, which nests the error
  // envelope one level deeper, under `json`:
  //   {"error":{"json":{"message":"…","data":{"code":"BAD_REQUEST"}}}}
  // Untransformed tRPC uses {"error":{"message":"…","data":{…}}}, so both
  // shapes are handled here.
  ApiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    String msg = 'Something went wrong';
    String? code;
    try {
      final data = e.response?.data;
      if (data is Map) {
        final error = data['error'];
        final body = (error is Map && error['json'] is Map)
            ? error['json'] as Map
            : (error is Map ? error : null);
        final errorData = body?['data'];
        if (errorData is Map) code = errorData['code'] as String?;
        msg = (body?['message'] as String?) ??
              (data['message']  as String?) ?? msg;
      }
    } catch (_) {}

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout    ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException('Connection timed out. Check your internet.',
          statusCode: null);
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException('No internet connection.', statusCode: null);
    }
    _log.e('API error ${status ?? '-'} ${code ?? ''} '
           '${e.requestOptions.path}: $msg');
    return ApiException(msg, statusCode: status, code: code);
  }

  // ── Token Management ─────────────────────────────────────────────────────
  Future<void> saveToken(String token) async {
    _token = token;
    try {
      await _storage.write(key: 'auth_token', value: token)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<String?> getToken() async {
    if (_token != null) return _token;
    try {
      return _token = await _storage.read(key: 'auth_token')
          .timeout(const Duration(seconds: 2));
    } catch (_) { return null; }
  }

  Future<void> clearToken() async {
    _token = null;
    try {
      await _storage.delete(key: 'auth_token').timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
