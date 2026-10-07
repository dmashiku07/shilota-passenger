import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  SessionStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _isLoggedKey = 'isLogged';
  static const _tokenKey = 'token';
  static const _userIdKey = 'userId';
  static const _fullNameKey = 'fullName';
  static const _userImageKey = 'userImage';
  static const _walletKey = 'wallet';
  static const _emailKey = 'email';
  static const _phoneNumberKey = 'phoneNumber';
  static const _countryCodeKey = 'countryCode';
  static const _passwordKey = 'password';

  bool get isLoggedIn => _prefs.getBool(_isLoggedKey) ?? false;
  String? get token => _prefs.getString(_tokenKey);
  String? get userId => _prefs.getString(_userIdKey);
  String? get fullName => _prefs.getString(_fullNameKey);
  String? get userImage => _prefs.getString(_userImageKey);
  String? get wallet => _prefs.getString(_walletKey);
  String? get email => _prefs.getString(_emailKey);
  String? get phoneNumber => _prefs.getString(_phoneNumberKey);
  String? get countryCode => _prefs.getString(_countryCodeKey);
  String? get password => _prefs.getString(_passwordKey);

  Future<void> saveSession({
    required String token,
    required String userId,
    required String fullName,
    String? userImage,
    String? wallet,
    String? email,
    String? phoneNumber,
    String? countryCode,
    String? password,
  }) async {
    await _prefs.setBool(_isLoggedKey, true);
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userIdKey, userId);
    await _prefs.setString(_fullNameKey, fullName);
    if (userImage != null) {
      await _prefs.setString(_userImageKey, userImage);
    }
    if (wallet != null) {
      await _prefs.setString(_walletKey, wallet);
    }
    if (email != null) {
      await _prefs.setString(_emailKey, email);
    }
    if (phoneNumber != null) {
      await _prefs.setString(_phoneNumberKey, phoneNumber);
    }
    if (countryCode != null) {
      await _prefs.setString(_countryCodeKey, countryCode);
    }
    if (password != null) {
      await _prefs.setString(_passwordKey, password);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_isLoggedKey);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userIdKey);
    await _prefs.remove(_fullNameKey);
    await _prefs.remove(_userImageKey);
    await _prefs.remove(_walletKey);
    await _prefs.remove(_emailKey);
    await _prefs.remove(_phoneNumberKey);
    await _prefs.remove(_countryCodeKey);
    await _prefs.remove(_passwordKey);
  }

  Future<void> updateProfile({
    required String fullName,
    String? userImage,
    String? phoneNumber,
    String? countryCode,
  }) async {
    await _prefs.setString(_fullNameKey, fullName);
    if (userImage != null && userImage.isNotEmpty) {
      await _prefs.setString(_userImageKey, userImage);
    }
    if (phoneNumber != null) {
      await _prefs.setString(_phoneNumberKey, phoneNumber);
    }
    if (countryCode != null) {
      await _prefs.setString(_countryCodeKey, countryCode);
    }
  }
}
