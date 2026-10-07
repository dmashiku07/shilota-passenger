class AuthResponse {
  const AuthResponse({
    required this.status,
    required this.message,
    this.userId,
    this.otp,
    this.fullName,
    this.userImage,
    this.email,
    this.password,
    this.countryCode,
    this.phoneNumber,
    this.token,
    this.walletMoney,
  });

  final String status;
  final String message;
  final String? userId;
  final String? otp;
  final String? fullName;
  final String? userImage;
  final String? email;
  final String? password;
  final String? countryCode;
  final String? phoneNumber;
  final String? token;
  final String? walletMoney;

  bool get isSuccess => status.toLowerCase() == 'true';

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    String? asString(dynamic value) => value?.toString();

    return AuthResponse(
      status: asString(json['status']) ?? 'false',
      message: asString(json['message']) ?? 'Something went wrong',
      userId: asString(json['user_id']),
      otp: asString(json['otp']),
      fullName: asString(json['full_name']),
      userImage: asString(json['user_image']),
      email: asString(json['email']),
      password: asString(json['password']),
      countryCode: asString(json['country_code']),
      phoneNumber: asString(json['phone_number']),
      token: asString(json['token']),
      walletMoney: asString(json['walletmoney']),
    );
  }
}

class PendingSignup {
  const PendingSignup({
    required this.fullName,
    required this.email,
    required this.password,
    this.countryCode = '255',
    this.phoneNumber,
  });

  final String fullName;
  final String email;
  final String password;
  final String countryCode;
  final String? phoneNumber;

  PendingSignup copyWith({
    String? fullName,
    String? email,
    String? password,
    String? countryCode,
    String? phoneNumber,
  }) {
    return PendingSignup(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
