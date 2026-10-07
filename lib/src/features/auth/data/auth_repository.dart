import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
  );
});

class AuthRepository {
  AuthRepository({
    required Dio dio,
    required this.sessionStorage,
  }) : _dio = dio;

  final Dio _dio;
  final SessionStorage sessionStorage;

  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final data = await _postAuth(
      'api/signup',
      {
        'full_name': fullName,
        'email': email,
        'password': password,
      },
    );

    if (!data.isSuccess) {
      throw AuthException(data.message);
    }
  }

  Future<AuthResponse> requestOtp({
    required String phoneNumber,
  }) async {
    final data = await _postAuth(
      'api/getotp',
      {
        'phone_number': phoneNumber,
      },
    );

    if (!data.isSuccess) {
      throw AuthException(data.message);
    }

    return data;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await _postAuth(
      'api/signIn',
      {
        'email': email,
        'password': password,
      },
    );

    if (!data.isSuccess) {
      throw AuthException(data.message);
    }

    await _saveSession(data);
    await _pushSignIn(token: data.token, userId: data.userId);
  }

  Future<void> completeSignup({
    required PendingSignup signup,
    required String phoneNumber,
  }) async {
    final data = await _postAuth(
      'api/signIn',
      {
        'email': signup.email,
        'password': signup.password,
        'phone_number': phoneNumber,
        'country_code': signup.countryCode,
      },
    );

    if (!data.isSuccess) {
      throw AuthException(data.message);
    }

    await _saveSession(data);
    await _pushSignIn(token: data.token, userId: data.userId);
  }

  Future<AuthResponse> _postAuth(
      String path, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final body = response.data;
      if (body == null) {
        throw const AuthException('Empty server response');
      }

      return AuthResponse.fromJson(body);
    } on DioException catch (error) {
      final message = _resolveDioMessage(error);
      throw AuthException(message);
    }
  }

  Future<void> _saveSession(AuthResponse data) async {
    final token = data.token;
    final userId = data.userId;
    final fullName = data.fullName;

    if (token == null || userId == null || fullName == null) {
      throw const AuthException('Incomplete account data from server');
    }

    await sessionStorage.saveSession(
      token: token,
      userId: userId,
      fullName: fullName,
      userImage: data.userImage,
      wallet: data.walletMoney,
      email: data.email,
      phoneNumber: data.phoneNumber,
      countryCode: data.countryCode,
      password: data.password,
    );
  }

  Future<void> _pushSignIn({
    required String? token,
    required String? userId,
  }) async {
    if (token == null || userId == null) {
      return;
    }

    try {
      await _dio.post<Map<String, dynamic>>(
        'api/pushsignin',
        data: {
          'user_id': userId,
          'device_token': '',
          'device_type': '1',
          'device_id': '',
          'lang_type': 'en',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Authorization': token,
          },
        ),
      );
    } on DioException {
      // Keep login successful even when push registration is unavailable.
    }
  }

  String _resolveDioMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 300 && statusCode < 400) {
      return 'Unable to connect securely. Please try again.';
    }

    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Unable to reach the server. Check your connection and try again.';
      default:
        return 'Unable to complete request. Please try again.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
