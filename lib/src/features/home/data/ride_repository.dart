import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/ride_models.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
  );
});

class RideRepository {
  RideRepository({
    required Dio dio,
    required SessionStorage sessionStorage,
  })  : _dio = dio,
        _sessionStorage = sessionStorage;

  final Dio _dio;
  final SessionStorage _sessionStorage;

  Future<String> getRoutePolyline({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    List<RideStop> rideStops = const <RideStop>[],
  }) async {
    final body = await _post(
      'api/routepath',
      {
        'user_id': _requireUserId(),
        'pickup_lat': '$pickupLat',
        'pickup_lng': '$pickupLng',
        'drop_lat': '$dropLat',
        'drop_lng': '$dropLng',
        'ride_stops': jsonEncode(
          rideStops
              .asMap()
              .entries
              .map((entry) =>
                  entry.value.copyWith(sequence: entry.key + 1).toJson())
              .toList(),
        ),
      },
    );
    if (body['status']?.toString() != 'true') {
      throw RideException(body['message']?.toString() ?? 'Route unavailable');
    }
    final encoded = body['encoded_polyline']?.toString() ?? '';
    if (encoded.isEmpty) {
      throw const RideException('Route unavailable');
    }
    return encoded;
  }

  Future<RideQuoteResponse> getRideQuotes({
    required String pickupLocation,
    required double pickupLat,
    required double pickupLng,
    required String dropLocation,
    required double dropLat,
    required double dropLng,
    required String distanceKm,
  }) async {
    final body = await _post(
      'api/grabrides',
      {
        'user_id': _requireUserId(),
        'pickup_location': pickupLocation,
        'pickup_lat': '$pickupLat',
        'pickup_lng': '$pickupLng',
        'drop_location': dropLocation,
        'drop_lat': '$dropLat',
        'drop_lng': '$dropLng',
        'distance': distanceKm,
      },
    );
    return RideQuoteResponse.fromJson(body);
  }

  Future<PoolingSettings> getPoolingSettings({
    required double pickupLat,
    required double pickupLng,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'api/poolsettings',
      queryParameters: {
        'pickup_lat': '$pickupLat',
        'pickup_lng': '$pickupLng',
      },
      options: _authorizedOptions(),
    );
    final body = response.data;
    if (body == null) {
      throw const RideException('Empty pooling settings response');
    }
    return PoolingSettings.fromJson(body);
  }

  Future<RequestRideResponse> requestRide({
    required String pickupLocation,
    required double pickupLat,
    required double pickupLng,
    required String dropLocation,
    required double dropLat,
    required double dropLng,
    required AvailableRideItem category,
    required String basePrice,
    String type = 'now',
    String paymentType = 'cash',
    bool poolingOptIn = false,
    int seatsRequested = 1,
    DeliveryDetails? deliveryDetails,
    DateTime? scheduledAt,
    List<RideStop> rideStops = const <RideStop>[],
    bool usePassengerPriceBroadcast = false,
    double? passengerOfferedPrice,
    double? broadcastRadiusKm,
  }) async {
    final payload = <String, dynamic>{
      'user_id': _requireUserId(),
      'pickup_location': pickupLocation,
      'pickup_lat': '$pickupLat',
      'pickup_lng': '$pickupLng',
      'drop_location': dropLocation,
      'drop_lat': '$dropLat',
      'drop_lng': '$dropLng',
      'category_id': category.id,
      'type': type,
      'payment_type': paymentType,
      'baseprice': basePrice,
      'ride_stops': jsonEncode(
        rideStops
            .asMap()
            .entries
            .map((entry) =>
                entry.value.copyWith(sequence: entry.key + 1).toJson())
            .toList(),
      ),
      'service_type':
          category.serviceType.isEmpty ? 'ride' : category.serviceType,
      'pooling_opt_in': poolingOptIn ? 'true' : 'false',
      'seats_requested': '$seatsRequested',
      'delivery_details': jsonEncode(
        (deliveryDetails ??
                const DeliveryDetails(
                  parcelType: '',
                  parcelSize: '',
                  recipientName: '',
                  recipientPhone: '',
                  senderNote: '',
                  handoffCode: '',
                  proofRequired: false,
                ))
            .toJson(),
      ),
    };

    if (type == 'schedule' && scheduledAt != null) {
      payload['schedule_time'] =
          (scheduledAt.millisecondsSinceEpoch / 1000).floor().toString();
      payload['schedule_utc_time'] = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
          .format(scheduledAt.toUtc());
    }

    if (usePassengerPriceBroadcast) {
      payload['request_type'] = 'PASSENGER_PRICE_BROADCAST';
      payload['pricing_mode'] = 'passenger_broadcast';
      if (passengerOfferedPrice != null) {
        payload['passenger_offered_price'] = passengerOfferedPrice.toString();
      }
      if (broadcastRadiusKm != null) {
        payload['broadcast_radius'] = broadcastRadiusKm.toString();
      }
      payload['passenger_price_broadcast'] = 'true';
    }

    final body = await _post(
      'api/requestride',
      payload,
    );
    return RequestRideResponse.fromJson(body);
  }

