import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../account/data/account_repository.dart';
import '../../account/domain/account_models.dart';
import '../../account/presentation/active_call_page.dart';
import '../../account/presentation/notifications_page.dart';
import '../../account/presentation/ride_chat_page.dart';
import '../../account/presentation/ride_history_page.dart';
import '../../account/presentation/sos_page.dart';
import '../../account/presentation/write_review_page.dart';
import '../data/ride_repository.dart';
import '../domain/ride_models.dart';
import 'app_drawer.dart';
import 'select_location_page.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({
    super.key,
    this.shortcutType,
    this.activeRideId,
    this.draft,
  });

  static const routePath = '/home';

  final String? shortcutType;
  final String? activeRideId;
  final RideBookingDraft? draft;

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _passengerPriceController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _dropoffFocus = FocusNode();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  List<LatLng> _routePolylinePoints = const <LatLng>[];
  String _statusMessage = 'Locating your current pickup point...';
  bool _isInitializing = true;
  bool _isFetchingQuotes = false;
  bool _isRequestingRide = false;
  bool _isFindingDriver = false;
  bool _isScheduleMode = false;
  bool _poolingEnabled = false;
  int _poolSeatsRequested = 1;
  PoolingSettings? _poolingSettings;
  DeliveryDetails _deliveryDetails = const DeliveryDetails(
    parcelType: '',
    parcelSize: '',
    recipientName: '',
    recipientPhone: '',
    senderNote: '',
    handoffCode: '',
    proofRequired: false,
  );
  List<AvailableRideItem> _quotes = const <AvailableRideItem>[];
  List<SavedPlace> _savedPlaces = const <SavedPlace>[];
  List<RideStop> _rideStops = const <RideStop>[];
  String _selectedServiceMode = 'ride';
  int _selectedRideIndex = 0;
  ConfirmRideResponse? _acceptedRide;
  List<DriverRideOffer> _driverOffers = const <DriverRideOffer>[];
  PassengerBroadcastContext? _passengerBroadcastContext;
  bool _usePassengerPriceBroadcast = false;
  RequestRideResponse? _scheduledRide;
  DateTime? _scheduledAt;
  String? _onrideId;
  String? _scheduledDraftRideId;
  bool _isAcceptingOffer = false;
  Timer? _rideStatusTimer;
  Timer? _offerRefreshTimer;
  bool _isCheckingRideStatus = false;
  bool _isRefreshingOffers = false;
  String _activeRideStatus = '';
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      // App bootstrap may run before authentication and skip its first socket
      // connection. Retry here, once the signed-in passenger reaches Home.
      try {
        await ref.read(realtimeServiceProvider).connect();
      } catch (error) {
        debugPrint('Realtime home connection failed: $error');
      }
      await _restoreActiveRide();
      await _bootstrapLocation();
      await _loadSavedPlaces();
      await _loadPassengerBroadcastContext();
      await _applyEntryState();
    });
  }

  Future<void> _restoreActiveRide() async {
    if (_onrideId != null || _scheduledDraftRideId != null) {
      return;
    }
    try {
      final requestedRideId = widget.activeRideId?.trim() ?? '';
      final snapshot = requestedRideId.isEmpty
          ? await ref.read(rideRepositoryProvider).getActiveRide()
          : null;
      final onrideId = requestedRideId.isNotEmpty
          ? requestedRideId
          : snapshot?['onride_id'] ?? '';
      if (onrideId.isEmpty) {
        return;
      }
      final rideStatus = requestedRideId.isNotEmpty
          ? await ref.read(rideRepositoryProvider).getRideStatus(onrideId)
          : snapshot?['ride_status'] ?? '';
      const activeStatuses = <String>{
        'requested',
        'accepted',
        'ontheway',
        'onride',
      };
      if (!activeStatuses.contains(rideStatus)) {
        return;
      }
      final ride = await ref.read(rideRepositoryProvider).confirmRide(onrideId);
      if (!mounted) {
        return;
      }

      final pickup = _coordinate(ride.pickupLat, ride.pickupLng);
      final dropoff = _coordinate(ride.dropLat, ride.dropLng);
      setState(() {
        _onrideId = onrideId;
        _activeRideStatus = rideStatus;
        _acceptedRide = ride.isAccepted ? ride : null;
        _driverOffers =
            ride.isAccepted ? const <DriverRideOffer>[] : ride.offers;
        _isFindingDriver = !ride.isAccepted && !ride.hasDriverOffers;
        _pickupLatLng = pickup ?? _pickupLatLng;
        _dropoffLatLng = dropoff ?? _dropoffLatLng;
        if ((ride.pickupLocation ?? '').isNotEmpty) {
          _pickupController.text = ride.pickupLocation!;
        }
        if ((ride.dropLocation ?? '').isNotEmpty) {
          _dropoffController.text = ride.dropLocation!;
        }
        _statusMessage = ride.isAccepted
            ? 'Your driver is on the way to the pickup.'
            : ride.hasDriverOffers
                ? 'Choose the driver offer that works best for you.'
                : 'Waiting for a driver to accept your ride.';
      });
      if (ride.isAccepted) {
        _startRideStatusMonitoring();
      } else if (ride.hasDriverOffers) {
        _startOfferMonitoring();
      }
      if (pickup != null && dropoff != null) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _moveCameraToBounds(pickup, dropoff);
      }
    } catch (_) {
      // Home remains usable for a new booking if active-ride restoration is
      // temporarily unavailable.
    }
  }

  LatLng? _coordinate(String? lat, String? lng) {
    final parsedLat = double.tryParse(lat ?? '');
    final parsedLng = double.tryParse(lng ?? '');
    if (parsedLat == null || parsedLng == null) {
      return null;
    }
    return LatLng(parsedLat, parsedLng);
  }

  @override
  void dispose() {
    _rideStatusTimer?.cancel();
    _offerRefreshTimer?.cancel();
    _pickupController.dispose();
    _dropoffController.dispose();
    _passengerPriceController.dispose();
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _bootstrapLocation() async {
    try {
      final permission = await _ensureLocationPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _isInitializing = false;
          _statusMessage =
              'Location permission is required to load pickup automatically.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final pickupLatLng = LatLng(position.latitude, position.longitude);
      final pickupAddress = await _reverseGeocode(pickupLatLng);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;
        _isInitializing = false;
        if (_onrideId == null) {
          _pickupLatLng = pickupLatLng;
          _pickupController.text = pickupAddress;
          _statusMessage = 'Choose your destination to see available rides.';
        }
      });

      unawaited(
        ref.read(rideRepositoryProvider).updatePassengerLocation(
              lat: position.latitude,
              lng: position.longitude,
              location: pickupAddress,
            ),
      );

      if (_onrideId == null) {
        await _moveCamera(pickupLatLng);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Unable to load current location: $error';
      });
    }
  }

  Future<void> _loadSavedPlaces() async {
    try {
      final response =
          await ref.read(accountRepositoryProvider).getSavedPlaces();
      if (!mounted) {
        return;
      }
      setState(() {
        _savedPlaces = response.items;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savedPlaces = const <SavedPlace>[];
      });
    }
  }

  Future<void> _loadPassengerBroadcastContext() async {
    PassengerBroadcastContext? contextValue;
    try {
      contextValue =
          await ref.read(rideRepositoryProvider).getPassengerBroadcastContext();
    } catch (_) {
      // Fall back to the active subscription snapshot below. This keeps the
      // booking flow usable during a rolling backend deployment.
    }

    if (contextValue == null || !contextValue.allowed) {
      try {
        final overview = await ref
            .read(accountRepositoryProvider)
            .getPassengerSubscriptionOverview();
        final subscription = overview.currentSubscription;
        if (subscription != null &&
            subscription.isActive &&
            _subscriptionFeatureEnabled(
              subscription,
              'CAN_SET_RIDE_PRICE',
            ) &&
            _subscriptionFeatureEnabled(
              subscription,
              'CAN_BROADCAST_RIDE_REQUEST',
            )) {
          contextValue = _contextFromSubscription(subscription);
        }
      } catch (_) {
        // Leave the API context unchanged when both eligibility lookups fail.
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _passengerBroadcastContext = contextValue;
      _usePassengerPriceBroadcast =
          contextValue != null && contextValue.enabled && contextValue.allowed;
    });
    if (!_usePassengerPriceBroadcast) {
      _passengerPriceController.clear();
    }
  }

  bool _subscriptionFeatureEnabled(
    PassengerSubscriptionData subscription,
    String featureCode,
  ) {
    return subscription.features.any((feature) {
      if (feature.featureCode != featureCode) {
        return false;
      }
      final value = feature.featureValue;
      return value == true || value?.toString().toLowerCase() == 'true';
    });
  }

  PassengerBroadcastContext _contextFromSubscription(
    PassengerSubscriptionData subscription,
  ) {
    Object? featureValue(String code) {
      for (final feature in subscription.features) {
        if (feature.featureCode == code) {
          return feature.featureValue;
        }
      }
      return null;
    }

    return PassengerBroadcastContext(
      enabled: true,
      allowed: true,
      reasonCode: '',
      message: '',
      defaultRadiusKm: 8,
      maxRadiusKm: 20,
      defaultExpiryMinutes: 5,
      maxExpiryMinutes: 15,
      maxBroadcastsPerDay: int.tryParse(
        featureValue('MAX_PRICE_BROADCASTS_PER_DAY')?.toString() ?? '',
      ),
      passengerBroadcastRadiusKm: double.tryParse(
            featureValue('PASSENGER_BROADCAST_RADIUS_KM')?.toString() ?? '',
          ) ??
          8,
    );
  }

  Future<void> _applyEntryState() async {
    if (_onrideId != null) {
      return;
    }
    final draft = widget.draft;
    if (draft != null) {
      _pickupController.text = draft.pickupAddress;
      _dropoffController.text = draft.dropoffAddress;
      _pickupLatLng = LatLng(draft.pickupLat, draft.pickupLng);
      _dropoffLatLng = LatLng(draft.dropoffLat, draft.dropoffLng);
      _isScheduleMode = true;
      _scheduledDraftRideId = draft.onRideId;
      _scheduledAt = draft.scheduleAt == null
          ? null
          : DateTime.tryParse(draft.scheduleAt!);
      _statusMessage =
          'Loaded your scheduled trip. Update the time or confirm again.';
      if (_pickupLatLng != null && _dropoffLatLng != null) {
        await _moveCameraToBounds(_pickupLatLng!, _dropoffLatLng!);
        await _lookupQuotes();
      }
      return;
    }

    final shortcutType = widget.shortcutType?.trim().toLowerCase();
    if (shortcutType == 'home' || shortcutType == 'work') {
      await _quickBookToSavedPlace(shortcutType!);
    }
  }

  Future<LocationPermission> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<String> _reverseGeocode(LatLng point) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) {
        return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }

      final place = placemarks.first;
      final parts = <String>[
        if (place.street != null && place.street!.trim().isNotEmpty)
          place.street!,
        if (place.subLocality != null && place.subLocality!.trim().isNotEmpty)
          place.subLocality!,
        if (place.locality != null && place.locality!.trim().isNotEmpty)
          place.locality!,
      ];

      if (parts.isEmpty) {
        return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }

      return parts.join(', ');
    } catch (_) {
      return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }
  }

  Future<LatLng> _geocodeAddress(String input) async {
    final trimmed = input.trim();
    final parts = trimmed.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts.first.trim());
      final lng = double.tryParse(parts.last.trim());
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    final locations = await locationFromAddress(trimmed);
    if (locations.isEmpty) {
      throw const RideException('Address could not be located');
    }
    final location = locations.first;
    return LatLng(location.latitude, location.longitude);
  }

  double _distanceKm(LatLng from, LatLng to) {
    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    return meters / 1000;
  }

  double _routeDistanceKm(LatLng pickup, LatLng dropoff) {
    var total = 0.0;
    var current = pickup;
    for (final stop in _rideStops) {
      final next = LatLng(stop.latitude, stop.longitude);
      total += _distanceKm(current, next);
      current = next;
    }
    total += _distanceKm(current, dropoff);
    return total;
  }

  Future<void> _lookupQuotes() async {
    if (_pickupController.text.trim().isEmpty ||
        _dropoffController.text.trim().isEmpty) {
      _showSnack('Pickup and destination are required');
      return;
    }

    setState(() {
      _isFetchingQuotes = true;
      _acceptedRide = null;
      _isFindingDriver = false;
      _onrideId = null;
    });

    try {
      final pickup =
          _pickupLatLng ?? await _geocodeAddress(_pickupController.text);
      final dropoff =
          _dropoffLatLng ?? await _geocodeAddress(_dropoffController.text);
      final distance = _routeDistanceKm(pickup, dropoff).toStringAsFixed(2);

      final response = await ref.read(rideRepositoryProvider).getRideQuotes(
            pickupLocation: _pickupController.text.trim(),
            pickupLat: pickup.latitude,
            pickupLng: pickup.longitude,
            dropLocation: _dropoffController.text.trim(),
            dropLat: dropoff.latitude,
            dropLng: dropoff.longitude,
            distanceKm: distance,
          );
      final poolingSettings =
          await ref.read(rideRepositoryProvider).getPoolingSettings(
                pickupLat: pickup.latitude,
                pickupLng: pickup.longitude,
              );

      if (!response.isSuccess) {
        throw RideException(response.message ?? 'Unable to fetch ride options');
      }

      final available =
          response.rides.where((ride) => ride.available == 1).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _pickupLatLng = pickup;
        _dropoffLatLng = dropoff;
        _quotes = available;
        final availableModes = available
            .map((ride) => ride.serviceType.trim().isEmpty
                ? 'ride'
                : ride.serviceType.trim().toLowerCase())
            .toSet();
        if (availableModes.isNotEmpty &&
            !availableModes.contains(_selectedServiceMode)) {
          _selectedServiceMode =
              availableModes.contains('ride') ? 'ride' : availableModes.first;
        }
        _selectedRideIndex = 0;
        _poolingSettings = poolingSettings;
        if (!poolingSettings.enabled) {
          _poolingEnabled = false;
        }
        _poolingEnabled = _selectedServiceMode == 'ride' && _poolingEnabled;
        if (!_poolingEnabled) {
          _poolSeatsRequested = 1;
        }
        _statusMessage = available.isEmpty
            ? 'No rides are available for this route right now.'
            : 'Choose a vehicle and request your ride.';
      });

      await _loadRoutePolyline(pickup, dropoff);
    } catch (error) {
      _showSnack('$error');
      if (mounted) {
        setState(() {
          _quotes = const <AvailableRideItem>[];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingQuotes = false;
        });
      }
    }
  }

  Future<void> _openLocationSelection({bool focusPickup = false}) async {
    final result = await context.push<LocationSelectionResult>(
      SelectLocationPage.routePath,
      extra: LocationSelectionArgs(
        pickupAddress: _pickupController.text.trim(),
        dropoffAddress: _dropoffController.text.trim(),
        rideStops: _rideStops,
        pickupLat: _pickupLatLng?.latitude,
        pickupLng: _pickupLatLng?.longitude,
        dropoffLat: _dropoffLatLng?.latitude,
        dropoffLng: _dropoffLatLng?.longitude,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _pickupController.text = result.pickupAddress;
      _dropoffController.text = result.dropoffAddress;
      _pickupLatLng = result.pickupLat != null && result.pickupLng != null
          ? LatLng(result.pickupLat!, result.pickupLng!)
          : _pickupLatLng;
      _dropoffLatLng = result.dropoffLat != null && result.dropoffLng != null
          ? LatLng(result.dropoffLat!, result.dropoffLng!)
          : _dropoffLatLng;
      _rideStops = result.rideStops;
      _routePolylinePoints = const <LatLng>[];
      _quotes = const <AvailableRideItem>[];
      _acceptedRide = null;
      _scheduledRide = null;
      _poolSeatsRequested = 1;
      _onrideId = null;
      _scheduledDraftRideId = null;
      _selectedRideIndex = 0;
      _statusMessage = result.dropoffAddress.trim().isEmpty
          ? 'Choose your destination to see available rides.'
          : 'Route updated. Check available rides for this trip.';
    });

    if (_pickupLatLng != null && _dropoffLatLng != null) {
      await _moveCameraToBounds(_pickupLatLng!, _dropoffLatLng!);
    } else if (_pickupLatLng != null) {
      await _moveCamera(_pickupLatLng!);
    }

    if (result.dropoffAddress.trim().isNotEmpty) {
      await _lookupQuotes();
    } else if (focusPickup) {
      _pickupFocus.requestFocus();
    } else {
      _dropoffFocus.requestFocus();
    }

    await _loadSavedPlaces();
  }

  SavedPlace? _findShortcut(String type) {
    for (final place in _savedPlaces) {
      if (place.placeType.toLowerCase() == type.toLowerCase()) {
        return place;
      }
    }
    return null;
  }

  Future<void> _quickBookToSavedPlace(String type) async {
    final target = _findShortcut(type);
    if (target == null) {
      _showSnack('Save your $type location first');
      await _openLocationSelection();
      return;
    }

    if (_pickupLatLng == null || _pickupController.text.trim().isEmpty) {
      await _bootstrapLocation();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _dropoffController.text = target.displayAddress;
      _dropoffLatLng = LatLng(target.latitude, target.longitude);
      _rideStops = const <RideStop>[];
      _scheduledRide = null;
      _statusMessage = 'Checking rides to ${target.displayTitle}...';
    });

    await _lookupQuotes();
  }

  List<String> get _availableServiceModes {
    final modes = _quotes
        .map((ride) => ride.serviceType.trim().isEmpty
            ? 'ride'
            : ride.serviceType.trim().toLowerCase())
        .toSet()
        .toList()
      ..sort();
    if (modes.isEmpty) {
      return const <String>['ride'];
    }
    return modes;
  }

  List<AvailableRideItem> get _visibleQuotes {
    return _quotes.where((ride) {
      final mode = ride.serviceType.trim().isEmpty
          ? 'ride'
          : ride.serviceType.trim().toLowerCase();
      return mode == _selectedServiceMode;
    }).toList();
  }

  void _syncSelectedRideIndex() {
    final visibleQuotes = _visibleQuotes;
    if (visibleQuotes.isEmpty) {
      _selectedRideIndex = 0;
      return;
    }
    if (_selectedRideIndex >= visibleQuotes.length) {
      _selectedRideIndex = 0;
    }
  }

  Future<void> _requestRide() async {
    if (_isRequestingRide) {
      return;
    }
    final requestGeneration = ++_requestGeneration;
    final visibleQuotes = _visibleQuotes;
    if (_pickupLatLng == null ||
        _dropoffLatLng == null ||
        visibleQuotes.isEmpty) {
      _showSnack('Fetch available rides first');
      return;
    }

    if (_isScheduleMode && _scheduledAt == null) {
      final selected = await _pickScheduleTime();
      if (selected == null) {
        return;
      }
    }

    if (_selectedServiceMode == 'delivery') {
      final deliveryDetails = await _collectDeliveryDetails();
      if (deliveryDetails == null) {
        return;
      }
      _deliveryDetails = deliveryDetails;
    }

    final usePassengerBroadcast = _selectedServiceMode == 'ride' &&
        !_isScheduleMode &&
        _usePassengerPriceBroadcast;
    double? passengerOfferedPrice;
    if (usePassengerBroadcast) {
      passengerOfferedPrice = double.tryParse(
        _passengerPriceController.text.trim().replaceAll(',', ''),
      );
      if (passengerOfferedPrice == null || passengerOfferedPrice <= 0) {
        _showSnack('Enter the price you want to broadcast to drivers');
        return;
      }
    }

    final selected = visibleQuotes[_selectedRideIndex];
    final isScheduleRequest = _isScheduleMode;
    setState(() {
      _isRequestingRide = true;
      _scheduledRide = null;
      _driverOffers = const <DriverRideOffer>[];
      _statusMessage = isScheduleRequest
          ? 'Scheduling ${selected.categoryName} for ${_formatScheduledTime(_scheduledAt)}...'
          : usePassengerBroadcast
              ? 'Broadcasting your price to nearby drivers...'
              : _poolingEnabled
                  ? 'Finding a shared ride for $_poolSeatsRequested seat(s)...'
                  : 'Finding a driver for ${selected.categoryName}...';
    });

    try {
      final repository = ref.read(rideRepositoryProvider);
      final request = isScheduleRequest && _scheduledDraftRideId != null
          ? await repository.updateScheduledRide(
              onRideId: _scheduledDraftRideId!,
              pickupLocation: _pickupController.text.trim(),
              pickupLat: _pickupLatLng!.latitude,
              pickupLng: _pickupLatLng!.longitude,
              dropLocation: _dropoffController.text.trim(),
              dropLat: _dropoffLatLng!.latitude,
              dropLng: _dropoffLatLng!.longitude,
              category: selected,
              basePrice: selected.basePrice,
              poolingOptIn: _selectedServiceMode == 'ride' && _poolingEnabled,
              seatsRequested: _poolSeatsRequested,
              deliveryDetails:
                  _selectedServiceMode == 'delivery' ? _deliveryDetails : null,
              scheduledAt: _scheduledAt!,
              rideStops: _rideStops,
            )
          : await repository.requestRide(
              pickupLocation: _pickupController.text.trim(),
              pickupLat: _pickupLatLng!.latitude,
              pickupLng: _pickupLatLng!.longitude,
              dropLocation: _dropoffController.text.trim(),
              dropLat: _dropoffLatLng!.latitude,
              dropLng: _dropoffLatLng!.longitude,
              category: selected,
              basePrice: selected.basePrice,
              type: isScheduleRequest ? 'schedule' : 'now',
              poolingOptIn: _selectedServiceMode == 'ride' && _poolingEnabled,
              seatsRequested: _poolSeatsRequested,
              deliveryDetails:
                  _selectedServiceMode == 'delivery' ? _deliveryDetails : null,
              scheduledAt: isScheduleRequest ? _scheduledAt : null,
              rideStops: _rideStops,
              usePassengerPriceBroadcast: usePassengerBroadcast,
              passengerOfferedPrice: passengerOfferedPrice,
              broadcastRadiusKm:
                  _passengerBroadcastContext?.passengerBroadcastRadiusKm,
            );

      if (!request.isSuccess || request.onrideId == null) {
        throw RideException(request.message ?? 'Ride request failed');
      }

      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }

      setState(() {
        if (isScheduleRequest) {
          _scheduledRide = request;
          _acceptedRide = null;
          _isFindingDriver = false;
          _scheduledDraftRideId = request.onrideId ?? _scheduledDraftRideId;
          _onrideId = null;
          _isScheduleMode = false;
          _statusMessage =
              'Ride scheduled for ${_formatScheduledTime(_scheduledAt)}. You can still book a ride for now.';
          if (_scheduledAt != null) {
            unawaited(
              ref.read(localNotificationServiceProvider).scheduleRideReminder(
                    onRideId: request.onrideId!,
                    scheduledAt: _scheduledAt!,
                    pickupLocation: _pickupController.text.trim(),
                    dropoffLocation: _dropoffController.text.trim(),
                  ),
            );
          }
        } else {
          _offerRefreshTimer?.cancel();
          _onrideId = request.onrideId;
          _scheduledRide = null;
          _isFindingDriver = true;
          _driverOffers = const <DriverRideOffer>[];
        }
      });

      if (isScheduleRequest) {
        return;
      }

      late final ConfirmRideResponse accepted;
      try {
        accepted = await ref.read(rideRepositoryProvider).pollUntilAccepted(
              request.onrideId!,
              isCancelled: () =>
                  !mounted ||
                  requestGeneration != _requestGeneration ||
                  _onrideId != request.onrideId,
            );
      } catch (_) {
        if (!mounted ||
            requestGeneration != _requestGeneration ||
            _onrideId != request.onrideId) {
          return;
        }
        rethrow;
      }

      if (!mounted ||
          requestGeneration != _requestGeneration ||
          _onrideId != request.onrideId) {
        return;
      }

      setState(() {
        if (accepted.isAccepted) {
          _acceptedRide = accepted;
          _driverOffers = const <DriverRideOffer>[];
          _isFindingDriver = false;
          _statusMessage = 'Driver accepted your ride.';
        } else if (accepted.hasDriverOffers) {
          _acceptedRide = null;
          _driverOffers = accepted.offers;
          _isFindingDriver = false;
          _statusMessage = accepted.isPassengerPriceBroadcast
              ? 'Drivers responded to your price. Choose who should take the trip.'
              : 'Choose the driver offer that works best for you.';
        }
      });
      if (accepted.hasDriverOffers) {
        _startOfferMonitoring();
      }
      if (accepted.isAccepted &&
          _pickupLatLng != null &&
          _dropoffLatLng != null) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _moveCameraToBounds(_pickupLatLng!, _dropoffLatLng!);
      }
      if (accepted.isAccepted) {
        _startRideStatusMonitoring();
      }
    } catch (error) {
      if (!mounted || requestGeneration != _requestGeneration) {
        return;
      }
      _showSnack('$error');
      setState(() {
        _isFindingDriver = false;
        _statusMessage = 'Ride request did not complete.';
      });
    } finally {
      if (mounted && requestGeneration == _requestGeneration) {
        setState(() {
          _isRequestingRide = false;
        });
      }
    }
  }

  Future<void> _cancelRide() async {
    final onrideId = _onrideId;
    if (onrideId == null || onrideId.isEmpty) {
      return;
    }

    try {
      await ref.read(rideRepositoryProvider).cancelRide(onrideId);
      unawaited(
        ref.read(localNotificationServiceProvider).cancelRideReminder(onrideId),
      );
      if (!mounted || _onrideId != onrideId) {
        return;
      }
      setState(() {
        _rideStatusTimer?.cancel();
        _offerRefreshTimer?.cancel();
        _requestGeneration++;
        _clearBookingDraft(
            'Ride cancelled. Choose a destination for a new ride.');
      });
      _showSnack('Ride cancelled');
      if (mounted) {
        await _bootstrapLocation();
      }
    } catch (error) {
      _showSnack('$error');
    }
  }

  void _startRideStatusMonitoring() {
    _offerRefreshTimer?.cancel();
    _rideStatusTimer?.cancel();
    _activeRideStatus = 'accepted';
    unawaited(_checkRideStatus());
    _rideStatusTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_checkRideStatus()),
    );
  }

  void _startOfferMonitoring() {
    _offerRefreshTimer?.cancel();
    _offerRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshDriverOffers()),
    );
  }

  Future<void> _refreshDriverOffers() async {
    final onrideId = _onrideId;
    if (onrideId == null ||
        onrideId.isEmpty ||
        _isRefreshingOffers ||
        _acceptedRide != null) {
      return;
    }
    _isRefreshingOffers = true;
    try {
      final response =
          await ref.read(rideRepositoryProvider).getRideOffers(onrideId);
      if (!mounted || _onrideId != onrideId) {
        return;
      }
      setState(() {
        _driverOffers = response.offers;
        if (response.offers.isEmpty) {
          _offerRefreshTimer?.cancel();
          _statusMessage = 'The driver offer window has ended.';
        }
      });
    } catch (_) {
      // Keep the existing offers visible during a temporary refresh failure.
    } finally {
      _isRefreshingOffers = false;
    }
  }

  Future<void> _checkRideStatus() async {
    final onrideId = _onrideId;
    if (onrideId == null || onrideId.isEmpty || _isCheckingRideStatus) {
      return;
    }
    _isCheckingRideStatus = true;
    try {
      final rideStatus =
          await ref.read(rideRepositoryProvider).getRideStatus(onrideId);
      if (!mounted ||
          _onrideId != onrideId ||
          rideStatus.isEmpty ||
          rideStatus == _activeRideStatus) {
        return;
      }
      final completedRideId = rideStatus == 'completed' ? onrideId : null;
      setState(() {
        _activeRideStatus = rideStatus;
        if (rideStatus == 'onride') {
          _statusMessage = 'Your trip is now in progress.';
        } else if (rideStatus == 'ontheway' || rideStatus == 'accepted') {
          _statusMessage = 'Your driver is on the way to the pickup.';
        } else if (rideStatus == 'completed') {
          _rideStatusTimer?.cancel();
          _clearBookingDraft('Choose your destination to start a new ride.');
        } else if (rideStatus == 'cancelled' ||
            rideStatus == 'ridenotaccepted') {
          _rideStatusTimer?.cancel();
          _acceptedRide = null;
          _onrideId = null;
          _routePolylinePoints = const <LatLng>[];
          _statusMessage = 'This ride has ended.';
        }
      });
      if (completedRideId != null && mounted) {
        await context.push(
          WriteReviewPage.routePath,
          extra: ReviewArgs(
            onRideId: completedRideId,
            from: 'completed',
          ),
        );
        if (mounted) {
          await _bootstrapLocation();
        }
      }
    } catch (_) {
      // A temporary status request failure must not interrupt an active trip.
    } finally {
      _isCheckingRideStatus = false;
    }
  }

  void _clearBookingDraft(String message) {
    _pickupController.clear();
    _dropoffController.clear();
    _passengerPriceController.clear();
    _pickupLatLng = null;
    _dropoffLatLng = null;
    _routePolylinePoints = const <LatLng>[];
    _rideStops = const <RideStop>[];
    _quotes = const <AvailableRideItem>[];
    _selectedRideIndex = 0;
    _selectedServiceMode = 'ride';
    _poolingEnabled = false;
    _poolSeatsRequested = 1;
    _deliveryDetails = const DeliveryDetails(
      parcelType: '',
      parcelSize: '',
      recipientName: '',
      recipientPhone: '',
      senderNote: '',
      handoffCode: '',
      proofRequired: false,
    );
    _isScheduleMode = false;
    _scheduledAt = null;
    _scheduledRide = null;
    _scheduledDraftRideId = null;
    _acceptedRide = null;
    _driverOffers = const <DriverRideOffer>[];
    _isFindingDriver = false;
    _isAcceptingOffer = false;
    _isRequestingRide = false;
    _isFetchingQuotes = false;
    _isRefreshingOffers = false;
    _onrideId = null;
    _activeRideStatus = '';
    _statusMessage = message;
  }

  Future<void> _acceptDriverOffer(DriverRideOffer offer) async {
    final onrideId = _onrideId;
    if (onrideId == null || onrideId.isEmpty || _isAcceptingOffer) {
      return;
    }

    try {
      setState(() {
        _isAcceptingOffer = true;
        _statusMessage =
            'Confirming ${offer.vehicleNumber} at ${offer.currency} ${offer.offeredPrice.toStringAsFixed(0)}...';
      });
      final accepted = await ref.read(rideRepositoryProvider).acceptRideOffer(
            onrideId: onrideId,
            offerId: offer.id,
          );
      if (!mounted || _onrideId != onrideId) {
        return;
      }
      setState(() {
        _offerRefreshTimer?.cancel();
        _acceptedRide = accepted;
        _driverOffers = const <DriverRideOffer>[];
        _isFindingDriver = false;
        _statusMessage = 'Driver accepted your ride.';
      });
      _startRideStatusMonitoring();
      if (_pickupLatLng != null && _dropoffLatLng != null) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _moveCameraToBounds(_pickupLatLng!, _dropoffLatLng!);
      }
    } catch (error) {
      _showSnack('$error');
      if (!mounted || _onrideId != onrideId) {
        return;
      }
      setState(() {
        _statusMessage = 'Unable to confirm this driver offer yet.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAcceptingOffer = false;
        });
      }
    }
  }

  Future<void> _cancelScheduledRide() async {
    final onrideId = _scheduledDraftRideId;
    if (onrideId == null || onrideId.isEmpty) {
      return;
    }

    try {
      await ref.read(rideRepositoryProvider).cancelRide(onrideId);
      unawaited(
        ref.read(localNotificationServiceProvider).cancelRideReminder(onrideId),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _requestGeneration++;
        _clearBookingDraft(
            'Scheduled ride cancelled. Choose a destination for a new ride.');
      });
      _showSnack('Scheduled ride cancelled');
      if (mounted) {
        await _bootstrapLocation();
      }
    } catch (error) {
      _showSnack('$error');
    }
  }

  Future<void> _moveCamera(LatLng target) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 16),
      ),
    );
  }

  Future<void> _moveCameraToBounds(LatLng pickup, LatLng dropoff) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    final points = _routePolylinePoints.isNotEmpty
        ? _routePolylinePoints
        : <LatLng>[
            pickup,
            ..._rideStops.map((stop) => LatLng(stop.latitude, stop.longitude)),
            dropoff,
          ];
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Future<void> _loadRoutePolyline(LatLng pickup, LatLng dropoff) async {
    var points = <LatLng>[];
    if (mounted) {
      setState(() {
        _routePolylinePoints = const <LatLng>[];
      });
    }
    try {
      final encoded = await ref.read(rideRepositoryProvider).getRoutePolyline(
            pickupLat: pickup.latitude,
            pickupLng: pickup.longitude,
            dropLat: dropoff.latitude,
            dropLng: dropoff.longitude,
            rideStops: _rideStops,
          );
      final decoded = _decodePolyline(encoded);
      if (decoded.length >= 2) {
        points = decoded;
      }
    } catch (error) {
      _showSnack('$error');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _routePolylinePoints = points;
    });
    await _moveCameraToBounds(pickup, dropoff);
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  Set<Polyline> _buildPolylines() {
    if (_routePolylinePoints.length < 2) {
      return const <Polyline>{};
    }
    return {
      Polyline(
        polylineId: const PolylineId('active-route'),
        points: _routePolylinePoints,
        color: const Color(0xFFF04E29),
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_pickupLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );
    }
    if (_dropoffLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLatLng!,
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }
    for (var index = 0; index < _rideStops.length; index++) {
      final stop = _rideStops[index];
      markers.add(
        Marker(
          markerId: MarkerId('stop-$index'),
          position: LatLng(stop.latitude, stop.longitude),
          infoWindow: InfoWindow(
            title: 'Stop ${index + 1}',
            snippet: stop.location,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }
    return markers;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<DateTime?> _pickScheduleTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(minutes: 20));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 6)),
    );

    if (pickedDate == null || !mounted) {
      return null;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null) {
      return null;
    }

    final scheduled = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (scheduled.isBefore(now.add(const Duration(minutes: 15)))) {
      _showSnack('Schedule time has to be 15 mins after current time');
      return null;
    }

    if (!mounted) {
      return scheduled;
    }

    setState(() {
      _scheduledAt = scheduled;
      _scheduledRide = null;
      _statusMessage =
          'Ride will be scheduled for ${_formatScheduledTime(scheduled)}.';
    });
    return scheduled;
  }

  String _formatScheduledTime(DateTime? value) {
    if (value == null) {
      return 'later';
    }
    return DateFormat('dd MMM, hh:mm a').format(value);
  }

  Future<void> _openMaskedCall() async {
    final ride = _acceptedRide;
    final onrideId = _onrideId;
    if (ride == null ||
        onrideId == null ||
        (ride.driverUserId?.trim().isEmpty ?? true)) {
      _showSnack('Driver contact is not available yet');
      return;
    }

    try {
      final roomId = 'ride_$onrideId';
      if (!mounted) {
        return;
      }
      await context.push(
        ActiveCallPage.routePath,
        extra: ActiveCallArgs(
          roomId: roomId,
          partnerId: ride.driverUserId!.trim(),
          partnerName: ride.driverName ?? 'Driver',
          partnerImageUrl: ride.driverImage,
          isCaller: true,
          onRideId: onrideId,
        ),
      );
    } catch (error) {
      _showSnack('$error');
    }
  }

  Future<void> _openTripChat() async {
    final onrideId = _onrideId;
    final ride = _acceptedRide;
    if (onrideId == null ||
        onrideId.isEmpty ||
        ride == null ||
        (ride.driverUserId?.trim().isEmpty ?? true)) {
      _showSnack('Trip chat is unavailable right now');
      return;
    }
    await context.push(
      RideChatPage.routePath,
      extra: RideChatArgs(
        onRideId: onrideId,
        driverId: ride.driverUserId!.trim(),
        driverName: ride.driverName ?? 'Driver',
      ),
    );
  }

  Future<void> _modifyScheduledTrip() async {
    setState(() {
      _scheduledRide = null;
      _isScheduleMode = true;
      _statusMessage = 'Adjust the pickup time, then confirm again.';
    });
    await _pickScheduleTime();
  }

  Future<DeliveryDetails?> _collectDeliveryDetails() async {
    final details = await showModalBottomSheet<DeliveryDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeliveryDetailsSheet(initial: _deliveryDetails),
    );
    if (details == null) {
      return null;
    }
    if (details.recipientName.trim().isEmpty ||
        details.recipientPhone.trim().isEmpty ||
        details.parcelType.trim().isEmpty) {
      _showSnack('Parcel type, recipient name, and phone are required');
      return null;
    }
    setState(() {
      _deliveryDetails = details;
    });
    return details;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionStorageProvider);
    final fullName = session.fullName ?? 'Shilota Rider';
    final email = session.email ?? '';
    final visibleQuotes = _visibleQuotes;
    final initialTarget = _pickupLatLng ??
        LatLng(
          _currentPosition?.latitude ?? -6.7924,
          _currentPosition?.longitude ?? 39.2083,
        );

    return Scaffold(
      drawer: AppDrawer(
        fullName: fullName,
        email: email,
      ),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(left: 12),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFCE7E1),
                child: BrandLogo(size: 18),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hello,',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B7D76),
                      ),
                    ),
                    Text(
                      fullName.split(' ').first,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF231814),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => context.push(NotificationsPage.routePath),
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: initialTarget, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            padding: EdgeInsets.only(
              top: _acceptedRide != null ? 86 : 0,
              bottom: _acceptedRide != null
                  ? MediaQuery.sizeOf(context).height * 0.34
                  : 0,
            ),
            onMapCreated: (controller) async {
              _mapController = controller;
              if (_pickupLatLng != null) {
                await _moveCamera(_pickupLatLng!);
              }
            },
          ),
          if (_acceptedRide == null && !_isFindingDriver)
            Positioned(
              top: 104,
              left: 16,
              right: 16,
              child: _SearchCard(
                pickupController: _pickupController,
                dropoffController: _dropoffController,
                pickupFocus: _pickupFocus,
                dropoffFocus: _dropoffFocus,
                homePlace: _findShortcut('home'),
                workPlace: _findShortcut('work'),
                onPickupTap: () => _openLocationSelection(focusPickup: true),
                onDropoffTap: _openLocationSelection,
                onFavoritesTap: _openLocationSelection,
                onHomeShortcutTap: () => _quickBookToSavedPlace('home'),
                onWorkShortcutTap: () => _quickBookToSavedPlace('work'),
                onLocateTap: _bootstrapLocation,
              ),
            ),
          Positioned(
            right: 20,
            bottom: MediaQuery.sizeOf(context).height *
                    (_acceptedRide != null ? 0.38 : 0.66) +
                12,
            child: FloatingActionButton(
              heroTag: 'pickup-location',
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFF04E29),
              onPressed: _bootstrapLocation,
              tooltip: 'Use my location',
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              statusMessage: _statusMessage,
              isInitializing: _isInitializing,
              isFetchingQuotes: _isFetchingQuotes,
              isFindingDriver: _isFindingDriver,
              pickupLocation: _pickupController.text.trim(),
              dropoffLocation: _dropoffController.text.trim(),
              rideStops: _rideStops,
              quotes: visibleQuotes,
              selectedRideIndex: _selectedRideIndex,
              onRideSelected: (index) {
                setState(() {
                  _selectedRideIndex = index;
                });
              },
              onHistoryTap: () => context.push(RideHistoryPage.routePath),
              onRequestRide: visibleQuotes.isEmpty || _isRequestingRide
                  ? null
                  : _requestRide,
              isScheduleMode: _isScheduleMode,
              scheduledAt: _scheduledAt,
              scheduledRide: _scheduledRide,
              selectedServiceMode: _selectedServiceMode,
              availableServiceModes: _availableServiceModes,
              onServiceModeChanged: (mode) {
                setState(() {
                  _selectedServiceMode = mode;
                  if (mode != 'ride') {
                    _poolingEnabled = false;
                  }
                  _syncSelectedRideIndex();
                });
              },
              poolingEnabled: _poolingEnabled,
              onPoolingChanged: (enabled) {
                setState(() {
                  _poolingEnabled =
                      (_poolingSettings?.enabled ?? true) && enabled;
                  if (!_poolingEnabled) {
                    _poolSeatsRequested = 1;
                  }
                });
              },
              poolSeatsRequested: _poolSeatsRequested,
              onPoolSeatsChanged: (seats) {
                setState(() {
                  _poolSeatsRequested = seats;
                });
              },
              onScheduleModeChanged: (enabled) {
                setState(() {
                  _isScheduleMode = enabled;
                  _scheduledRide = null;
                  _statusMessage = enabled
                      ? (_scheduledAt == null
                          ? 'Choose when you want to be picked up.'
                          : 'Ride will be scheduled for ${_formatScheduledTime(_scheduledAt)}.')
                      : 'Choose a vehicle and request your ride.';
                });
              },
              onPickScheduleTime: _pickScheduleTime,
              isRequestingRide: _isRequestingRide,
              driverOffers: _driverOffers,
              onAcceptDriverOffer: _acceptDriverOffer,
              isAcceptingOffer: _isAcceptingOffer,
              acceptedRide: _acceptedRide,
              activeRideStatus: _activeRideStatus,
              onCancelRide: _onrideId != null
                  ? _cancelRide
                  : (_scheduledDraftRideId == null
                      ? null
                      : _cancelScheduledRide),
              onMaskedCall: _acceptedRide == null ? null : _openMaskedCall,
              onTripChat: _acceptedRide == null ? null : _openTripChat,
              onSosTap: _onrideId == null
                  ? null
                  : () => context.push(SosPage.routePath, extra: _onrideId!),
              onModifyScheduledTrip: _modifyScheduledTrip,
              deliveryDetails: _deliveryDetails,
              poolingSettings: _poolingSettings,
              passengerBroadcastContext: _passengerBroadcastContext,
              usePassengerPriceBroadcast: _usePassengerPriceBroadcast,
              onPassengerPriceBroadcastChanged: (enabled) {
                setState(() {
                  _usePassengerPriceBroadcast = enabled;
                  if (!enabled) {
                    _passengerPriceController.clear();
                  }
                });
              },
              passengerPriceController: _passengerPriceController,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.pickupController,
    required this.dropoffController,
    required this.pickupFocus,
    required this.dropoffFocus,
    required this.homePlace,
    required this.workPlace,
    required this.onPickupTap,
    required this.onDropoffTap,
    required this.onFavoritesTap,
    required this.onHomeShortcutTap,
    required this.onWorkShortcutTap,
    required this.onLocateTap,
  });

  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final FocusNode pickupFocus;
  final FocusNode dropoffFocus;
  final SavedPlace? homePlace;
  final SavedPlace? workPlace;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;
  final VoidCallback onFavoritesTap;
  final VoidCallback onHomeShortcutTap;
  final VoidCallback onWorkShortcutTap;
  final VoidCallback onLocateTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where to?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF231814),
              ),
            ),
            const SizedBox(height: 8),
            _HomeRouteField(
              icon: Icons.search_rounded,
              hint: 'Enter destination...',
              controller: dropoffController,
              focusNode: dropoffFocus,
              onTap: onDropoffTap,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.home_rounded,
                    title: 'Home',
                    subtitle: homePlace?.displayAddress ?? 'Set your address',
                    onTap: onHomeShortcutTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.work_outline_rounded,
                    title: 'Work',
                    subtitle: workPlace?.displayAddress ?? 'Set your address',
                    onTap: onWorkShortcutTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onLocateTap,
                    icon: const Icon(Icons.gps_fixed_rounded),
                    label: const Text('Current Pickup'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onFavoritesTap,
                    icon: const Icon(Icons.bookmark_border_rounded),
                    label: const Text('All Saved Places'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.statusMessage,
    required this.isInitializing,
    required this.isFetchingQuotes,
    required this.isFindingDriver,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.rideStops,
    required this.quotes,
    required this.selectedRideIndex,
    required this.onRideSelected,
    required this.onHistoryTap,
    required this.onRequestRide,
    required this.isScheduleMode,
    required this.scheduledAt,
    required this.scheduledRide,
    required this.selectedServiceMode,
    required this.availableServiceModes,
    required this.onServiceModeChanged,
    required this.poolingEnabled,
    required this.onPoolingChanged,
    required this.poolSeatsRequested,
    required this.onPoolSeatsChanged,
    required this.onScheduleModeChanged,
    required this.onPickScheduleTime,
    required this.isRequestingRide,
    required this.driverOffers,
    required this.onAcceptDriverOffer,
    required this.isAcceptingOffer,
    required this.acceptedRide,
    required this.activeRideStatus,
    required this.onCancelRide,
    required this.onMaskedCall,
    required this.onTripChat,
    required this.onSosTap,
    required this.onModifyScheduledTrip,
    required this.deliveryDetails,
    required this.poolingSettings,
    required this.passengerBroadcastContext,
    required this.usePassengerPriceBroadcast,
    required this.onPassengerPriceBroadcastChanged,
    required this.passengerPriceController,
  });

  final String statusMessage;
  final bool isInitializing;
  final bool isFetchingQuotes;
  final bool isFindingDriver;
  final String pickupLocation;
  final String dropoffLocation;
  final List<RideStop> rideStops;
  final List<AvailableRideItem> quotes;
  final int selectedRideIndex;
  final ValueChanged<int> onRideSelected;
  final VoidCallback onHistoryTap;
  final VoidCallback? onRequestRide;
  final bool isScheduleMode;
  final DateTime? scheduledAt;
  final RequestRideResponse? scheduledRide;
  final String selectedServiceMode;
  final List<String> availableServiceModes;
  final ValueChanged<String> onServiceModeChanged;
  final bool poolingEnabled;
  final ValueChanged<bool> onPoolingChanged;
  final int poolSeatsRequested;
  final ValueChanged<int> onPoolSeatsChanged;
  final ValueChanged<bool> onScheduleModeChanged;
  final Future<DateTime?> Function() onPickScheduleTime;
  final bool isRequestingRide;
  final List<DriverRideOffer> driverOffers;
  final Future<void> Function(DriverRideOffer offer) onAcceptDriverOffer;
  final bool isAcceptingOffer;
  final ConfirmRideResponse? acceptedRide;
  final String activeRideStatus;
  final VoidCallback? onCancelRide;
  final VoidCallback? onMaskedCall;
  final VoidCallback? onTripChat;
  final VoidCallback? onSosTap;
  final VoidCallback onModifyScheduledTrip;
  final DeliveryDetails deliveryDetails;
  final PoolingSettings? poolingSettings;
  final PassengerBroadcastContext? passengerBroadcastContext;
  final bool usePassengerPriceBroadcast;
  final ValueChanged<bool> onPassengerPriceBroadcastChanged;
  final TextEditingController passengerPriceController;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final normalizedStatus = statusMessage.toLowerCase();
    final showErrorStatus = normalizedStatus.contains('did not') ||
        normalizedStatus.contains('failed') ||
        normalizedStatus.contains('error') ||
        normalizedStatus.contains('unable');
    final panelHeightFactor = acceptedRide != null ? 0.38 : 0.66;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * panelHeightFactor),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5DAD5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (showErrorStatus) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFFD84322),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            statusMessage,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: Color(0xFF7A3024),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                if (rideStops.isNotEmpty &&
                    (isFindingDriver || acceptedRide != null)) ...[
                  _RouteStopsPreview(stops: rideStops),
                  const SizedBox(height: 8),
                ],
                if (isInitializing) ...[
                  const SizedBox(height: 10),
                  const Center(child: CircularProgressIndicator()),
                ] else if (isFetchingQuotes) ...[
                  const SizedBox(height: 18),
                  const _LoadingStageCard(
                    title: 'Loading ride categories...',
                    subtitle: 'Fetching available vehicles for this route.',
                  ),
                ] else if (isFindingDriver) ...[
                  const SizedBox(height: 18),
                  _FindingDriverCard(
                    pickupLocation: pickupLocation,
                    dropoffLocation: dropoffLocation,
                    poolingEnabled: poolingEnabled,
                    poolSeatsRequested: poolSeatsRequested,
                    onCancelRide: onCancelRide,
                  ),
                ] else if (acceptedRide != null) ...[
                  const SizedBox(height: 4),
                  _AcceptedRideCard(
                    ride: acceptedRide!,
                    rideStatus: activeRideStatus,
                    onCancelRide: onCancelRide,
                    onMaskedCall: onMaskedCall,
                    onTripChat: onTripChat,
                    onSosTap: onSosTap,
                  ),
                ] else if (driverOffers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _DriverOfferSelectionCard(
                    offers: driverOffers,
                    isAcceptingOffer: isAcceptingOffer,
                    onAcceptOffer: onAcceptDriverOffer,
                  ),
                  OutlinedButton(
                    onPressed: onCancelRide,
                    child: const Text('Cancel request'),
                  ),
                ] else if (isScheduleMode && scheduledRide != null) ...[
                  const SizedBox(height: 18),
                  _ScheduledRideCard(
                    scheduledAt: scheduledAt,
                    onOpenBookings: onHistoryTap,
                    onCancelRide: onCancelRide,
                    onModifySchedule: onModifyScheduledTrip,
                  ),
                ] else if (quotes.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (availableServiceModes.length > 1)
                          ...availableServiceModes.map((mode) {
                            final selected = mode == selectedServiceMode;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                label: Text(
                                  mode == 'delivery' ? 'Delivery' : 'Ride',
                                ),
                                selected: selected,
                                onSelected: (_) => onServiceModeChanged(mode),
                              ),
                            );
                          }),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            avatar: Icon(
                              isScheduleMode
                                  ? Icons.schedule_rounded
                                  : Icons.flash_on_rounded,
                              size: 15,
                            ),
                            label: Text(isScheduleMode ? 'Scheduled' : 'Now'),
                            selected: isScheduleMode,
                            onSelected: (selected) {
                              onScheduleModeChanged(selected);
                            },
                          ),
                        ),
                        if (selectedServiceMode == 'ride')
                          ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            avatar: const Icon(
                              Icons.people_outline_rounded,
                              size: 15,
                            ),
                            label: Text(poolingSettings == null
                                ? 'Pool'
                                : 'Pool · save ${poolingSettings!.discountPercent}%'),
                            selected: poolingEnabled,
                            onSelected: poolingSettings?.enabled == false
                                ? null
                                : onPoolingChanged,
                          ),
                      ],
                    ),
                  ),
                  if (selectedServiceMode == 'ride' && poolingEnabled) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F0),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF4D6CD)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Seats to reserve',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Reserve up to ${poolingSettings?.maxPassengers ?? 4} seats in the pooled ride.',
                                  style:
                                      const TextStyle(color: Color(0xFF7F756F)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: poolSeatsRequested > 1
                                ? () =>
                                    onPoolSeatsChanged(poolSeatsRequested - 1)
                                : null,
                            tooltip: 'Remove seat',
                            icon:
                                const Icon(Icons.remove_circle_outline_rounded),
                          ),
                          Text(
                            '$poolSeatsRequested',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            onPressed: poolSeatsRequested <
                                    (poolingSettings?.maxPassengers ?? 4)
                                ? () =>
                                    onPoolSeatsChanged(poolSeatsRequested + 1)
                                : null,
                            tooltip: 'Add seat',
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (selectedServiceMode == 'delivery') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5F3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery details',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            deliveryDetails.isEmpty
                                ? 'Add parcel, recipient, and handoff details before requesting.'
                                : '${deliveryDetails.parcelType} for ${deliveryDetails.recipientName} • ${deliveryDetails.recipientPhone}',
                            style: const TextStyle(color: Color(0xFF7F756F)),
                          ),
                          if (!deliveryDetails.isEmpty &&
                              deliveryDetails.senderNote.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              deliveryDetails.senderNote,
                              style: const TextStyle(color: Color(0xFF7F756F)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (isScheduleMode) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onPickScheduleTime,
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F0),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF4D6CD)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFFCE7E1),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: Color(0xFFF04E29),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pickup time',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    scheduledAt == null
                                        ? 'Select date and time'
                                        : DateFormat('dd MMM, hh:mm a')
                                            .format(scheduledAt!),
                                    style: const TextStyle(
                                      color: Color(0xFF7F756F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 230,
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      primary: false,
                      itemCount: quotes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final ride = quotes[index];
                        final isSelected = index == selectedRideIndex;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onRideSelected(index),
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF5F0)
                                    : const Color(0xFFF8F5F3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFF04E29)
                                      : Colors.transparent,
                                  width: 1.4,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _RideCategoryAvatar(
                                        imageUrl: ride.categoryImage,
                                        label: ride.categoryName,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ride.categoryName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              ride.reachPickup.isEmpty
                                                  ? 'Affordable, everyday rides'
                                                  : 'Pickup in ${ride.reachPickup}',
                                              style: const TextStyle(
                                                color: Color(0xFF7F756F),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        usePassengerPriceBroadcast && isSelected
                                            ? 'Set your price'
                                            : 'Driver offers',
                                        style: const TextStyle(
                                          color: Color(0xFF7F756F),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isSelected &&
                                      selectedServiceMode == 'ride' &&
                                      usePassengerPriceBroadcast &&
                                      (passengerBroadcastContext?.allowed ??
                                          false)) ...[
                                    const Divider(height: 10),
                                    _InlinePreferredPriceEditor(
                                      controller: passengerPriceController,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFFCE7E1),
                          child: Icon(
                            Icons.payments_outlined,
                            color: Color(0xFFF04E29),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cash payment selected for this ride.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onRequestRide,
                      child: isRequestingRide
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isScheduleMode
                              ? 'Schedule ${quotes[selectedRideIndex].categoryName}'
                              : poolingEnabled
                                  ? 'Confirm ${quotes[selectedRideIndex].categoryName} x$poolSeatsRequested • Save ${poolingSettings?.discountPercent ?? 0}%'
                                  : 'Confirm ${quotes[selectedRideIndex].categoryName}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptedRideCard extends StatelessWidget {
  const _AcceptedRideCard({
    required this.ride,
    required this.rideStatus,
    required this.onCancelRide,
    required this.onMaskedCall,
    required this.onTripChat,
    required this.onSosTap,
  });

  final ConfirmRideResponse ride;
  final String rideStatus;
  final VoidCallback? onCancelRide;
  final VoidCallback? onMaskedCall;
  final VoidCallback? onTripChat;
  final VoidCallback? onSosTap;

  @override
  Widget build(BuildContext context) {
    final tripStarted = rideStatus == 'onride';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D6CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 21,
                backgroundColor: Color(0xFFFCE7E1),
                child: Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: Color(0xFFF04E29),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tripStarted
                          ? 'Trip in progress'
                          : (ride.driverName ?? 'Driver assigned'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF231814),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        '${ride.driverVehicle ?? ''} ${ride.driverVehicleNo ?? ''}'
                            .trim(),
                        '★ ${ride.driverRating ?? '-'}',
                      ].where((value) => value.isNotEmpty).join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7F756F),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!tripStarted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'OTP ${ride.onrideOtp ?? '-'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (ride.poolingOptIn) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Shared ride reserved for ${ride.seatsRequested} seat(s). Group size: ${ride.poolGroupSize}. Status: ${ride.poolStatus ?? 'pool_requested'}${ride.poolDiscountPercent > 0 ? ' • ${ride.poolDiscountPercent}% savings applied' : ''}.',
                style: const TextStyle(
                  color: Color(0xFF7F756F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (ride.deliveryDetails != null &&
              !ride.deliveryDetails!.isEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5F3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery handoff',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ride.deliveryDetails!.parcelType} for ${ride.deliveryDetails!.recipientName}',
                    style: const TextStyle(color: Color(0xFF7F756F)),
                  ),
                  if (ride.deliveryDetails!.senderNote.trim().isNotEmpty)
                    Text(
                      ride.deliveryDetails!.senderNote,
                      style: const TextStyle(color: Color(0xFF7F756F)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactRideAction(
                  onPressed: onMaskedCall,
                  icon: Icons.call_outlined,
                  label: 'Call',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactRideAction(
                  onPressed: onTripChat,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactRideAction(
                  onPressed: onSosTap,
                  icon: Icons.sos_rounded,
                  label: 'Emergency Alert',
                  destructive: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactRideAction(
                  onPressed: onCancelRide,
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  destructive: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactRideAction extends StatelessWidget {
  const _CompactRideAction({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFD84322) : const Color(0xFF493D38);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
            color: destructive
                ? const Color(0xFFF0B8AA)
                : const Color(0xFFE4D9D4)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DriverOfferSelectionCard extends StatelessWidget {
  const _DriverOfferSelectionCard({
    required this.offers,
    required this.isAcceptingOffer,
    required this.onAcceptOffer,
  });

  final List<DriverRideOffer> offers;
  final bool isAcceptingOffer;
  final Future<void> Function(DriverRideOffer offer) onAcceptOffer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF3D6CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose an offer',
            style: TextStyle(
              color: Color(0xFF231814),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Offers are sorted from lowest to highest. Driver details appear after you choose.',
            style: TextStyle(color: Color(0xFF7F756F)),
          ),
          const SizedBox(height: 14),
          ...offers.map(
            (offer) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6F2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.vehicleNumber.isEmpty
                                    ? 'Driver nearby'
                                    : offer.vehicleNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                offer.offerType == 'ACCEPT_PASSENGER_PRICE'
                                    ? 'Accepted your price'
                                    : 'Driver offer',
                                style: const TextStyle(
                                  color: Color(0xFFF04E29),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${offer.currency} ${offer.offeredPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Color(0xFFF04E29),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (offer.estimatedArrivalMinutes != null ||
                        (offer.message?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (offer.estimatedArrivalMinutes != null)
                            Text(
                              'ETA ${offer.estimatedArrivalMinutes} min',
                              style: const TextStyle(
                                color: Color(0xFF7F756F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (offer.estimatedArrivalMinutes != null &&
                              (offer.message?.isNotEmpty ?? false))
                            const SizedBox(width: 10),
                          if (offer.message?.isNotEmpty ?? false)
                            Expanded(
                              child: Text(
                                offer.message!,
                                style: const TextStyle(
                                  color: Color(0xFF7F756F),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isAcceptingOffer
                            ? null
                            : () => onAcceptOffer(offer),
                        child: isAcceptingOffer
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Choose this offer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlinePreferredPriceEditor extends StatelessWidget {
  const _InlinePreferredPriceEditor({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    const adjustmentStep = 500.0;

    void adjustPrice(double delta) {
      final current = double.tryParse(
            controller.text.replaceAll(',', '').trim(),
          ) ??
          0;
      final adjusted = (current + delta).clamp(0, double.infinity);
      controller.text = adjusted.toStringAsFixed(0);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Your price',
            maxLines: 1,
            style: TextStyle(
              color: Color(0xFF231814),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final current = double.tryParse(
                  value.text.replaceAll(',', '').trim(),
                ) ??
                0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: const EdgeInsets.all(4),
                  onPressed:
                      current <= 0 ? null : () => adjustPrice(-adjustmentStep),
                  tooltip: 'Reduce price',
                  icon: const Icon(Icons.remove_rounded, size: 16),
                ),
                SizedBox(
                  width: 82,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: 'TSh ',
                      hintText: 'Price',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => adjustPrice(adjustmentStep),
                  tooltip: 'Increase price',
                  icon: const Icon(Icons.add_rounded, size: 16),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DeliveryDetailsSheet extends StatefulWidget {
  const _DeliveryDetailsSheet({
    required this.initial,
  });

  final DeliveryDetails initial;

  @override
  State<_DeliveryDetailsSheet> createState() => _DeliveryDetailsSheetState();
}

class _DeliveryDetailsSheetState extends State<_DeliveryDetailsSheet> {
  late final TextEditingController _parcelTypeController;
  late final TextEditingController _parcelSizeController;
  late final TextEditingController _recipientNameController;
  late final TextEditingController _recipientPhoneController;
  late final TextEditingController _senderNoteController;
  late final TextEditingController _handoffCodeController;
  late bool _proofRequired;

  @override
  void initState() {
    super.initState();
    _parcelTypeController =
        TextEditingController(text: widget.initial.parcelType);
    _parcelSizeController =
        TextEditingController(text: widget.initial.parcelSize);
    _recipientNameController =
        TextEditingController(text: widget.initial.recipientName);
    _recipientPhoneController =
        TextEditingController(text: widget.initial.recipientPhone);
    _senderNoteController =
        TextEditingController(text: widget.initial.senderNote);
    _handoffCodeController =
        TextEditingController(text: widget.initial.handoffCode);
    _proofRequired = widget.initial.proofRequired;
  }

  @override
  void dispose() {
    _parcelTypeController.dispose();
    _parcelSizeController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _senderNoteController.dispose();
    _handoffCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery details',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _parcelTypeController,
                    decoration: const InputDecoration(labelText: 'Parcel type'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _parcelSizeController,
                    decoration: const InputDecoration(labelText: 'Parcel size'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _recipientNameController,
                    decoration:
                        const InputDecoration(labelText: 'Recipient name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _recipientPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Recipient phone'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _handoffCodeController,
                    decoration:
                        const InputDecoration(labelText: 'Handoff code'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _senderNoteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Delivery instructions',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _proofRequired,
                    onChanged: (value) {
                      setState(() {
                        _proofRequired = value;
                      });
                    },
                    title: const Text('Require proof of delivery'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          DeliveryDetails(
                            parcelType: _parcelTypeController.text.trim(),
                            parcelSize: _parcelSizeController.text.trim(),
                            recipientName: _recipientNameController.text.trim(),
                            recipientPhone:
                                _recipientPhoneController.text.trim(),
                            senderNote: _senderNoteController.text.trim(),
                            handoffCode: _handoffCodeController.text.trim(),
                            proofRequired: _proofRequired,
                          ),
                        );
                      },
                      child: const Text('Save delivery details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingStageCard extends StatelessWidget {
  const _LoadingStageCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _StageText(
              title: title,
              subtitle: subtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStopsPreview extends StatelessWidget {
  const _RouteStopsPreview({
    required this.stops,
  });

  final List<RideStop> stops;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip stops',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF231814),
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < stops.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFFFE8E1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF04E29),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stops[index].location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF7F756F)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduledRideCard extends StatelessWidget {
  const _ScheduledRideCard({
    required this.scheduledAt,
    required this.onOpenBookings,
    required this.onCancelRide,
    required this.onModifySchedule,
  });

  final DateTime? scheduledAt;
  final VoidCallback onOpenBookings;
  final VoidCallback? onCancelRide;
  final VoidCallback onModifySchedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF3D6CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ride scheduled',
            style: TextStyle(
              color: Color(0xFF231814),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            scheduledAt == null
                ? 'Your booking has been saved.'
                : 'Pickup planned for ${DateFormat('dd MMM, hh:mm a').format(scheduledAt!)}.',
            style: const TextStyle(
              color: Color(0xFF7F756F),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onModifySchedule,
                  child: const Text('Modify Time'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancelRide,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF04E29),
                    side: const BorderSide(color: Color(0xFFF04E29)),
                  ),
                  child: const Text('Cancel Ride'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onOpenBookings,
                  child: const Text('Open Bookings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FindingDriverCard extends StatelessWidget {
  const _FindingDriverCard({
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.poolingEnabled,
    required this.poolSeatsRequested,
    required this.onCancelRide,
  });

  final String pickupLocation;
  final String dropoffLocation;
  final bool poolingEnabled;
  final int poolSeatsRequested;
  final VoidCallback? onCancelRide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1D7CF)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFE3DA), Color(0xFFF04E29)],
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Finding your driver...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            poolingEnabled
                ? 'We are matching you with a pooled ride for $poolSeatsRequested seat(s).'
                : 'We are matching you with the nearest available driver.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7F756F)),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5F3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _RouteStageLine(
                  color: const Color(0xFF59C36A),
                  title:
                      pickupLocation.isEmpty ? 'Pickup Point' : pickupLocation,
                ),
                const SizedBox(height: 12),
                _RouteStageLine(
                  color: const Color(0xFFC74732),
                  title: dropoffLocation.isEmpty
                      ? 'Drop-off Destination'
                      : dropoffLocation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCancelRide,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF04E29),
                side: const BorderSide(color: Color(0xFFF04E29)),
              ),
              child: const Text('Cancel Request'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageText extends StatelessWidget {
  const _StageText({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF7F756F)),
        ),
      ],
    );
  }
}

class _RouteStageLine extends StatelessWidget {
  const _RouteStageLine({
    required this.color,
    required this.title,
  });

  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _RideCategoryAvatar extends StatelessWidget {
  const _RideCategoryAvatar({
    required this.imageUrl,
    required this.label,
  });

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveImageUrl(imageUrl);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEE8),
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved == null
          ? const Icon(
              Icons.local_taxi_rounded,
              color: Color(0xFFF04E29),
            )
          : Image.network(
              resolved,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_taxi_rounded,
                color: Color(0xFFF04E29),
              ),
            ),
    );
  }
}

String? _resolveImageUrl(String imageUrl) {
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return '${AppConfig.baseUrl}${trimmed.startsWith('/') ? trimmed.substring(1) : trimmed}';
}

class _HomeRouteField extends StatelessWidget {
  const _HomeRouteField({
    required this.icon,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.onTap,
  });

  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8F5F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFF04E29)),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFAA5B4B)),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5F3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFF04E29)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7F756F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
