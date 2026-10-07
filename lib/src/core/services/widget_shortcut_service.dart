import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/domain/account_models.dart';

final widgetShortcutServiceProvider = Provider<WidgetShortcutService>((ref) {
  return const WidgetShortcutService();
});

class WidgetShortcutService {
  const WidgetShortcutService();

  static const MethodChannel _channel =
      MethodChannel('shilota/widget_shortcuts');

  Future<void> syncSavedPlaces(List<SavedPlace> places) async {
    final home = _findPlace(places, 'home');
    final work = _findPlace(places, 'work');
    try {
      await _channel.invokeMethod<void>('syncSavedPlaces', <String, dynamic>{
        'homeLabel': _buildLabel(home, 'Home'),
        'workLabel': _buildLabel(work, 'Work'),
      });
    } catch (_) {}
  }

  SavedPlace? _findPlace(List<SavedPlace> places, String type) {
    for (final place in places) {
      if (place.placeType.toLowerCase() == type) {
        return place;
      }
    }
    return null;
  }

  String _buildLabel(SavedPlace? place, String fallback) {
    if (place == null) {
      return fallback;
    }
    final address = place.displayAddress.trim();
    if (address.isEmpty) {
      return fallback;
    }
    return '$fallback\n${_truncate(address)}';
  }

  String _truncate(String value) {
    if (value.length <= 28) {
      return value;
    }
    return '${value.substring(0, 25)}...';
  }
}
