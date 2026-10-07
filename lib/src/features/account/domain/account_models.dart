class ApiListResponse<T> {
  const ApiListResponse({
    required this.status,
    required this.message,
    required this.items,
  });

  final String status;
  final String? message;
  final List<T> items;

  bool get isSuccess => status.toLowerCase() == 'true';
}

class ProfileData {
  const ProfileData({
    required this.status,
    required this.message,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.userImage,
    required this.countryCode,
    required this.phoneNumber,
    required this.walletMoney,
    required this.emergencyContacts,
  });

  final String status;
  final String? message;
  final String? userId;
  final String? fullName;
  final String? email;
  final String? userImage;
  final String? countryCode;
  final String? phoneNumber;
  final String? walletMoney;
  final List<EmergencyContact> emergencyContacts;

  bool get isSuccess => status.toLowerCase() == 'true';

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final contacts =
        (json['emergency_contact'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(EmergencyContact.fromJson)
            .toList();

    return ProfileData(
      status: json['status']?.toString() ?? 'false',
      message: json['message']?.toString(),
      userId: json['user_id']?.toString(),
      fullName: json['full_name']?.toString(),
      email: json['email']?.toString(),
      userImage: json['user_image']?.toString(),
      countryCode: json['country_code']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      walletMoney: json['walletmoney']?.toString(),
      emergencyContacts: contacts,
    );
  }
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  final String? id;
  final String? name;
  final String? phoneNumber;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      phoneNumber: json['phone_no']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name ?? '',
      'phone_no': phoneNumber ?? '',
    };
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

class AdminData {
  const AdminData({
    required this.status,
    required this.currencySymbol,
    required this.emergencyContact,
  });

  final String status;
  final String? currencySymbol;
  final String? emergencyContact;

  bool get isSuccess => status.toLowerCase() == 'true';

  factory AdminData.fromJson(Map<String, dynamic> json) {
    return AdminData(
      status: json['status']?.toString() ?? 'false',
      currencySymbol: json['currencysymbol']?.toString(),
      emergencyContact: json['emergencycontact']?.toString(),
    );
  }
}

class SosAlertPayload {
  const SosAlertPayload({
    required this.actionType,
    required this.message,
    required this.latitude,
    required this.longitude,
    required this.rideId,
    required this.contactTarget,
  });

  final String actionType;
  final String message;
  final double latitude;
  final double longitude;
  final String rideId;
  final String contactTarget;
}

class CallSessionData {
  const CallSessionData({
    required this.status,
    required this.message,
    required this.roomId,
    this.receiverId,
  });

  final String status;
  final String? message;
  final String roomId;
  final String? receiverId;

  bool get isSuccess => status.toLowerCase() == 'true';

  factory CallSessionData.fromJson(Map<String, dynamic> json) {
    return CallSessionData(
      status: json['status']?.toString() ?? 'false',
      message: json['message']?.toString(),
      roomId: json['room_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString(),
    );
  }
}

class ActiveCallArgs {
  const ActiveCallArgs({
    required this.roomId,
    required this.partnerId,
    required this.partnerName,
    required this.isCaller,
    required this.onRideId,
    this.partnerImageUrl,
  });

  final String roomId;
  final String partnerId;
  final String partnerName;
  final bool isCaller;
  final String onRideId;
  final String? partnerImageUrl;
}

class IncomingCallEvent {
  const IncomingCallEvent({
    required this.roomId,
    required this.partnerId,
    required this.partnerName,
    required this.onRideId,
    this.partnerImageUrl,
  });

  final String roomId;
  final String partnerId;
  final String partnerName;
  final String onRideId;
  final String? partnerImageUrl;

  factory IncomingCallEvent.fromJson(Map<String, dynamic> json) {
    String? cleanImageUrl(dynamic value) {
      final imageUrl = value?.toString().trim() ?? '';
      if (imageUrl.isEmpty ||
          imageUrl.toLowerCase() == 'undefined' ||
          imageUrl.toLowerCase() == 'null') {
        return null;
      }
      return imageUrl;
    }

    return IncomingCallEvent(
      roomId: json['room_id']?.toString() ?? '',
      partnerId: json['sender_id']?.toString() ?? '',
      partnerName: json['user_name']?.toString() ??
          json['driver_name']?.toString() ??
          'Shilota Driver',
      onRideId: json['ride_id']?.toString() ?? '',
      partnerImageUrl: cleanImageUrl(
        json['user_image'] ?? json['driver_image'],
      ),
    );
  }
}

class RideChatArgs {
  const RideChatArgs({
    required this.onRideId,
    required this.driverId,
    required this.driverName,
  });