  Future<RequestRideResponse> updateScheduledRide({
    required String onRideId,
    required String pickupLocation,
    required double pickupLat,
    required double pickupLng,
    required String dropLocation,
    required double dropLat,
    required double dropLng,
    required AvailableRideItem category,
    required String basePrice,
    bool poolingOptIn = false,
    int seatsRequested = 1,
    DeliveryDetails? deliveryDetails,
    required DateTime scheduledAt,
    List<RideStop> rideStops = const <RideStop>[],
  }) async {
    final body = await _post(
      'api/updatescheduledride',
      {
        'user_id': _requireUserId(),
        'onride_id': onRideId,
        'pickup_location': pickupLocation,
        'pickup_lat': '$pickupLat',
        'pickup_lng': '$pickupLng',
        'drop_location': dropLocation,
        'drop_lat': '$dropLat',
        'drop_lng': '$dropLng',
        'category_id': category.id,
        'payment_type': 'cash',
        'baseprice': basePrice,
        'ride_stops': jsonEncode(
          rideStops
              .asMap()
              .entries
              .map((entry) =>
                  entry.value.copyWith(sequence: entry.key + 1).toJson())
              .toList(),
        ),
        'service_type':
            category.serviceType.isEmpty ? 'ride' : category.serviceType,
        'pooling_opt_in': poolingOptIn ? 'true' : 'false',
        'seats_requested': '$seatsRequested',
        'delivery_details': jsonEncode(
          (deliveryDetails ??
                  const DeliveryDetails(
                    parcelType: '',
                    parcelSize: '',
                    recipientName: '',
                    recipientPhone: '',
                    senderNote: '',
                    handoffCode: '',
                    proofRequired: false,
                  ))
              .toJson(),
        ),
        'schedule_time':
            (scheduledAt.millisecondsSinceEpoch / 1000).floor().toString(),
        'schedule_utc_time': DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
            .format(scheduledAt.toUtc()),
      },
    );
    return RequestRideResponse.fromJson(body);
  }

  Future<ConfirmRideResponse> confirmRide(String onrideId) async {
    final body = await _post(
      'api/confirmride',
      {
        'user_id': _requireUserId(),
        'onride_id': onrideId,
        'is_notify': '1',
      },
    );
    return ConfirmRideResponse.fromJson(body);
  }

  Future<Map<String, String>?> getActiveRide() async {
    final body = await _post(
      'api/activeride',
      {'user_id': _requireUserId()},
    );
    if (body['status']?.toString() != 'true') {
      return null;
    }
    final onrideId = body['onride_id']?.toString() ?? '';
    if (onrideId.isEmpty) {
      return null;
    }
    return body.map(
      (key, dynamic value) => MapEntry(key, value?.toString() ?? ''),
    );
  }

  Future<String> getRideStatus(String onrideId) async {
    final body = await _post(
      'api/ridestatus',
      {
        'user_id': _requireUserId(),
        'onride_id': onrideId,
      },
    );
    if (body['status']?.toString() != 'true') {
      throw RideException(body['message']?.toString() ?? 'Ride unavailable');
    }
    return body['ride_status']?.toString().trim().toLowerCase() ?? '';
  }

  Future<ConfirmRideResponse> getRideOffers(String onrideId) async {
    final body = await _post(
      'api/rideoffers',
      {
        'user_id': _requireUserId(),
        'onride_id': onrideId,
      },
    );
    return ConfirmRideResponse.fromJson(body);
  }

