class RideStop {
  const RideStop({
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.sequence,
    this.fareIncrement = '0',
  });

  final String location;
  final double latitude;
  final double longitude;
  final int sequence;
  final String fareIncrement;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'location': location,
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      'sequence': sequence.toString(),
      'fare_increment': fareIncrement,
    };
  }

  factory RideStop.fromJson(Map<String, dynamic> json) {
    return RideStop(
      location: json['location']?.toString() ?? '',
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['lng']?.toString() ?? '') ?? 0,
      sequence: int.tryParse(json['sequence']?.toString() ?? '') ?? 0,
      fareIncrement: json['fare_increment']?.toString() ?? '0',
    );
  }

  RideStop copyWith({
    String? location,
    double? latitude,
    double? longitude,
    int? sequence,
    String? fareIncrement,
  }) {
    return RideStop(
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sequence: sequence ?? this.sequence,
      fareIncrement: fareIncrement ?? this.fareIncrement,
    );
  }
}

class DeliveryDetails {
  const DeliveryDetails({
    required this.parcelType,
    required this.parcelSize,
    required this.recipientName,
    required this.recipientPhone,
    required this.senderNote,
    required this.handoffCode,
    required this.proofRequired,
  });

  final String parcelType;
  final String parcelSize;
  final String recipientName;
  final String recipientPhone;
  final String senderNote;
  final String handoffCode;
  final bool proofRequired;

  bool get isEmpty =>
      parcelType.trim().isEmpty &&
      parcelSize.trim().isEmpty &&
      recipientName.trim().isEmpty &&
      recipientPhone.trim().isEmpty &&
      senderNote.trim().isEmpty &&
      handoffCode.trim().isEmpty &&
      !proofRequired;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'parcel_type': parcelType,
      'parcel_size': parcelSize,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'sender_note': senderNote,
      'handoff_code': handoffCode,
      'proof_required': proofRequired,
    };
  }

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) {
    return DeliveryDetails(
      parcelType: json['parcel_type']?.toString() ?? '',
      parcelSize: json['parcel_size']?.toString() ?? '',
      recipientName: json['recipient_name']?.toString() ?? '',
      recipientPhone: json['recipient_phone']?.toString() ?? '',
      senderNote: json['sender_note']?.toString() ?? '',
      handoffCode: json['handoff_code']?.toString() ?? '',
      proofRequired: json['proof_required'] == true ||
          json['proof_required']?.toString() == 'true',
    );
  }

  DeliveryDetails copyWith({
    String? parcelType,
    String? parcelSize,
    String? recipientName,
    String? recipientPhone,
    String? senderNote,
    String? handoffCode,
    bool? proofRequired,
  }) {
    return DeliveryDetails(
      parcelType: parcelType ?? this.parcelType,
      parcelSize: parcelSize ?? this.parcelSize,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      senderNote: senderNote ?? this.senderNote,
      handoffCode: handoffCode ?? this.handoffCode,
      proofRequired: proofRequired ?? this.proofRequired,
    );
  }
}

class RideQuoteResponse {
  const RideQuoteResponse({
    required this.status,
    required this.message,
    required this.rides,
  });

  final String status;
  final String? message;
  final List<AvailableRideItem> rides;

  bool get isSuccess => status.toLowerCase() == 'true';

  factory RideQuoteResponse.fromJson(Map<String, dynamic> json) {
    return RideQuoteResponse(
      status: json['status']?.toString() ?? 'false',
      message: json['message']?.toString(),
      rides: (json['available_ride'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AvailableRideItem.fromJson)
          .toList(),
    );
  }
}

class AvailableRideItem {
  const AvailableRideItem({
    required this.id,
    required this.categoryName,
    required this.categoryImage,
    required this.basePrice,
    required this.reachPickup,
    required this.serviceType,
    required this.available,
  });

  final String id;
  final String categoryName;
  final String categoryImage;
  final String basePrice;
  final String reachPickup;
  final String serviceType;
  final int available;