  final String onRideId;
  final String driverId;
  final String driverName;
}

class RideChatMessage {
  const RideChatMessage({
    required this.id,
    required this.onRideId,
    required this.senderType,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String onRideId;
  final String senderType;
  final String senderId;
  final String message;
  final String createdAt;

  bool get isOutgoing => senderType == 'user';

  factory RideChatMessage.fromJson(Map<String, dynamic> json) {
    return RideChatMessage(
      id: json['_id']?.toString() ?? '',
      onRideId: json['onride_id']?.toString() ?? '',
      senderType: json['sender_type']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.title,
    required this.message,
    required this.notifiedAt,
  });

  final String title;
  final String message;
  final String notifiedAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      notifiedAt: json['notified_at']?.toString() ?? '',
    );
  }
}

class HelpPageData {
  const HelpPageData({
    required this.id,
    required this.pageType,
    required this.title,
    required this.content,
    required this.status,
  });

  final String id;
  final String pageType;
  final String title;
  final String content;
  final String status;

  factory HelpPageData.fromJson(Map<String, dynamic> json) {
    return HelpPageData(
      id: json['id']?.toString() ?? '',
      pageType: json['pagetype']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class WalletHistoryItem {
  const WalletHistoryItem({
    required this.id,
    required this.transaction,
    required this.type,
    required this.amount,
    required this.date,
  });

  final String id;
  final String transaction;
  final String type;
  final String amount;
  final String date;

  factory WalletHistoryItem.fromJson(Map<String, dynamic> json) {
    return WalletHistoryItem(
      id: json['_id']?.toString() ?? '',
      transaction: json['transaction']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      date: json['updated_at']?.toString() ?? '',
    );
  }
}

class SavedPlace {
  const SavedPlace({
    required this.placeId,
    required this.placeName,
    required this.placeFullAddress,
    required this.latitude,
    required this.longitude,
    required this.placeType,
  });

  final String placeId;
  final String placeName;
  final String placeFullAddress;
  final double latitude;
  final double longitude;
  final String placeType;

  bool get isHome => placeType.toLowerCase() == 'home';
  bool get isWork => placeType.toLowerCase() == 'work';
  String get displayTitle => placeType.isEmpty ? 'Saved place' : placeType;
  String get displayAddress =>
      placeFullAddress.isEmpty ? placeName : placeFullAddress;

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      placeId: json['google_place_id']?.toString() ?? '',
      placeName: json['place_name']?.toString() ?? '',
      placeFullAddress: json['place_full_address']?.toString() ?? '',
      latitude: double.tryParse(json['place_latitude']?.toString() ?? '') ?? 0,
      longitude:
          double.tryParse(json['place_longitude']?.toString() ?? '') ?? 0,
      placeType: json['place_type']?.toString() ?? '',
    );
  }
}

class RideHistoryItem {
  const RideHistoryItem({
    required this.onRideId,
    required this.pickupTime,
    required this.categoryImage,
    required this.categoryName,
    required this.vehicleNo,
    required this.totalPrice,
    required this.rideStatus,
  });

  final String onRideId;
  final String pickupTime;
  final String categoryImage;
  final String categoryName;
  final String vehicleNo;
  final String totalPrice;
  final String rideStatus;

  factory RideHistoryItem.fromJson(Map<String, dynamic> json) {
    return RideHistoryItem(
      onRideId: json['onride_id']?.toString() ?? '',
      pickupTime: json['pickup_time']?.toString() ?? '',
      categoryImage: json['category_image']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      vehicleNo: json['vehicle_no']?.toString() ?? '',
      totalPrice: json['total_price']?.toString() ?? '',
      rideStatus: json['ride_status']?.toString() ?? '',
    );
  }
}

class RideDetailArgs {
  const RideDetailArgs({
    required this.onRideId,
    required this.from,
    this.pickupTime,
    this.vehicleNo,
  });

  final String onRideId;
  final String from;
  final String? pickupTime;
  final String? vehicleNo;
}

class RideDetailData {
  const RideDetailData({
    required this.status,
    required this.message,
    required this.values,
  });

