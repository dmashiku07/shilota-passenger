import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../account/data/account_repository.dart';
import '../../account/domain/account_models.dart';
import '../domain/ride_models.dart';

class SelectLocationPage extends ConsumerStatefulWidget {
  const SelectLocationPage({
    required this.args,
    super.key,
  });

  static const routePath = '/select-location';

  final LocationSelectionArgs args;

  @override
  ConsumerState<SelectLocationPage> createState() => _SelectLocationPageState();
}

class _SelectLocationPageState extends ConsumerState<SelectLocationPage> {
  static final RegExp _plusCodePattern = RegExp(
    r'^[23456789CFGHJMPQRVWX]{4,}\+[23456789CFGHJMPQRVWX]{2,}$',
    caseSensitive: false,
  );
  static const MethodChannel _placesChannel = MethodChannel(
    'shilota/places',
  );
  late final TextEditingController _pickupController;
  late final TextEditingController _dropoffController;
  late final FocusNode _pickupFocus;
  late final FocusNode _dropoffFocus;

  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  late List<RideStop> _rideStops;
  bool _savingFavorite = false;
  bool _locating = false;
  bool _pickupActive = false;
  late Future<ApiListResponse<SavedPlace>> _savedPlacesFuture;

  List<_PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;
  String _placesSessionToken = '';
  bool _suppressTextListener = false;

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController(text: widget.args.pickupAddress);
    _dropoffController =
        TextEditingController(text: widget.args.dropoffAddress);
    _pickupFocus = FocusNode();
    _dropoffFocus = FocusNode();
    _pickupLatLng =
        widget.args.pickupLat != null && widget.args.pickupLng != null
            ? LatLng(widget.args.pickupLat!, widget.args.pickupLng!)
            : null;
    _dropoffLatLng =
        widget.args.dropoffLat != null && widget.args.dropoffLng != null
            ? LatLng(widget.args.dropoffLat!, widget.args.dropoffLng!)
            : null;
    _rideStops = widget.args.rideStops
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(sequence: entry.key + 1))
        .toList();
    _savedPlacesFuture = ref.read(accountRepositoryProvider).getSavedPlaces();
    _pickupFocus.addListener(_onFocusChanged);
    _dropoffFocus.addListener(_onFocusChanged);
    _pickupController.addListener(_onPickupChanged);
    _dropoffController.addListener(_onDropoffChanged);
  }

  @override
  void dispose() {
    _pickupController.removeListener(_onPickupChanged);
    _dropoffController.removeListener(_onDropoffChanged);
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupFocus.removeListener(_onFocusChanged);
    _dropoffFocus.removeListener(_onFocusChanged);
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _pickupActive = _pickupFocus.hasFocus;
    });
    if (!_pickupFocus.hasFocus && !_dropoffFocus.hasFocus) {
      _clearSuggestions();
    }
  }

  void _onPickupChanged() {
    if (_suppressTextListener) {
      return;
    }
    _debounce?.cancel();
    final text = _pickupController.text.trim();
    if (text.length < 2 || !_pickupFocus.hasFocus) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(text);
    });
  }

  void _onDropoffChanged() {
    if (_suppressTextListener) {
      return;
    }
    _debounce?.cancel();
    final text = _dropoffController.text.trim();
    if (text.length < 2 || !_dropoffFocus.hasFocus) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(text);
    });
  }

  Future<void> _searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      _clearSuggestions();
      return;
    }
    setState(() => _isSearching = true);
    try {
      if (_placesSessionToken.isEmpty) {
        _placesSessionToken = _newPlacesSessionToken();
      }
      final response = await _placesChannel.invokeListMethod<dynamic>(
            'autocomplete',
            <String, dynamic>{
              'query': trimmed,
              'sessionToken': _placesSessionToken,
            },
          ) ??
          const <dynamic>[];
      if (!mounted) return;
      final results = response
          .take(6)
          .map((dynamic item) {
            final map = _asStringKeyedMap(item);
            return _PlaceSuggestion(
              placeId: map['placeId']?.toString(),
              title: map['title']?.toString().trim() ?? '',
              subtitle: map['subtitle']?.toString().trim().isNotEmpty == true
                  ? map['subtitle'].toString().trim()
                  : null,
            );
          })
          .where((item) => item.title.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      _showSnack('$error');
    }
  }

  void _clearSuggestions() {
    if (_suggestions.isNotEmpty || _isSearching) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
    }
  }

  bool get _isSearchActive => _suggestions.isNotEmpty || _isSearching;

  String _newPlacesSessionToken() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = math.Random.secure();
    return List<String>.generate(
      24,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return const <String, dynamic>{};
  }

  Future<void> _refreshSavedPlaces() async {
    setState(() {
      _savedPlacesFuture = ref.read(accountRepositoryProvider).getSavedPlaces();
    });
  }

  Future<LatLng> _resolveCoordinates(String address) async {
    final locations = await locationFromAddress(address.trim());
    if (locations.isEmpty) {
      throw const _SelectLocationException('Address could not be located');
    }
    final first = locations.first;
    return LatLng(first.latitude, first.longitude);
  }

  Future<_PlaceSuggestion> _resolveSuggestionDetails(
    _PlaceSuggestion suggestion,
  ) async {
    if (suggestion.latitude != null && suggestion.longitude != null) {
      return suggestion;
    }
    final placeId = suggestion.placeId?.trim() ?? '';
    if (placeId.isEmpty) {
      throw const _SelectLocationException('Place details are unavailable');
    }
    final data = await _placesChannel.invokeMapMethod<String, dynamic>(
      'fetchPlaceDetails',
      <String, dynamic>{
        'placeId': placeId,
        'sessionToken': _placesSessionToken,
      },
    );
    final normalizedData = _asStringKeyedMap(data);
    if (normalizedData.isEmpty) {
      throw const _SelectLocationException('Unable to load place details');
    }
    final latitude = (normalizedData['latitude'] as num?)?.toDouble();
    final longitude = (normalizedData['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const _SelectLocationException('Selected place has no coordinates');
    }
    final title = normalizedData['title']?.toString().trim().isNotEmpty == true
        ? normalizedData['title'].toString().trim()
        : suggestion.title;
    final formattedAddress = normalizedData['subtitle']?.toString().trim();
    final normalizedSubtitle =
        formattedAddress != null && formattedAddress.isNotEmpty
            ? formattedAddress
            : suggestion.subtitle;
    return suggestion.copyWith(
      title: title,
      subtitle: normalizedSubtitle,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _SelectLocationException('Location permission is required');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      final address = await _describePoint(point);
      if (!mounted) {
        return;
      }

      setState(() {
        _pickupController.text = _joinAddress(address.$1, address.$2);
        _pickupLatLng = point;
        _pickupActive = false;
      });
      _dropoffFocus.requestFocus();
    } catch (error) {
      _showSnack('$error');
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<(String, String?)> _describePoint(LatLng point) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) {
        return (
          'Pinned location',
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        );
      }
      final place = placemarks.first;
      final rawTitle = _firstMeaningfulPart(<String?>[
        place.name,
        place.street,
        place.thoroughfare,
        place.subLocality,
      ]);
      final title = rawTitle ?? 'Pinned location';
      final subtitle = _joinDistinctParts(
        <String?>[
          place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.country,
        ],
        exclude: <String>{title},
      );
      return (
        title,
        subtitle.isEmpty
            ? '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}'
            : subtitle,
      );
    } catch (_) {
      return (
        'Pinned location',
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
      );
    }
  }

  String? _firstMeaningfulPart(List<String?> candidates) {
    for (final candidate in candidates) {
      final clean = _cleanAddressPart(candidate);
      if (clean.isNotEmpty) {
        return clean;
      }
    }
    return null;
  }

  String _joinDistinctParts(
    List<String?> parts, {
    Set<String> exclude = const <String>{},
  }) {
    final normalizedExcludes = exclude
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final unique = <String>[];
    final seen = <String>{};
    for (final part in parts) {
      final clean = _cleanAddressPart(part);
      if (clean.isEmpty) {
        continue;
      }
      final key = clean.toLowerCase();
      if (seen.contains(key) || normalizedExcludes.contains(key)) {
        continue;
      }
      seen.add(key);
      unique.add(clean);
    }
    return unique.join(', ');
  }

  String _cleanAddressPart(String? value) {
    final clean = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty || _plusCodePattern.hasMatch(clean)) {
      return '';
    }
    return clean;
  }

  String _joinAddress(String title, String? subtitle) {
    final secondary = (subtitle ?? '').trim();
    if (secondary.isEmpty) {
      return title;
    }
    return '$title, $secondary';
  }

  Future<void> _applySuggestion(_PlaceSuggestion suggestion) async {
    try {
      final resolved = await _resolveSuggestionDetails(suggestion);
      if (!mounted) {
        return;
      }
      _debounce?.cancel();
      _suppressTextListener = true;
      setState(() {
        if (_pickupActive) {
          _pickupController.text = resolved.displayAddress;
          _pickupLatLng = LatLng(resolved.latitude!, resolved.longitude!);
        } else {
          _dropoffController.text = resolved.displayAddress;
          _dropoffLatLng = LatLng(resolved.latitude!, resolved.longitude!);
        }
        _suggestions = [];
        _placesSessionToken = '';
        _pickupActive = false;
      });
      _pickupFocus.unfocus();
      _dropoffFocus.unfocus();
      _suppressTextListener = false;
    } catch (error) {
      _suppressTextListener = false;
      _showSnack('$error');
    }
  }

  void _applySavedPlace(SavedPlace place) {
    _debounce?.cancel();
    _suppressTextListener = true;
    setState(() {
      if (_pickupActive) {
        _pickupController.text = place.placeFullAddress.isEmpty
            ? place.placeName
            : place.placeFullAddress;
        _pickupLatLng = LatLng(place.latitude, place.longitude);
      } else {
        _dropoffController.text = place.placeFullAddress.isEmpty
            ? place.placeName
            : place.placeFullAddress;
        _dropoffLatLng = LatLng(place.latitude, place.longitude);
      }
      _suggestions = [];
      _pickupActive = false;
      _placesSessionToken = '';
    });
    _pickupFocus.unfocus();
    _dropoffFocus.unfocus();
    _suppressTextListener = false;
  }

  Future<void> _saveActiveFieldAsFavorite() async {
    final isPickup = _pickupActive;
    final address = isPickup
        ? _pickupController.text.trim()
        : _dropoffController.text.trim();
    if (address.isEmpty) {
      _showSnack('Enter a location first');
      return;
    }

    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Save Location As',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                for (final option in const ['Home', 'Work', 'Other'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (type == null) {
      return;
    }

    setState(() {
      _savingFavorite = true;
    });
    try {
      final point = isPickup
          ? (_pickupLatLng ?? await _resolveCoordinates(address))
          : (_dropoffLatLng ?? await _resolveCoordinates(address));
      await ref.read(accountRepositoryProvider).savePlace(
            placeName: type,
            placeFullAddress: address,
            latitude: point.latitude,
            longitude: point.longitude,
            placeType: type,
          );
      await _refreshSavedPlaces();
      _showSnack('Saved to favorite locations');
    } catch (error) {
      _showSnack('$error');
    } finally {
      if (mounted) {
        setState(() {
          _savingFavorite = false;
        });
      }
    }
  }

  Future<void> _confirmSelection() async {
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) {
      _showSnack('Pickup and destination are required');
      return;
    }

    try {
      final pickupPoint = _pickupLatLng ?? await _resolveCoordinates(pickup);
      final dropoffPoint = _dropoffLatLng ?? await _resolveCoordinates(dropoff);
      final rideStops = _normalizedStops(
        pickupPoint: pickupPoint,
        dropoffPoint: dropoffPoint,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        LocationSelectionResult(
          pickupAddress: pickup,
          dropoffAddress: dropoff,
          rideStops: rideStops,
          pickupLat: pickupPoint.latitude,
          pickupLng: pickupPoint.longitude,
          dropoffLat: dropoffPoint.latitude,
          dropoffLng: dropoffPoint.longitude,
        ),
      );
    } catch (error) {
      _showSnack('$error');
    }
  }

  List<RideStop> _normalizedStops({
    LatLng? pickupPoint,
    LatLng? dropoffPoint,
  }) {
    final clean = <RideStop>[];
    for (final stop in _rideStops) {
      final sameAsPickup = pickupPoint != null &&
          _isSamePoint(
            pickupPoint.latitude,
            pickupPoint.longitude,
            stop.latitude,
            stop.longitude,
          );
      final sameAsDropoff = dropoffPoint != null &&
          _isSamePoint(
            dropoffPoint.latitude,
            dropoffPoint.longitude,
            stop.latitude,
            stop.longitude,
          );
      final duplicate = clean.any(
        (item) => _isSamePoint(
          item.latitude,
          item.longitude,
          stop.latitude,
          stop.longitude,
        ),
      );
      if (!sameAsPickup && !sameAsDropoff && !duplicate) {
        clean.add(stop);
      }
    }

    return clean
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(sequence: entry.key + 1))
        .toList();
  }

  Future<void> _addStop() async {
    if (_rideStops.length >= 4) {
      _showSnack('You can add up to 4 stops only');
      return;
    }

    final stop = await showModalBottomSheet<RideStop>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AddStopSheet(
        onSearch: _searchStopSuggestions,
        onSelect: _resolveSuggestionDetails,
      ),
    );

    if (stop == null || !mounted) {
      return;
    }

    final pickup = _pickupLatLng;
    final dropoff = _dropoffLatLng;
    final sameAsPickup = pickup != null &&
        _isSamePoint(
          pickup.latitude,
          pickup.longitude,
          stop.latitude,
          stop.longitude,
        );
    final sameAsDropoff = dropoff != null &&
        _isSamePoint(
          dropoff.latitude,
          dropoff.longitude,
          stop.latitude,
          stop.longitude,
        );
    final duplicateStop = _rideStops.any(
      (item) => _isSamePoint(
        item.latitude,
        item.longitude,
        stop.latitude,
        stop.longitude,
      ),
    );

    if (sameAsPickup || sameAsDropoff || duplicateStop) {
      _showSnack('This stop is already part of the route');
      return;
    }

    setState(() {
      _rideStops = [
        ..._rideStops,
        stop.copyWith(sequence: _rideStops.length + 1),
      ];
    });
  }

  Future<List<_PlaceSuggestion>> _searchStopSuggestions(String query) async {
    if (_placesSessionToken.isEmpty) {
      _placesSessionToken = _newPlacesSessionToken();
    }
    final response = await _placesChannel.invokeListMethod<dynamic>(
          'autocomplete',
          <String, dynamic>{
            'query': query.trim(),
            'sessionToken': _placesSessionToken,
          },
        ) ??
        const <dynamic>[];
    return response
        .take(6)
        .map((dynamic item) {
          final map = _asStringKeyedMap(item);
          return _PlaceSuggestion(
            placeId: map['placeId']?.toString(),
            title: map['title']?.toString().trim() ?? '',
            subtitle: map['subtitle']?.toString().trim().isNotEmpty == true
                ? map['subtitle'].toString().trim()
                : null,
          );
        })
        .where((item) => item.title.isNotEmpty)
        .toList();
  }

  void _removeStop(int index) {
    setState(() {
      _rideStops = [
        for (var i = 0; i < _rideStops.length; i++)
          if (i != index) _rideStops[i],
      ];
      _rideStops = _normalizedStops();
    });
  }

  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      final updated = [..._rideStops];
      final item = updated.removeAt(oldIndex);
      updated.insert(newIndex, item);
      _rideStops = updated
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(sequence: entry.key + 1))
          .toList();
    });
  }

  bool _isSamePoint(
    double firstLat,
    double firstLng,
    double secondLat,
    double secondLng,
  ) {
    return (firstLat - secondLat).abs() < 0.0001 &&
        (firstLng - secondLng).abs() < 0.0001;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(
        title: const Text('Plan your trip'),
      ),
      bottomNavigationBar: _isSearchActive
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmSelection,
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TripField(
                color: const Color(0xFF59C36A),
                title: 'Current Location',
                controller: _pickupController,
                focusNode: _pickupFocus,
                trailing: IconButton(
                  onPressed: _locating ? null : _useCurrentLocation,
                  tooltip: 'Use current location',
                  icon: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.gps_fixed_rounded),
                ),
              ),
              const SizedBox(height: 12),
              _TripField(
                color: const Color(0xFFC74732),
                title: 'Where to?',
                controller: _dropoffController,
                focusNode: _dropoffFocus,
                trailing: IconButton(
                  onPressed:
                      _savingFavorite ? null : _saveActiveFieldAsFavorite,
                  tooltip: 'Swap locations',
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
              ),
              const SizedBox(height: 14),
              _StopSummaryCard(
                stops: _rideStops,
                onAddStop: _addStop,
                onRemoveStop: _removeStop,
                onReorderStops: _reorderStops,
              ),
              const SizedBox(height: 16),
              Expanded(
                child:
                    _isSearchActive ? _buildSuggestions() : _buildSavedPlaces(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_suggestions.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Color(0xFF6A5D57)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFEEE8),
            child: Icon(
              Icons.place_rounded,
              color: Color(0xFFF04E29),
            ),
          ),
          title: Text(
            suggestion.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: suggestion.subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    suggestion.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6A5D57)),
                  ),
                ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4F0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _pickupActive ? 'Pickup' : 'Drop-off',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF04E29),
              ),
            ),
          ),
          onTap: () => _applySuggestion(suggestion),
        );
      },
    );
  }

  Widget _buildSavedPlaces() {
    return FutureBuilder<ApiListResponse<SavedPlace>>(
      future: _savedPlacesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }

        final items = snapshot.data?.items ?? const <SavedPlace>[];
        if (items.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Type above to search for a location, or save your common destinations here.',
                style: TextStyle(color: Color(0xFF6A5D57)),
              ),
            ),
          );
        }

        return ListView(
          children: [
            const Text(
              'Saved Places',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    return _AddPlaceCard(
                      onTap: _saveActiveFieldAsFavorite,
                    );
                  }
                  final item = items[index];
                  return _SavedPlaceCard(
                    item: item,
                    onTap: () => _applySavedPlace(item),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Most Visited',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in items) ...[
              _PlaceListTile(
                item: item,
                onTap: () => _applySavedPlace(item),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({
    this.placeId,
    required this.title,
    this.subtitle,
    this.latitude,
    this.longitude,
  });

  final String? placeId;
  final String title;
  final String? subtitle;
  final double? latitude;
  final double? longitude;

  String get displayAddress {
    final secondary = (subtitle ?? '').trim();
    if (secondary.isEmpty) {
      return title;
    }
    return '$title, $secondary';
  }

  _PlaceSuggestion copyWith({
    String? placeId,
    String? title,
    String? subtitle,
    double? latitude,
    double? longitude,
  }) {
    return _PlaceSuggestion(
      placeId: placeId ?? this.placeId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class _TripField extends StatelessWidget {
  const _TripField({
    required this.color,
    required this.title,
    required this.controller,
    required this.focusNode,
    required this.trailing,
  });

  final Color color;
  final String title;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              if (title != 'Where to?')
                Container(
                  width: 2,
                  height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: const Color(0xFFE7D8D2),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: title == 'Where to?'
                    ? const Color(0xFFF04E29)
                    : const Color(0xFFE9E0DB),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 2,
                    textInputAction: title == 'Where to?'
                        ? TextInputAction.search
                        : TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: title,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StopSummaryCard extends StatelessWidget {
  const _StopSummaryCard({
    required this.stops,
    required this.onAddStop,
    required this.onRemoveStop,
    required this.onReorderStops,
  });

  final List<RideStop> stops;
  final VoidCallback onAddStop;
  final ValueChanged<int> onRemoveStop;
  final void Function(int oldIndex, int newIndex) onReorderStops;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Stops',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAddStop,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add stop'),
              ),
            ],
          ),
          if (stops.isEmpty)
            const Text(
              'No intermediate stops yet. Add up to 4 stops for this trip.',
              style: TextStyle(color: Color(0xFF6A5D57)),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stops.length > 1)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Press and drag to reorder your stops.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6A5D57),
                      ),
                    ),
                  ),
                ReorderableListView.builder(
                  key: const ValueKey('ride-stops-reorderable'),
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stops.length,
                  onReorderItem: onReorderStops,
                  itemBuilder: (context, index) {
                    return Padding(
                      key: ValueKey(
                        '${stops[index].location}-${stops[index].sequence}-$index',
                      ),
                      padding: EdgeInsets.only(
                        bottom: index == stops.length - 1 ? 0 : 10,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4F0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFFFE8E1),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFFF04E29),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stops[index].location,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  color: Color(0xFF6A5D57),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => onRemoveStop(index),
                              tooltip: 'Remove stop',
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AddStopSheet extends StatefulWidget {
  const _AddStopSheet({
    required this.onSearch,
    required this.onSelect,
  });

  final Future<List<_PlaceSuggestion>> Function(String query) onSearch;
  final Future<_PlaceSuggestion> Function(_PlaceSuggestion suggestion) onSelect;

  @override
  State<_AddStopSheet> createState() => _AddStopSheetState();
}

class _AddStopSheetState extends State<_AddStopSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  List<_PlaceSuggestion> _suggestions = const <_PlaceSuggestion>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const <_PlaceSuggestion>[];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _isSearching = true;
      });
      try {
        final suggestions = await widget.onSearch(query);
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions = suggestions;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions = const <_PlaceSuggestion>[];
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add stop',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Search stop location',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _suggestions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Type at least 2 characters to search.',
                            style: TextStyle(color: Color(0xFF6A5D57)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _suggestions[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFEEE8),
                                child: Icon(
                                  Icons.place_rounded,
                                  color: Color(0xFFF04E29),
                                ),
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: item.subtitle == null
                                  ? null
                                  : Text(
                                      item.subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF6A5D57),
                                      ),
                                    ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                              ),
                              onTap: () async {
                                try {
                                  final resolved = await widget.onSelect(item);
                                  if (!context.mounted) {
                                    return;
                                  }
                                  Navigator.of(context).pop(
                                    RideStop(
                                      location: resolved.displayAddress,
                                      latitude: resolved.latitude!,
                                      longitude: resolved.longitude!,
                                      sequence: 0,
                                    ),
                                  );
                                } catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$error')),
                                  );
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPlaceCard extends StatelessWidget {
  const _SavedPlaceCard({
    required this.item,
    required this.onTap,
  });

  final SavedPlace item;
  final VoidCallback onTap;

  String get _addressLabel =>
      item.placeFullAddress.isEmpty ? item.placeName : item.placeFullAddress;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (item.placeType.toLowerCase()) {
      case 'home':
        icon = Icons.home_rounded;
        break;
      case 'work':
        icon = Icons.work_rounded;
        break;
      default:
        icon = Icons.place_rounded;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        width: 166,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFE8E1),
              child: Icon(icon, color: const Color(0xFFF04E29)),
            ),
            const SizedBox(height: 14),
            Text(
              item.placeType.isEmpty ? 'Saved place' : item.placeType,
              style: const TextStyle(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                _addressLabel,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6A5D57),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPlaceCard extends StatelessWidget {
  const _AddPlaceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        width: 166,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE7D8D2),
            style: BorderStyle.solid,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFF8F5F3),
                child: Icon(Icons.add_rounded, color: Color(0xFF231814)),
              ),
              SizedBox(height: 12),
              Text(
                'Add New',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceListTile extends StatelessWidget {
  const _PlaceListTile({
    required this.item,
    required this.onTap,
  });

  final SavedPlace item;
  final VoidCallback onTap;

  String get _addressLabel =>
      item.placeFullAddress.isEmpty ? item.placeName : item.placeFullAddress;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (item.placeType.toLowerCase()) {
      case 'home':
        icon = Icons.home_rounded;
        break;
      case 'work':
        icon = Icons.work_rounded;
        break;
      default:
        icon = Icons.place_rounded;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFEEE8),
              child: Icon(icon, color: const Color(0xFFF04E29)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.placeType.isEmpty ? 'Saved place' : item.placeType,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _addressLabel,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6A5D57)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectLocationException implements Exception {
  const _SelectLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
