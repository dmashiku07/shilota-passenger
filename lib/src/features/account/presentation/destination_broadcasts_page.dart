import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../home/data/ride_repository.dart';
import '../../home/domain/ride_models.dart';

class DestinationBroadcastsPage extends ConsumerStatefulWidget {
  const DestinationBroadcastsPage({super.key});

  static const routePath = '/destination-broadcasts';

  @override
  ConsumerState<DestinationBroadcastsPage> createState() =>
      _DestinationBroadcastsPageState();
}

class _DestinationBroadcastsPageState
    extends ConsumerState<DestinationBroadcastsPage> {
  bool _loading = true;
  List<DriverDestinationBroadcastItem> _broadcasts =
      const <DriverDestinationBroadcastItem>[];
  List<DriverDestinationJoinRequestItem> _requests =
      const <DriverDestinationJoinRequestItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final repository = ref.read(rideRepositoryProvider);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final broadcasts = await repository.getNearbyDestinationBroadcasts(
        lat: position.latitude,
        lng: position.longitude,
      );
      final requests = await repository.getDestinationBroadcastRequests();
      if (!mounted) {
        return;
      }
      setState(() {
        _broadcasts = broadcasts;
        _requests = requests;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _broadcasts = const <DriverDestinationBroadcastItem>[];
        _requests = const <DriverDestinationJoinRequestItem>[];
        _loading = false;
      });
    }
  }

  Future<void> _joinBroadcast(DriverDestinationBroadcastItem item) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await ref.read(rideRepositoryProvider).requestDestinationBroadcastSeat(
            broadcastId: item.id,
            pickupLabel: item.originLabel,
            pickupLat: position.latitude,
            pickupLng: position.longitude,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final featureEnabled =
        AppConfig.featureFlags['driver_destination_broadcast_enabled'] ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(title: const Text('Nearby Driver Trips')),
      body: !featureEnabled
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nearby driver trips are disabled in this environment.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Nearby drivers',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ..._broadcasts.map((item) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.driverName} • ${item.vehicleName} ${item.vehicleNumber}'
                                      .trim(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                    '${item.originLabel} → ${item.destinationLabel}'),
                                const SizedBox(height: 6),
                                Text(
                                  'Departs ${item.departureTime == null ? '-' : DateFormat('dd MMM, hh:mm a').format(item.departureTime!.toLocal())}',
                                ),
                                Text(
                                  '${item.remainingSeats}/${item.availableSeats} seats • TZS ${item.pricePerPassenger.toStringAsFixed(0)}',
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: item.remainingSeats > 0
                                        ? () => _joinBroadcast(item)
                                        : null,
                                    child: const Text('Request to join'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (_broadcasts.isEmpty)
                        const Text(
                          'No nearby driver trips are available right now.',
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Your requests',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ..._requests.map((item) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.destinationLabel),
                          subtitle: Text(
                            '${item.pickupLabel} • ${item.requestedSeats} seat(s)',
                          ),
                          trailing: Text(item.status),
                        );
                      }),
                      if (_requests.isEmpty)
                        const Text(
                            'You have not requested any destination seats yet.'),
                    ],
                  ),
                ),
    );
  }
}