  final String status;
  final String? message;
  final Map<String, String> values;

  bool get isSuccess => status.toLowerCase() == 'true';

  factory RideDetailData.fromJson(Map<String, dynamic> json) {
    final mapped = <String, String>{};
    json.forEach((key, value) {
      mapped[key] = value?.toString() ?? '';
    });
    return RideDetailData(
      status: mapped['status'] ?? 'false',
      message: mapped['message'],
      values: mapped,
    );
  }
}

class ReviewArgs {
  const ReviewArgs({
    required this.onRideId,
    required this.from,
    this.rating,
    this.reviewMessage,
  });

  final String onRideId;
  final String from;
  final String? rating;
  final String? reviewMessage;
}

class EmergencyContactsArgs {
  const EmergencyContactsArgs({
    required this.contacts,
  });

  final List<EmergencyContact> contacts;
}

class RideBookingDraft {
  const RideBookingDraft({
    this.onRideId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.scheduleAt,
  });

  final String? onRideId;
  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String? scheduleAt;
}

class SupportConversationArgs {
  const SupportConversationArgs({
    required this.title,
    required this.subject,
    required this.recipientLabel,
    this.lostItemId,
    this.prefillMessage,
  });

  final String title;
  final String subject;
  final String recipientLabel;
  final String? lostItemId;
  final String? prefillMessage;
}

class LostItemMessage {
  const LostItemMessage({
    required this.id,
    required this.senderType,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String senderType;
  final String senderId;
  final String message;
  final String createdAt;

  bool get isOutgoing => senderType == 'user';

  factory LostItemMessage.fromJson(Map<String, dynamic> json) {
    return LostItemMessage(
      id: json['_id']?.toString() ?? '',
      senderType: json['sender_type']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class LostItemCaseSummary {
  const LostItemCaseSummary({
    required this.lostItemId,
    required this.caseStatus,
    required this.escalationStatus,
    required this.returnIncentiveStatus,
    required this.riderConfirmedReturned,
    this.responseDueAt,
    this.lastMessageAt,
  });

  final String lostItemId;
  final String caseStatus;
  final String escalationStatus;
  final String returnIncentiveStatus;
  final bool riderConfirmedReturned;
  final String? responseDueAt;
  final String? lastMessageAt;

  bool get isEscalated => escalationStatus.toLowerCase() == 'escalated';
  bool get canConfirmReturned =>
      !riderConfirmedReturned && caseStatus.toLowerCase() != 'resolved';

  factory LostItemCaseSummary.fromJson(Map<String, dynamic> json) {
    return LostItemCaseSummary(
      lostItemId: json['lost_item_id']?.toString() ?? '',
      caseStatus: json['case_status']?.toString() ?? 'open',
      escalationStatus: json['escalation_status']?.toString() ?? 'normal',
      returnIncentiveStatus:
          json['return_incentive_status']?.toString() ?? 'eligible',
      riderConfirmedReturned: json['rider_confirmed_returned'] == true ||
          json['rider_confirmed_returned']?.toString() == 'true',
      responseDueAt: json['response_due_at']?.toString(),
      lastMessageAt: json['last_message_at']?.toString(),
    );
  }
}

class RiderBlockStatus {
  const RiderBlockStatus({
    required this.activeBlockCount,
    required this.pendingReview,
    this.reviewStatus,
    this.reason,
  });

  final int activeBlockCount;
  final bool pendingReview;
  final String? reviewStatus;
  final String? reason;

  bool get hasAccountNotice => pendingReview || activeBlockCount > 0;

  factory RiderBlockStatus.fromJson(Map<String, dynamic> json) {
    final latest = json['latest_block'];
    final latestBlock =
        latest is Map<String, dynamic> ? latest : <String, dynamic>{};
    return RiderBlockStatus(
      activeBlockCount:
          int.tryParse(json['active_block_count']?.toString() ?? '') ?? 0,
      pendingReview: json['pending_review'] == true ||
          json['pending_review']?.toString() == 'true',
      reviewStatus: latestBlock['admin_review_status']?.toString(),
      reason: latestBlock['reason']?.toString(),
    );
  }
}

class PassengerPlanFeature {
  const PassengerPlanFeature({
    required this.featureCode,
    required this.featureValue,
  });

  final String featureCode;
  final Object? featureValue;

  factory PassengerPlanFeature.fromJson(Map<String, dynamic> json) {
    return PassengerPlanFeature(
      featureCode: json['feature_code']?.toString() ?? '',
      featureValue: json['feature_value'],
    );
  }

  String get label {
    switch (featureCode) {
      case 'CAN_SET_RIDE_PRICE':
        return 'Set your own ride price';
      case 'CAN_BROADCAST_RIDE_REQUEST':
        return 'Broadcast ride requests';
      case 'PRIORITY_MATCHING':
        return 'Priority driver matching';
      case 'MAX_PRICE_BROADCASTS_PER_DAY':
        return 'Daily price broadcasts: ${featureValue ?? 0}';
      case 'PASSENGER_BROADCAST_RADIUS_KM':
        return 'Broadcast radius: ${featureValue ?? 0} km';
      default:
        return featureCode.replaceAll('_', ' ');
    }
  }
}

class PassengerPlan {
  const PassengerPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationUnit,
    required this.durationValue,
    required this.validityLabel,
    required this.features,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String durationUnit;
  final int durationValue;
  final String validityLabel;
  final List<PassengerPlanFeature> features;

  factory PassengerPlan.fromJson(Map<String, dynamic> json) {
    return PassengerPlan(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'TZS',
      durationUnit: json['duration_unit']?.toString() ?? '',
      durationValue:
          int.tryParse(json['duration_value']?.toString() ?? '') ?? 0,
      validityLabel: json['validity_label']?.toString() ?? '',
      features: (json['features'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PassengerPlanFeature.fromJson)
          .toList(),
    );
  }
}

class PassengerSubscriptionData {
  const PassengerSubscriptionData({
    required this.id,
    required this.status,
    required this.paymentStatus,
    required this.planName,
    required this.price,
    required this.currency,
    required this.validityLabel,
    required this.startsAt,
    required this.expiresAt,
    required this.features,
  });

  final String id;
  final String status;
  final String paymentStatus;
  final String planName;
  final double price;
  final String currency;
  final String validityLabel;
  final String? startsAt;
  final String? expiresAt;
  final List<PassengerPlanFeature> features;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isPending => status.toLowerCase() == 'pending_payment';

  factory PassengerSubscriptionData.fromJson(Map<String, dynamic> json) {
    return PassengerSubscriptionData(
      id: json['_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      planName: json['plan_name_snapshot']?.toString() ?? '',
      price: double.tryParse(json['price_snapshot']?.toString() ?? '') ?? 0,
      currency: json['currency_snapshot']?.toString() ?? 'TZS',
      validityLabel: json['validity_label']?.toString() ?? '',
      startsAt: json['starts_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      features:
          (json['plan_features_snapshot'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(PassengerPlanFeature.fromJson)
              .toList(),
    );
  }
}

class PassengerSubscriptionOverview {
  const PassengerSubscriptionOverview({
    required this.currentSubscription,
    required this.pendingSubscription,
  });

  final PassengerSubscriptionData? currentSubscription;
  final PassengerSubscriptionData? pendingSubscription;

  factory PassengerSubscriptionOverview.fromJson(Map<String, dynamic> json) {
    final current = json['current_subscription'];
    final pending = json['pending_subscription'];
    return PassengerSubscriptionOverview(
      currentSubscription: current is Map<String, dynamic>
          ? PassengerSubscriptionData.fromJson(current)
          : null,
      pendingSubscription: pending is Map<String, dynamic>
          ? PassengerSubscriptionData.fromJson(pending)
          : null,
    );
  }
}

class PassengerSubscriptionPayment {
  const PassengerSubscriptionPayment({
    required this.paymentUrl,
    required this.returnUrl,
    required this.transId,
    required this.subscriptionId,
    required this.subscription,
  });

  final String paymentUrl;
  final String returnUrl;
  final String transId;
  final String subscriptionId;
  final PassengerSubscriptionData? subscription;

  factory PassengerSubscriptionPayment.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    return PassengerSubscriptionPayment(
      paymentUrl: json['payment_url']?.toString() ?? '',
      returnUrl: json['return_url']?.toString() ?? '',
      transId: json['transid']?.toString() ?? '',
      subscriptionId: json['subscription_id']?.toString() ?? '',
      subscription: result is Map<String, dynamic>
          ? PassengerSubscriptionData.fromJson(result)
          : null,
    );
  }
}
