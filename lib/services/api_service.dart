import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  ApiService._();

  final _storage = const FlutterSecureStorage();
  String? _baseUrl;
  String? _token;
  String? _ip;
  String? _port;

  Future<void> configure(String ip, int port) async {
    _ip = ip;
    _port = port.toString();
    _baseUrl = 'https://$ip:$port';
    await _storage.write(key: 'server_ip', value: ip);
    await _storage.write(key: 'server_port', value: port.toString());
  }

  Future<bool> loadSavedConfig() async {
    _ip = await _storage.read(key: 'server_ip');
    _port = await _storage.read(key: 'server_port');
    if (_ip != null && _port != null) {
      _baseUrl = 'https://$_ip:$_port';
      _token = await _storage.read(key: 'jwt_token');
      return true;
    }
    return false;
  }

  String? get ip => _ip;
  String? get port => _port;

  http.Client _buildClient() {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return _IOClient(client);
  }

  Future<LoginResult> login(String pin) async {
    try {
      final client = _buildClient();
      final deviceMac = await _storage.read(key: 'pc_mac') ?? 'mobile-app';
      final response = await client.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pin': pin,
          'mac': deviceMac,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        await _storage.write(key: 'jwt_token', value: _token);
        return const LoginResult(success: true);
      } else {
        final error = jsonDecode(response.body);
        return LoginResult(
          success: false,
          message: error['detail'] ?? 'error_response',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      return const LoginResult(success: false, message: 'socket_connection_refused');
    } catch (e) {
      return LoginResult(success: false, message: 'runtime_error: $e');
    }
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  Future<ApiResult> get(String path) async {
    try {
      final client = _buildClient();
      final response = await client.get(
        Uri.parse('$_baseUrl$path'),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 8));
      return _handleResponse(response);
    } catch (e) {
      return ApiResult(success: false, message: e.toString());
    }
  }

  Future<ApiResult> post(String path, [Map<String, dynamic>? body]) async {
    try {
      final client = _buildClient();
      final response = await client.post(
        Uri.parse('$_baseUrl$path'),
        headers: _authHeaders,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 8));
      return _handleResponse(response);
    } catch (e) {
      return ApiResult(success: false, message: e.toString());
    }
  }

  ApiResult _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResult(
        success: true,
        data: jsonDecode(response.body),
      );
    } else if (response.statusCode == 401) {
      _token = null;
      _storage.delete(key: 'jwt_token');
      return const ApiResult(success: false, message: 'unauthorized', statusCode: 401);
    } else {
      final error = jsonDecode(response.body);
      return ApiResult(
        success: false,
        message: error['detail'] ?? 'server_error',
        statusCode: response.statusCode,
      );
    }
  }

  Future<bool> isServerReachable() async {
    try {
      final client = _buildClient();
      final response = await client.get(
        Uri.parse('$_baseUrl/ping'),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  bool get hasToken => _token != null;

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: 'jwt_token');
  }
}

class LoginResult {
  final bool success;
  final String? message;
  final int? statusCode;
  const LoginResult({required this.success, this.message, this.statusCode});
}

class ApiResult {
  final bool success;
  final dynamic data;
  final String? message;
  final int? statusCode;
  const ApiResult({required this.success, this.data, this.message, this.statusCode});
}

class _IOClient extends http.BaseClient {
  final HttpClient _client;
  _IOClient(this._client);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ioRequest = await _client.openUrl(request.method, request.url);
    request.headers.forEach(ioRequest.headers.set);
    if (request is http.Request && request.body.isNotEmpty) {
      ioRequest.add(request.bodyBytes);
    }
    final response = await ioRequest.close();
    final Map<String, String> headers = {};
    response.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });
    return http.StreamedResponse(
      response.asBroadcastStream(),
      response.statusCode,
      headers: headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
