class DriverSession {
  const DriverSession({
    required this.userId,
    required this.token,
    required this.fullName,
    this.email,
    this.wallet,
    this.userImage,
    this.vehicleApproval,
    this.adminApproved,
  });

  final String userId;
  final String token;
  final String fullName;
  final String? email;
  final String? wallet;
  final String? userImage;
  final String? vehicleApproval;
  final String? adminApproved;

  factory DriverSession.fromJson(Map<String, dynamic> json) {
    return DriverSession(
      userId: _firstString(json, const ['user_id', '_id', 'id']) ?? '',
      token: _firstString(json, const ['token', 'user_token']) ?? '',
      fullName: _firstString(json, const ['full_name', 'name', 'user_name']) ??
          'Driver',
      email: _firstString(json, const ['email']),
      wallet:
          _firstString(json, const ['walletmoney', 'wallet', 'walletMoney']),
      userImage: _firstString(json, const ['user_image', 'profile_image']),
      vehicleApproval: _firstString(json, const ['vehicle_approval']),
      adminApproved: _firstString(json, const ['admin_approved']),
    );
  }

  bool get isComplete => userId.isNotEmpty && token.isNotEmpty;
}

class DriverProfile {
  const DriverProfile({
    required this.userId,
    required this.fullName,
    this.email,
    this.phoneNumber,
    this.countryCode,
    this.wallet,
    this.userImage,
    this.rating,
    this.vehicleApproval,
    this.adminApproved,
  });

  final String userId;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? countryCode;
  final String? wallet;
  final String? userImage;
  final String? rating;
  final String? vehicleApproval;
  final String? adminApproved;

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      userId: _firstString(json, const ['user_id', '_id', 'id']) ?? '',
      fullName: _firstString(json, const ['full_name', 'name', 'user_name']) ??
          'Driver',
      email: _firstString(json, const ['email']),
      phoneNumber: _firstString(json, const ['phone_number', 'phone']),
      countryCode: _firstString(json, const ['country_code']),
      wallet:
          _firstString(json, const ['walletmoney', 'wallet', 'walletMoney']),
      userImage: _firstString(json, const ['user_image', 'profile_image']),
      rating: _firstString(json, const ['rating', 'avg_rating']),
      vehicleApproval: _firstString(json, const ['vehicle_approval']),
      adminApproved: _firstString(json, const ['admin_approved']),
    );
  }
}

class DriverDashboard {
  const DriverDashboard({
    this.totalRides = '0',
    this.completedRides = '0',
    this.cancelledRides = '0',
    this.wallet = '0.00',
    this.subscriptionStatus,
    this.raw = const <String, dynamic>{},
  });

  final String totalRides;
  final String completedRides;
  final String cancelledRides;
  final String wallet;
  final String? subscriptionStatus;
  final Map<String, dynamic> raw;

  factory DriverDashboard.fromJson(Map<String, dynamic> json) {
    return DriverDashboard(
      totalRides:
          _firstString(json, const ['total_rides', 'totalrides', 'rides']) ??
              '0',
      completedRides: _firstString(
            json,
            const ['completed_rides', 'completedrides', 'completed'],
          ) ??
          '0',
      cancelledRides: _firstString(
            json,
            const ['cancelled_rides', 'cancelledrides', 'cancelled'],
          ) ??
          '0',
      wallet: _firstString(json, const ['walletmoney', 'wallet', 'earnings']) ??
          '0.00',
      subscriptionStatus: _firstString(
        json,
        const ['subscription_status', 'subscriptionStatus'],
      ),
      raw: json,
    );
  }
}

class DriverListItem {
  const DriverListItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.status,
    this.amount,
    this.createdAt,
    this.raw = const <String, dynamic>{},
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? status;
  final String? amount;
  final String? createdAt;
  final Map<String, dynamic> raw;

  factory DriverListItem.fromJson(Map<String, dynamic> json) {
    final pickup = _firstString(json, const ['pickup', 'pickup_address']);
    final drop = _firstString(json, const ['drop', 'drop_address', 'dropoff']);
    return DriverListItem(
      id: _firstString(json, const ['_id', 'id', 'ride_id']) ?? '',
      title: pickup ?? _firstString(json, const ['title', 'name']) ?? 'Ride',
      subtitle: drop ?? _firstString(json, const ['message', 'description']),
      status: _firstString(json, const ['status', 'ride_status']),
      amount: _firstString(json, const ['amount', 'fare', 'total']),
      createdAt: _firstString(json, const ['createdAt', 'created_at', 'date']),
      raw: json,
    );
  }
}

class DriverAdminData {
  const DriverAdminData({
    required this.status,
    this.currencySymbol = 'TZS',
    this.emergencyContact,
  });

  final bool status;
  final String currencySymbol;
  final String? emergencyContact;

  factory DriverAdminData.fromJson(Map<String, dynamic> json) {
    return DriverAdminData(
      status: _firstString(json, const ['status']) == 'true',
      currencySymbol:
          _firstString(json, const ['currency_symbol', 'currencySymbol']) ??
              'TZS',
      emergencyContact:
          _firstString(json, const ['emergencycontact', 'emergencyContact']),
    );
  }
}

String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return null;
}
