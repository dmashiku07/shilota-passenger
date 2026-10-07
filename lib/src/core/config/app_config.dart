class AppConfig {
  const AppConfig._();

  static const appName = 'Shilota';
  static const baseUrl = 'https://shilota.tz/';
  // Socket.IO 1.x reads Uri.port directly, so keep HTTPS port 443 explicit.
  static const socketUrl = 'https://shilota.tz:443';
  static const appRtcUrl = 'https://shilota.tz';
  static const featureFlags = <String, bool>{
    'commission_enabled': false,
    'driver_subscriptions_enabled': true,
    'driver_pricing_enabled': true,
    'passenger_price_broadcast_enabled': true,
    'driver_destination_broadcast_enabled': true,
  };

  static const primaryColorHex = 0xFFF04E29;
  static const primaryDarkColorHex = 0xFFD84322;
  static const secondaryColorHex = 0xFFFFFFFF;
  static const accentColorHex = 0xFF9C9B9B;

  static const textPrimaryColorHex = 0xFF1E1E1E;
  static const textSecondaryColorHex = 0xFF474747;
  static const textTertiaryColorHex = 0xFF9C9B9B;
  static const lineColorHex = 0xFFC9C9C9;
  static const greenColorHex = 0xFF1FB545;
  static const redColorHex = 0xFFD22121;
  static const blueColorHex = 0xFF136FCD;
  static const lightBlueColorHex = 0xFFE6EEF5;
  static const notificationColorHex = 0xFFFE9352;
  static const transparentBlackHex = 0xFFC9000000;

  static const currencySymbol = 'TSh';
  static const emergencyContact = '';
  static const defaultLanguage = 'English';
  static const defaultLanguageCode = 'en';
  static const maxSearchCount = 13;
  static const dialogDelayMs = 2000;
  static const emailPattern =
      r'^[_A-Za-z0-9-\+]+(\.[_A-Za-z0-9-]+)*@[A-Za-z0-9-]+(\.[A-Za-z0-9]+)*(\.[A-Za-z]{2,})$';

  static const textSizeVerySmall = 10.0;
  static const textSizeSmall = 12.0;
  static const textSizeMedium = 14.0;
  static const textSizeMediumLarge = 16.0;
  static const textSizeLarge = 18.0;
  static const textSizeHeader = 22.0;
}
