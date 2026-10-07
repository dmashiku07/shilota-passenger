import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/widget_shortcut_service.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/account_models.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    widgetShortcutService: ref.watch(widgetShortcutServiceProvider),
  );
});

class AccountRepository {
  AccountRepository({
    required Dio dio,
    required SessionStorage sessionStorage,
    required WidgetShortcutService widgetShortcutService,
  })  : _dio = dio,
        _sessionStorage = sessionStorage,
        _widgetShortcutService = widgetShortcutService;

  final Dio _dio;
  final SessionStorage _sessionStorage;
  final WidgetShortcutService _widgetShortcutService;

  Future<ProfileData> getProfile() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'api/profile/${_requireUserId()}',
      options: _authorizedOptions(),
    );

    final body = response.data;
    if (body == null) {
      throw const AccountException('Empty profile response');
    }

    return ProfileData.fromJson(body);
  }

  Future<void> updateProfile({
    required String fullName,
    required String countryCode,
    required String phoneNumber,
  }) async {
    final body = await _postJson(
      'api/updateprofile',
      {
        'user_id': _requireUserId(),
        'full_name': fullName,
        'country_code': countryCode,
        'phone_number': phoneNumber,
      },
    );
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to update profile',
      );
    }
    await _sessionStorage.updateProfile(
      fullName: fullName,
      countryCode: countryCode,
      phoneNumber: phoneNumber,
    );
  }

  Future<String> uploadProfileImage({
    required List<int> bytes,
    required String fileName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'api/uploadprofileimage',
      data: FormData.fromMap({
        'user_id': _requireUserId(),
        'userImage': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
      options: _authorizedOptions(contentType: 'multipart/form-data'),
    );
    final body = response.data ?? <String, dynamic>{};
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to upload profile image',
      );
    }
    final imageUrl = body['user_image']?.toString() ?? '';
    if (imageUrl.isEmpty) {
      throw const AccountException('Profile image URL is missing');
    }
    await _sessionStorage.updateProfile(
      fullName: _sessionStorage.fullName ?? '',
      userImage: imageUrl,
    );
    return imageUrl;
  }

  Future<AdminData> getAdminData() async {
    final body = await _getJson('api/admindatas', needsAuth: false);
    return AdminData.fromJson(body);
  }

  Future<ApiListResponse<NotificationItem>> getNotifications() async {
    final body = await _getJson('api/notifications/${_requireUserId()}');
    final items = (body['result'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<ApiListResponse<HelpPageData>> getHelpPages() async {
    final body = await _getJson('api/helppages', needsAuth: false);
    final items = (body['result'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(HelpPageData.fromJson)
        .toList();

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<ApiListResponse<WalletHistoryItem>> getWalletHistory() async {
    final body = await _getJson('api/wallethistory/${_requireUserId()}');
    final items = (body['payment_list'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(WalletHistoryItem.fromJson)
        .toList();

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<ApiListResponse<SavedPlace>> getSavedPlaces() async {
    final body = await _postJson(
      'api/savedplaces',
      {
        'user_id': _requireUserId(),
      },
    );

    final items = (body['saved_places'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SavedPlace.fromJson)
        .toList();
    await _widgetShortcutService.syncSavedPlaces(items);

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<void> removeSavedPlace(String googlePlaceId) async {
    final body = await _postJson(
      'api/saveplace',
      {
        'user_id': _requireUserId(),
        'google_place_id': googlePlaceId,
        'type': 'remove',
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
          body['message']?.toString() ?? 'Unable to remove favorite');
    }
    await getSavedPlaces();
  }

  Future<void> savePlace({
    required String placeName,
    required String placeFullAddress,
    required double latitude,
    required double longitude,
    required String placeType,
    String googlePlaceId = '',
  }) async {
    final body = await _postJson(
      'api/saveplace',
      {
        'user_id': _requireUserId(),
        'place_name': placeName,
        'place_full_address': placeFullAddress,
        'place_latitude': '$latitude',
        'place_longitude': '$longitude',
        'place_type': placeType,
        'google_place_id': googlePlaceId,
        'type': 'add',
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
          body['message']?.toString() ?? 'Unable to save favorite');
    }
    await getSavedPlaces();
  }

  Future<ApiListResponse<RideHistoryItem>> getRideHistory(String type) async {
    final body = await _postJson(
      'api/ridehistory',
      {
        'user_id': _requireUserId(),
        'type': type,
      },
    );

    final items = (body['result'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(RideHistoryItem.fromJson)
        .toList();

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<RideDetailData> getRideDetails({
    required String onRideId,
    required String type,
  }) async {
    final body = await _postJson(
      'api/ridedetails',
      {
        'user_id': _requireUserId(),
        'onride_id': onRideId,
        'type': type,
      },
    );
    return RideDetailData.fromJson(body);
  }

  Future<RideDetailData> getCompletedRideDetails({
    required String onRideId,
  }) async {
    final body = await _postJson(
      'api/completeridedetails',
      {
        'user_id': _requireUserId(),
        'onride_id': onRideId,
      },
    );
    return RideDetailData.fromJson(body);
  }

  Future<void> submitReview({
    required String onRideId,
    required double rating,
    required String reviewMessage,
  }) async {
    final body = await _postJson(
      'api/review',
      {
        'user_id': _requireUserId(),
        'onride_id': onRideId,
        'review_message': reviewMessage,
        'rating': rating.toString(),
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
          body['message']?.toString() ?? 'Unable to save review');
    }
  }

  Future<String?> reportLostItem({
    required String rideId,
    required String description,
    required String contactPhone,
  }) async {
    final body = await _postJson(
      'api/lostitem/report',
      {
        'ride_id': rideId,
        'item_description': description,
        'contact_phone': contactPhone,
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
          body['message']?.toString() ?? 'Unable to report lost item');
    }
    return body['lost_item_id']?.toString();
  }

  Future<ApiListResponse<LostItemMessage>> getLostItemMessages(
    String lostItemId,
  ) async {
    final body = await _getJson('api/lostitem/messages/$lostItemId');
    final items = (body['result'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(LostItemMessage.fromJson)
        .toList();

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<void> sendLostItemMessage({
    required String lostItemId,
    required String message,
  }) async {
    final body = await _postJson(
      'api/lostitem/message',
      {
        'lost_item_id': lostItemId,
        'message': message,
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to send lost item message',
      );
    }
  }

  Future<String?> getLostItemCaseIdForRide(String rideId) async {
    final body = await _getJson('api/lostitem/ride/$rideId');
    if ((body['status']?.toString() ?? 'false') != 'true') {
      return null;
    }
    return body['lost_item_id']?.toString();
  }

  Future<LostItemCaseSummary> getLostItemCase(String lostItemId) async {
    final body = await _getJson('api/lostitem/$lostItemId');
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to load lost item case',
      );
    }
    return LostItemCaseSummary.fromJson(body);
  }

  Future<RiderBlockStatus> getRiderBlockStatus() async {
    final body = await _getJson('api/riderblockstatus/${_requireUserId()}');
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to load account review status',
      );
    }
    return RiderBlockStatus.fromJson(body);
  }

  Future<ApiListResponse<PassengerPlan>> getPassengerSubscriptionPlans() async {
    final body = await _getJson(
      'api/passenger/subscriptionplans/${_requireUserId()}',
    );
    final items = (body['result'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PassengerPlan.fromJson)
        .toList();

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<PassengerSubscriptionOverview>
      getPassengerSubscriptionOverview() async {
    final body = await _getJson(
      'api/passenger/subscriptions/current/${_requireUserId()}',
    );
    return PassengerSubscriptionOverview.fromJson(body);
  }

  Future<ApiListResponse<PassengerSubscriptionData>>
      getPassengerSubscriptionHistory() async {
    final body = await _getJson(
      'api/passenger/subscriptions/history/${_requireUserId()}',
    );
    final items = (body['result'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PassengerSubscriptionData.fromJson)
        .toList();

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<PassengerSubscriptionPayment> initiatePassengerSubscriptionPurchase(
    String planId,
  ) async {
    final body = await _postJson(
      'api/passenger/subscriptions/initiate',
      {
        'user_id': _requireUserId(),
        'plan_id': planId,
      },
    );
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ??
            'Unable to initiate passenger subscription payment',
      );
    }
    return PassengerSubscriptionPayment.fromJson(body);
  }

  Future<PassengerSubscriptionData?> verifyPassengerSubscriptionPayment(
    String transId,
  ) async {
    final body = await _getJson(
      'api/passenger/subscriptions/verifyselcom/$transId',
    );
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Payment is still pending',
      );
    }
    final result = body['result'];
    if (result is Map<String, dynamic>) {
      return PassengerSubscriptionData.fromJson(result);
    }
    return null;
  }

  Future<void> escalateLostItemCase({
    required String lostItemId,
    required String reason,
  }) async {
    final body = await _postJson(
      'api/lostitem/$lostItemId/escalate',
      {
        'reason': reason,
      },
    );
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to escalate lost item case',
      );
    }
  }

  Future<void> confirmLostItemReturned(String lostItemId) async {
    final body = await _postJson(
      'api/lostitem/$lostItemId/confirmreturn',
      const <String, dynamic>{},
    );
    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to confirm returned item',
      );
    }
  }

  Future<void> cancelRideById(String onRideId) async {
    final body = await _postJson(
      'api/cancelride',
      {
        'user_id': _requireUserId(),
        'onride_id': onRideId,
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
          body['message']?.toString() ?? 'Unable to cancel ride');
    }
  }

  Future<void> contactUs({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    final body = await _postJson(
      'api/contactus',
      {
        'user_id': _requireUserId(),
        'name': name,
        'email': email,
        'subject': subject,
        'message': message,
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
          body['message']?.toString() ?? 'Unable to send message');
    }
  }

  Future<void> updateEmergencyContacts(
    List<EmergencyContact> contacts,
  ) async {
    final body = await _postJson(
      'api/updateprofile',
      {
        'user_id': _requireUserId(),
        'emergency_contact': jsonEncode(
          contacts.map((item) => item.toJson()).toList(),
        ),
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to update emergency contacts',
      );
    }
  }

  Future<void> sendSosAlert(SosAlertPayload payload) async {
    final body = await _postJson(
      'api/sosalert',
      {
        'user_id': _requireUserId(),
        'lat': payload.latitude.toString(),
        'lng': payload.longitude.toString(),
        'ride_id': payload.rideId,
        'message': payload.message,
        'action_type': payload.actionType,
        'contact_target': payload.contactTarget,
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to send Emergency Alert',
      );
    }
  }

  Future<CallSessionData> makeMaskedCall({
    required String receiverId,
    required String roomId,
    String? onRideId,
  }) async {
    final body = await _postJson(
      'api/makecall',
      {
        'sender_id': _requireUserId(),
        'receiver_id': receiverId,
        'type': 'audio',
        'user_type': 'user',
        'room_id': roomId,
        'platform': 'flutter',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        if (onRideId != null && onRideId.isNotEmpty) 'onride_id': onRideId,
      },
    );

    return CallSessionData.fromJson({
      ...body,
      'room_id': roomId,
      'receiver_id': receiverId,
    });
  }

  Future<List<Map<String, dynamic>>> getCallIceServers() async {
    final body = await _getJson(
      'api/call/ice-servers/${_requireUserId()}',
    );
    return (body['ice_servers'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> endMaskedCall({
    required String roomId,
    required String receiverId,
  }) async {
    final body = await _postJson(
      'api/endcall',
      {
        'sender_id': _requireUserId(),
        'receiver_id': receiverId,
        'type': 'audio',
        'user_type': 'user',
        'room_id': roomId,
        'platform': 'flutter',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to end call',
      );
    }
  }

  Future<ApiListResponse<RideChatMessage>> getRideChatMessages(
    String onRideId,
  ) async {
    final body = await _getJson('api/ridechat/$onRideId/messages');
    final items = (body['result'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(RideChatMessage.fromJson)
        .toList();

    return ApiListResponse(
      status: body['status']?.toString() ?? 'false',
      message: body['message']?.toString(),
      items: items,
    );
  }

  Future<RideChatMessage> sendRideChatMessage({
    required String onRideId,
    required String message,
  }) async {
    final body = await _postJson(
      'api/ridechat/$onRideId/message',
      {
        'message': message,
      },
    );

    if ((body['status']?.toString() ?? 'false') != 'true') {
      throw AccountException(
        body['message']?.toString() ?? 'Unable to send ride chat message',
      );
    }

    final result = body['result'];
    if (result is Map<String, dynamic>) {
      return RideChatMessage.fromJson(result);
    }
    throw const AccountException('Empty ride chat response');
  }

  Options _authorizedOptions({String? contentType}) {
    final token = _sessionStorage.token;
    if (token == null || token.isEmpty) {
      throw const AccountException('You are not signed in');
    }

    return Options(
      headers: {'Authorization': token},
      contentType: contentType,
    );
  }

  String _requireUserId() {
    final userId = _sessionStorage.userId;
    if (userId == null || userId.isEmpty) {
      throw const AccountException('Missing user session');
    }
    return userId;
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    bool needsAuth = true,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        options: needsAuth ? _authorizedOptions() : null,
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw AccountException(_resolveMessage(error));
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: payload,
        options: _authorizedOptions(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw AccountException(_resolveMessage(error));
    }
  }

  String _resolveMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return error.message ?? 'Unable to complete request';
  }
}

class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}
