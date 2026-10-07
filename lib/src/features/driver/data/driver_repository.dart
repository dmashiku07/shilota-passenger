import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/driver_models.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
  );
});

class DriverRepository {
  DriverRepository({
    required Dio dio,
    required this.sessionStorage,
  }) : _dio = dio;

  final Dio _dio;
  final SessionStorage sessionStorage;

  Future<DriverAdminData> getAdminData() async {
    final body = await _getJson('driverapi/admindatas', needsAuth: false);
    return DriverAdminData.fromJson(body);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final body = await _postJson(
      'driverapi/signin',
      {
        'email': email,
        'password': password,
      },
      needsAuth: false,
    );
    _assertSuccess(body);
    final session = DriverSession.fromJson(body);
    if (!session.isComplete) {
      throw const DriverApiException('Incomplete driver account data');
    }
    await sessionStorage.saveSession(
      token: session.token,
      userId: session.userId,
      fullName: session.fullName,
      email: session.email,
      wallet: session.wallet,
      userImage: session.userImage,
      password: password,
    );
    await pushSignIn();
  }

  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
    required String location,
  }) async {
    final body = await _postJson(
      'driverapi/signup',
      {
        'full_name': fullName,
        'email': email,
        'password': password,
        'location': location,
      },
      needsAuth: false,
    );
    _assertSuccess(body);
  }

  Future<DriverProfile> getProfile() async {
    final userId = _requireUserId();
    final body = await _getJson('driverapi/profile/$userId');
    return DriverProfile.fromJson(body);
  }

  Future<DriverDashboard> getDashboard() async {
    final userId = _requireUserId();
    final body = await _getJson('driverapi/dashboard/$userId');
    return DriverDashboard.fromJson(body);
  }

  Future<List<DriverListItem>> getNotifications() async {
    final userId = _requireUserId();
    final body = await _getJson('driverapi/notifications/$userId');
    return _extractItems(body).map(DriverListItem.fromJson).toList();
  }

  Future<List<DriverListItem>> getUpcomingRides() async {
    final userId = _requireUserId();
    final body = await _getJson('driverapi/scheduledupcoming/$userId');
    return _extractItems(body).map(DriverListItem.fromJson).toList();
  }

  Future<List<DriverListItem>> getRideHistory() async {
    final body = await _postJson(
      'driverapi/ridehistory',
      {
        'user_id': _requireUserId(),
      },
    );
    return _extractItems(body).map(DriverListItem.fromJson).toList();
  }

  Future<List<DriverListItem>> getWalletHistory() async {
    final userId = _requireUserId();
    final body = await _getJson('driverapi/wallethistory/$userId');
    return _extractItems(body).map(DriverListItem.fromJson).toList();
  }

  Future<List<DriverListItem>> getSubscriptionPlans() async {
    final userId = _requireUserId();
    final body = await _getJson('driverapi/subscriptionplans/$userId');
    return _extractItems(body).map(DriverListItem.fromJson).toList();
  }

  Future<List<DriverListItem>> getDestinationBroadcasts() async {
    final userId = _requireUserId();
    final body = await _getJson('driverapi/destinationbroadcasts/$userId');
    return _extractItems(body).map(DriverListItem.fromJson).toList();
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    final body = await _postJson(
      'driverapi/liveme',
      {
        'user_id': _requireUserId(),
        'status': isOnline ? 'online' : 'offline',
      },
    );
    _assertSuccess(body);
  }

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _postJson(
      'driverapi/whereiam',
      {
        'user_id': _requireUserId(),
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      },
    );
  }

  Future<void> pushSignIn() async {
    try {
      await _postJson(
        'driverapi/pushsignin',
        {
          'user_id': _requireUserId(),
          'device_token': '',
          'device_type': '1',
          'device_id': '',
          'lang_type': 'en',
        },
      );
    } on DriverApiException {
      // Do not block login when device-token registration is unavailable.
    }
  }

  Future<void> logout() async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        'driverapi/pushsignout',
        data: {
          'user_id': sessionStorage.userId,
          'device_id': '',
        },
        options: _options(needsAuth: true),
      );
    } on DioException {
      // Local logout should continue when the network is unavailable.
    } finally {
      await sessionStorage.clear();
    }
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    bool needsAuth = true,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        options: _options(needsAuth: needsAuth),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw DriverApiException(_resolveDioMessage(error));
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> data, {
    bool needsAuth = true,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: _options(needsAuth: needsAuth),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw DriverApiException(_resolveDioMessage(error));
    }
  }

  Options _options({required bool needsAuth}) {
    return Options(
      contentType: Headers.formUrlEncodedContentType,
      headers: needsAuth && sessionStorage.token != null
          ? {
              'Authorization': sessionStorage.token,
            }
          : null,
    );
  }

  void _assertSuccess(Map<String, dynamic> body) {
    final status = body['status']?.toString().toLowerCase();
    if (status == 'true' || status == 'success') {
      return;
    }
    throw DriverApiException(
      body['message']?.toString() ?? 'Unable to complete request',
    );
  }

  String _requireUserId() {
    final userId = sessionStorage.userId;
    if (userId == null || userId.isEmpty) {
      throw const DriverApiException('Driver session is missing');
    }
    return userId;
  }

  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> body) {
    const keys = [
      'data',
      'result',
      'rides',
      'history',
      'notifications',
      'plans',
      'subscriptions',
      'broadcasts',
      'wallet_history',
    ];
    for (final key in keys) {
      final value = body[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  String _resolveDioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
    }
    final statusCode = error.response?.statusCode;
    if (statusCode == 404) {
      return 'Driver API route was not found. Check the server base URL.';
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

class DriverApiException implements Exception {
  const DriverApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
