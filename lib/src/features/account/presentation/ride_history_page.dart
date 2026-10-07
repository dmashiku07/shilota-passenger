import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';
import 'ride_detail_page.dart';

class RideHistoryPage extends ConsumerWidget {
  const RideHistoryPage({super.key});

  static const routePath = '/rides';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountRepositoryProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Rides'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Booking'),
              Tab(text: 'Scheduled'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RideHistoryList(
              future: _bookingRidesFuture(repository),
              emptyMessage: 'No active bookings',
            ),
            _RideHistoryList(
              future: _scheduledRidesFuture(repository),
              emptyMessage: 'No scheduled rides',
            ),
            _RideHistoryList(
              future: _historyRidesFuture(repository),
              emptyMessage: 'No ride history yet',
            ),
          ],
        ),
      ),
    );
  }

  Future<ApiListResponse<RideHistoryItem>> _bookingRidesFuture(
    AccountRepository repository,
  ) async {
    final response = await repository.getRideHistory('booking');
    final items = response.items.where((ride) {
      final status = ride.rideStatus.toLowerCase();
      return status != 'scheduled' && status != 'scheduleridenotaccepted';
    }).toList();

    return ApiListResponse<RideHistoryItem>(
      status: response.status,
      message: response.message,
      items: items,
    );
  }

  Future<ApiListResponse<RideHistoryItem>> _scheduledRidesFuture(
    AccountRepository repository,
  ) async {
    final results = await Future.wait([
      repository.getRideHistory('booking'),
      repository.getRideHistory('history'),
    ]);

    final scheduled = <RideHistoryItem>[
      ...results[0].items,
      ...results[1].items,
    ].where((ride) {
      final status = ride.rideStatus.toLowerCase();
      return status == 'scheduled' || status == 'scheduleridenotaccepted';
    }).toList()
      ..sort((first, second) => second.pickupTime.compareTo(first.pickupTime));

    return ApiListResponse<RideHistoryItem>(
      status: 'true',
      message: null,
      items: scheduled,
    );
  }

  Future<ApiListResponse<RideHistoryItem>> _historyRidesFuture(
    AccountRepository repository,
  ) async {
    final response = await repository.getRideHistory('history');
    final items = response.items.where((ride) {
      final status = ride.rideStatus.toLowerCase();
      return status != 'scheduled' && status != 'scheduleridenotaccepted';
    }).toList();

    return ApiListResponse<RideHistoryItem>(
      status: response.status,
      message: response.message,
      items: items,
    );
  }
}

class _RideHistoryList extends StatelessWidget {
  const _RideHistoryList({
    required this.future,
    required this.emptyMessage,
  });

  final Future<ApiListResponse<RideHistoryItem>> future;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiListResponse<RideHistoryItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }

        final rides = snapshot.data?.items ?? const <RideHistoryItem>[];
        if (rides.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final ride = rides[index];
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push(
                RideDetailPage.routePath,
                extra: RideDetailArgs(
                  onRideId: ride.onRideId,
                  from: ride.rideStatus,
                  pickupTime: ride.pickupTime,
                  vehicleNo: ride.vehicleNo,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFFCE7E1),
                      child: Icon(Icons.local_taxi_rounded,
                          color: Color(0xFFF04E29)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.categoryName.isEmpty
                                ? 'Ride'
                                : ride.categoryName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ride.vehicleNo,
                            style: const TextStyle(color: Color(0xFF7F756F)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ride.pickupTime,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF7F756F)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${AppConfig.currencySymbol} ${ride.totalPrice}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF04E29),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ride.rideStatus,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF7F756F)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