  factory AvailableRideItem.fromJson(Map<String, dynamic> json) {
    return AvailableRideItem(
      id: json['_id']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      categoryImage: json['image']?.toString() ?? '',
      basePrice: json['baseprice']?.toString() ?? '0',
      reachPickup: json['reach_pickup']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      available: int.tryParse(json['available']?.toString() ?? '') ?? 0,
    );
  }
}

class PoolingSettings {
  const PoolingSettings({
    required this.enabled,
    required this.discountPercent,
    required this.maxPassengers,
    required this.maxDetourKm,
    required this.maxPickupGapKm,
    required this.maxDropGapKm,
    required this.zoneKey,
  });

  final bool enabled;
  final int discountPercent;
  final int maxPassengers;
  final int maxDetourKm;
  final int maxPickupGapKm;
  final int maxDropGapKm;
  final String zoneKey;

  factory PoolingSettings.fromJson(Map<String, dynamic> json) {
    return PoolingSettings(
      enabled: json['enabled'] == true || json['enabled']?.toString() == 'true',
      discountPercent:
          int.tryParse(json['discount_percent']?.toString() ?? '') ?? 0,
      maxPassengers:
          int.tryParse(json['max_passengers']?.toString() ?? '') ?? 3,
      maxDetourKm: int.tryParse(json['max_detour_km']?.toString() ?? '') ?? 3,
      maxPickupGapKm:
          int.tryParse(json['max_pickup_gap_km']?.toString() ?? '') ?? 2,
      maxDropGapKm:
          int.tryParse(json['max_drop_gap_km']?.toString() ?? '') ?? 3,
      zoneKey: json['zone_key']?.toString() ?? '',
    );
  }
}

class RequestRideResponse {
  const RequestRideResponse({
    required this.status,
    required this.message,
    required this.onrideId,
    required this.onrideType,
    this.requestType,
    this.pricingMode,
    this.offerExpiresAt,
    this.broadcastExpiresAt,
    this.passengerOfferedPrice,
    this.broadcastRadius,
    this.seatsRequested,
    this.poolStatus,
    this.poolGroupSize = 1,
    this.poolDiscountPercent = 0,
    this.deliveryDetails,
  });

  final String status;
  final String? message;
  final String? onrideId;
  final String? onrideType;
  final String? requestType;
  final String? pricingMode;
  final DateTime? offerExpiresAt;
  final DateTime? broadcastExpiresAt;
  final double? passengerOfferedPrice;
  final double? broadcastRadius;
  final String? seatsRequested;
  final String? poolStatus;
  final int poolGroupSize;
  final int poolDiscountPercent;
  final DeliveryDetails? deliveryDetails;

  bool get isSuccess => status.toLowerCase() == 'true';