  Future<PassengerBroadcastContext> getPassengerBroadcastContext() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'api/passenger/subscriptions/broadcastcontext/${_requireUserId()}',
      options: _authorizedOptions(),
    );
    final body = response.data;
    if (body == null) {
      throw const RideException('Empty passenger broadcast settings response');
    }
    return PassengerBroadcastContext.fromJson(body);
  }

  Future<void> updatePassengerLocation({
    required double lat,
    required double lng,
    required String location,
  }) async {
    final body = await _post(
      'api/passenger/location',
      {
        'user_id': _requireUserId(),
        'lat': '$lat',
        'lng': '$lng',
        'location': location,
      },
    );
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw RideException(
        body['message']?.toString() ?? 'Unable to update passenger location',
      );
    }
  }

  Future<List<DriverDestinationBroadcastItem>> getNearbyDestinationBroadcasts({
    required double lat,
    required double lng,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'api/destinationbroadcasts/nearby/${_requireUserId()}',
      queryParameters: {
        'lat': '$lat',
        'lng': '$lng',
      },
      options: _authorizedOptions(),
    );
    final body = response.data ?? <String, dynamic>{};
    final items = body['result'] as List<dynamic>? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(DriverDestinationBroadcastItem.fromJson)
        .toList();
  }

  Future<void> requestDestinationBroadcastSeat({
    required String broadcastId,
    required String pickupLabel,
    required double pickupLat,
    required double pickupLng,
    int requestedSeats = 1,
  }) async {
    final body = await _post(
      'api/destinationbroadcasts/join',
      {
        'user_id': _requireUserId(),
        'broadcast_id': broadcastId,
        'pickup_label': pickupLabel,
        'pickup_lat': '$pickupLat',
        'pickup_lng': '$pickupLng',
        'requested_seats': '$requestedSeats',
      },
    );
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw RideException(
        body['message']?.toString() ?? 'Unable to request a seat',
      );
    }
  }

  Future<List<DriverDestinationJoinRequestItem>>
      getDestinationBroadcastRequests() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'api/destinationbroadcasts/requests/${_requireUserId()}',
      options: _authorizedOptions(),
    );
    final body = response.data ?? <String, dynamic>{};
    final items = body['result'] as List<dynamic>? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(DriverDestinationJoinRequestItem.fromJson)
        .toList();
  }

  Future<ConfirmRideResponse> acceptRideOffer({
    required String onrideId,
    required String offerId,
  }) async {
    await _post(
      'api/rideoffers/accept',
      {
        'user_id': _requireUserId(),
        'onride_id': onrideId,
        'offer_id': offerId,
      },
    );
    return confirmRide(onrideId);
  }

  Future<void> cancelRide(String onrideId) async {
    final body = await _post(
      'api/cancelride',
      {
        'user_id': _requireUserId(),
        'onride_id': onrideId,
      },
    );
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw RideException(
          body['message']?.toString() ?? 'Unable to cancel ride');
    }
  }

  Future<ConfirmRideResponse> pollUntilAccepted(
    String onrideId, {
    int maxAttempts = 12,
    Duration interval = const Duration(seconds: 5),
    bool Function()? isCancelled,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (isCancelled?.call() == true) {
        throw const RideException('Ride request cancelled');
      }
      final result = await confirmRide(onrideId);
      if (isCancelled?.call() == true) {
        throw const RideException('Ride request cancelled');
      }
      if (result.isAccepted) {
        return result;
      }
      if (result.hasDriverOffers) {
        return result;
      }
      if (!result.isSearching) {
        await _cancelUnacceptedRide(onrideId);
        throw RideException(result.message ?? 'Ride request failed');
      }
      await Future<void>.delayed(interval);
    }
    if (isCancelled?.call() == true) {
      throw const RideException('Ride request cancelled');
    }
    await _cancelUnacceptedRide(onrideId);
    throw const RideException('No driver accepted the ride yet');
  }

  Future<void> _cancelUnacceptedRide(String onrideId) async {
    try {
      await cancelRide(onrideId);
    } catch (_) {
      // Preserve the original matching failure. The backend expiry cleanup is
      // the fallback if cancellation cannot be delivered.
    }
  }

  Options _authorizedOptions() {
    final token = _sessionStorage.token;
    if (token == null || token.isEmpty) {
      throw const RideException('You are not signed in');
    }
    return Options(
      headers: {'Authorization': token},
      contentType: Headers.formUrlEncodedContentType,
    );
  }

  String _requireUserId() {
    final userId = _sessionStorage.userId;
    if (userId == null || userId.isEmpty) {
      throw const RideException('Missing user session');
    }
    return userId;
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: payload,
        options: _authorizedOptions(),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw RideException(message);
        }
      }
      throw RideException(error.message ?? 'Unable to complete ride request');
    }
  }
}

class RideException implements Exception {
  const RideException(this.message);

  final String message;

  @override
  String toString() => message;
}