  factory RequestRideResponse.fromJson(Map<String, dynamic> json) {
    return RequestRideResponse(
      status: json['status']?.toString() ?? 'false',
      message: json['message']?.toString(),
      onrideId: json['onride_id']?.toString(),
      onrideType: json['onride_type']?.toString(),
      requestType: json['request_type']?.toString(),
      pricingMode: json['pricing_mode']?.toString(),
      offerExpiresAt:
          DateTime.tryParse(json['offer_expires_at']?.toString() ?? ''),
      broadcastExpiresAt:
          DateTime.tryParse(json['broadcast_expires_at']?.toString() ?? ''),
      passengerOfferedPrice:
          double.tryParse(json['passenger_offered_price']?.toString() ?? ''),
      broadcastRadius:
          double.tryParse(json['broadcast_radius']?.toString() ?? ''),
      seatsRequested: json['seats_requested']?.toString(),
      poolStatus: json['pool_status']?.toString(),
      poolGroupSize:
          int.tryParse(json['pool_group_size']?.toString() ?? '') ?? 1,
      poolDiscountPercent:
          int.tryParse(json['pool_discount_percent']?.toString() ?? '') ?? 0,
      deliveryDetails: json['delivery_details'] is Map<String, dynamic>
          ? DeliveryDetails.fromJson(
              json['delivery_details'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class DriverRideOffer {
  const DriverRideOffer({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverRating,
    required this.vehicleName,
    required this.vehicleNumber,
    required this.offeredPrice,
    required this.currency,
    required this.offerType,
    this.estimatedArrivalMinutes,
    this.message,
    this.status,
    this.expiresAt,
  });

  final String id;
  final String driverId;
  final String driverName;
  final String driverRating;
  final String vehicleName;
  final String vehicleNumber;
  final double offeredPrice;
  final String currency;
  final String offerType;
  final int? estimatedArrivalMinutes;
  final String? message;
  final String? status;
  final DateTime? expiresAt;

  factory DriverRideOffer.fromJson(Map<String, dynamic> json) {
    return DriverRideOffer(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? 'Driver',
      driverRating: json['driver_rating']?.toString() ?? '0',
      vehicleName: json['vehicle_name']?.toString() ?? '',
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      offeredPrice:
          double.tryParse(json['offered_price']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'TZS',
      offerType: json['offer_type']?.toString() ?? 'DRIVER_DIRECT_OFFER',
      estimatedArrivalMinutes:
          int.tryParse(json['estimated_arrival_minutes']?.toString() ?? ''),
      message: json['message']?.toString(),
      status: json['status']?.toString(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }
}

class ConfirmRideResponse {
  const ConfirmRideResponse({
    required this.status,
    required this.message,
    this.requestType,
    this.pricingMode,
    this.offerExpiresAt,
    this.broadcastExpiresAt,
    this.passengerOfferedPrice,
    this.offers = const <DriverRideOffer>[],
    this.finalAgreedPrice,
    this.finalAgreedCurrency,
    this.pickupLocation,
    this.pickupLat,
    this.pickupLng,
    this.dropLocation,
    this.dropLat,
    this.dropLng,
    this.onrideOtp,
    this.driverName,
    this.driverId,
    this.driverUserId,
    this.driverRating,
    this.driverMobile,
    this.driverVehicle,
    this.driverVehicleNo,
    this.basePrice,
    this.driverImage,
    this.rideStops = const <RideStop>[],
    this.poolingOptIn = false,
    this.seatsRequested = 1,
    this.poolStatus,
    this.poolGroupSize = 1,
    this.poolDiscountPercent = 0,
    this.deliveryDetails,
  });

  final String status;
  final String? message;
  final String? requestType;
  final String? pricingMode;
  final DateTime? offerExpiresAt;
  final DateTime? broadcastExpiresAt;
  final double? passengerOfferedPrice;
  final List<DriverRideOffer> offers;
  final String? finalAgreedPrice;
  final String? finalAgreedCurrency;
  final String? pickupLocation;
  final String? pickupLat;
  final String? pickupLng;
  final String? dropLocation;
  final String? dropLat;
  final String? dropLng;
  final String? onrideOtp;
  final String? driverName;
  final String? driverId;
  final String? driverUserId;
  final String? driverRating;
  final String? driverMobile;
  final String? driverVehicle;
  final String? driverVehicleNo;
  final String? basePrice;
  final String? driverImage;
  final List<RideStop> rideStops;
  final bool poolingOptIn;
  final int seatsRequested;
  final String? poolStatus;
  final int poolGroupSize;
  final int poolDiscountPercent;
  final DeliveryDetails? deliveryDetails;

  bool get isAccepted => status.toLowerCase() == 'true';
  bool get isSearching =>
      (status.toLowerCase() == 'false' && message == 'Searching') ||
      status.toLowerCase() == 'searching_offers';
  bool get hasDriverOffers => offers.isNotEmpty;
  bool get isPassengerPriceBroadcast =>
      (requestType ?? '').toUpperCase() == 'PASSENGER_PRICE_BROADCAST';

  factory ConfirmRideResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmRideResponse(
      status: json['status']?.toString() ?? 'false',
      message: json['message']?.toString(),
      requestType: json['request_type']?.toString(),
      pricingMode: json['pricing_mode']?.toString(),
      offerExpiresAt:
          DateTime.tryParse(json['offer_expires_at']?.toString() ?? ''),
      broadcastExpiresAt:
          DateTime.tryParse(json['broadcast_expires_at']?.toString() ?? ''),
      passengerOfferedPrice:
          double.tryParse(json['passenger_offered_price']?.toString() ?? ''),
      offers: ((json['offers'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DriverRideOffer.fromJson)
          .toList()
        ..sort((left, right) {
          final priceOrder = left.offeredPrice.compareTo(right.offeredPrice);
          if (priceOrder != 0) {
            return priceOrder;
          }
          return left.id.compareTo(right.id);
        })),
      finalAgreedPrice: json['final_agreed_price']?.toString(),
      finalAgreedCurrency: json['final_agreed_currency']?.toString(),
      pickupLocation: json['pickup_location']?.toString(),
      pickupLat: json['pickup_lat']?.toString(),
      pickupLng: json['pickup_lng']?.toString(),
      dropLocation: json['drop_location']?.toString(),
      dropLat: json['drop_lat']?.toString(),
      dropLng: json['drop_lng']?.toString(),
      onrideOtp: json['onride_otp']?.toString(),
      driverName: json['driver_name']?.toString(),
      driverId: json['driver_id']?.toString(),
      driverUserId: json['driver_userid']?.toString(),
      driverRating: json['driver_rating']?.toString(),
      driverMobile: json['driver_mobile']?.toString(),
      driverVehicle: json['driver_vehicle']?.toString(),
      driverVehicleNo: json['driver_vehicleno']?.toString(),
      basePrice: json['base_price']?.toString(),
      driverImage: json['driver_image']?.toString(),
      rideStops: (json['ride_stops'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(RideStop.fromJson)
          .toList(),
      poolingOptIn: json['pooling_opt_in'] == true ||
          json['pooling_opt_in']?.toString() == 'true',
      seatsRequested:
          int.tryParse(json['seats_requested']?.toString() ?? '') ?? 1,
      poolStatus: json['pool_status']?.toString(),
      poolGroupSize:
          int.tryParse(json['pool_group_size']?.toString() ?? '') ?? 1,
      poolDiscountPercent:
          int.tryParse(json['pool_discount_percent']?.toString() ?? '') ?? 0,
      deliveryDetails: json['delivery_details'] is Map<String, dynamic>
          ? DeliveryDetails.fromJson(
              json['delivery_details'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class PassengerBroadcastContext {
  const PassengerBroadcastContext({
    required this.enabled,
    required this.allowed,
    required this.reasonCode,
    required this.message,
    required this.defaultRadiusKm,
    required this.maxRadiusKm,
    required this.defaultExpiryMinutes,
    required this.maxExpiryMinutes,
    required this.maxBroadcastsPerDay,
    required this.passengerBroadcastRadiusKm,
  });

  final bool enabled;
  final bool allowed;
  final String reasonCode;
  final String message;
  final double defaultRadiusKm;
  final double maxRadiusKm;
  final int defaultExpiryMinutes;
  final int maxExpiryMinutes;
  final int? maxBroadcastsPerDay;
  final double passengerBroadcastRadiusKm;

  factory PassengerBroadcastContext.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    final data = result is Map<String, dynamic> ? result : json;
    final allowed =
        data['allowed'] == true || data['allowed']?.toString() == 'true';
    final hasEnabledValue = data.containsKey('enabled');
    return PassengerBroadcastContext(
      // Older API deployments omitted `enabled` even when authorization was
      // granted. In that response shape, `allowed` is the authoritative value.
      enabled: hasEnabledValue
          ? data['enabled'] == true || data['enabled']?.toString() == 'true'
          : allowed,
      allowed: allowed,
      reasonCode: data['reason_code']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      defaultRadiusKm:
          double.tryParse(data['default_radius_km']?.toString() ?? '') ?? 8,
      maxRadiusKm:
          double.tryParse(data['max_radius_km']?.toString() ?? '') ?? 20,
      defaultExpiryMinutes:
          int.tryParse(data['default_expiry_minutes']?.toString() ?? '') ?? 5,
      maxExpiryMinutes:
          int.tryParse(data['max_expiry_minutes']?.toString() ?? '') ?? 15,
      maxBroadcastsPerDay:
          int.tryParse(data['max_broadcasts_per_day']?.toString() ?? ''),
      passengerBroadcastRadiusKm: double.tryParse(
              data['passenger_broadcast_radius_km']?.toString() ?? '') ??
          8,
    );
  }
}

class DriverDestinationBroadcastItem {
  const DriverDestinationBroadcastItem({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverImage,
    required this.vehicleName,
    required this.vehicleNumber,
    required this.originLabel,
    required this.destinationLabel,
    required this.departureTime,
    required this.pricePerPassenger,
    required this.availableSeats,
    required this.remainingSeats,
    required this.notificationRadius,
    required this.status,
  });

  final String id;
  final String driverId;
  final String driverName;
  final String driverImage;
  final String vehicleName;
  final String vehicleNumber;
  final String originLabel;
  final String destinationLabel;
  final DateTime? departureTime;
  final double pricePerPassenger;
  final int availableSeats;
  final int remainingSeats;
  final double notificationRadius;
  final String status;

  factory DriverDestinationBroadcastItem.fromJson(Map<String, dynamic> json) {
    return DriverDestinationBroadcastItem(
      id: json['_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? 'Driver',
      driverImage: json['driver_image']?.toString() ?? '',
      vehicleName: json['vehicle_name']?.toString() ?? '',
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      originLabel: json['origin_label']?.toString() ?? '',
      destinationLabel: json['destination_label']?.toString() ?? '',
      departureTime:
          DateTime.tryParse(json['departure_time']?.toString() ?? ''),
      pricePerPassenger:
          double.tryParse(json['price_per_passenger']?.toString() ?? '') ?? 0,
      availableSeats:
          int.tryParse(json['available_seats']?.toString() ?? '') ?? 0,
      remainingSeats:
          int.tryParse(json['remaining_seats']?.toString() ?? '') ?? 0,
      notificationRadius:
          double.tryParse(json['notification_radius']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

class DriverDestinationJoinRequestItem {
  const DriverDestinationJoinRequestItem({
    required this.id,
    required this.broadcastId,
    required this.pickupLabel,
    required this.requestedSeats,
    required this.status,
    required this.destinationLabel,
    this.departureTime,
    this.pricePerPassenger,
  });

  final String id;
  final String broadcastId;
  final String pickupLabel;
  final int requestedSeats;
  final String status;
  final String destinationLabel;
  final DateTime? departureTime;
  final double? pricePerPassenger;

  factory DriverDestinationJoinRequestItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return DriverDestinationJoinRequestItem(
      id: json['_id']?.toString() ?? '',
      broadcastId: json['broadcast_id']?.toString() ?? '',
      pickupLabel: json['pickup_label']?.toString() ?? '',
      requestedSeats:
          int.tryParse(json['requested_seats']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? '',
      destinationLabel: json['destination_label']?.toString() ?? '',
      departureTime:
          DateTime.tryParse(json['departure_time']?.toString() ?? ''),
      pricePerPassenger:
          double.tryParse(json['price_per_passenger']?.toString() ?? ''),
    );
  }
}

class LocationSelectionArgs {
  const LocationSelectionArgs({
    required this.pickupAddress,
    required this.dropoffAddress,
    this.rideStops = const <RideStop>[],
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  final String pickupAddress;
  final String dropoffAddress;
  final List<RideStop> rideStops;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
}

class LocationSelectionResult {
  const LocationSelectionResult({
    required this.pickupAddress,
    required this.dropoffAddress,
    this.rideStops = const <RideStop>[],
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  final String pickupAddress;
  final String dropoffAddress;
  final List<RideStop> rideStops;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
}
