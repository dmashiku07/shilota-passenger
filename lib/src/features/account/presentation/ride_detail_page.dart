import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/storage_providers.dart';
import '../../home/presentation/home_shell_page.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';
import 'support_conversation_page.dart';
import 'write_review_page.dart';

class RideDetailPage extends ConsumerStatefulWidget {
  const RideDetailPage({
    super.key,
    required this.args,
  });

  static const routePath = '/ride-detail';

  final RideDetailArgs args;

  @override
  ConsumerState<RideDetailPage> createState() => _RideDetailPageState();
}

class _RideDetailPageState extends ConsumerState<RideDetailPage> {
  late Future<RideDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RideDetailData> _load() {
    final repository = ref.read(accountRepositoryProvider);
    if (widget.args.from == 'completed') {
      return repository.getCompletedRideDetails(onRideId: widget.args.onRideId);
    }
    return repository.getRideDetails(
      onRideId: widget.args.onRideId,
      type: widget.args.from,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Detail')),
      body: FutureBuilder<RideDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final ride = snapshot.data;
          if (ride == null || !ride.isSuccess) {
            return Center(
                child: Text(ride?.message ?? 'Ride details unavailable'));
          }

          final values = ride.values;
          final from = widget.args.from;
          final isCompleted = from == 'completed';
          final isActive = const <String>{
            'requested',
            'accepted',
            'ontheway',
            'onride',
          }.contains(from.toLowerCase());
          final paymentDirectToDriver =
              (values['payment_direct_to_driver'] ?? '0') == '1';
          final canReview =
              isCompleted && (values['ispayment'] ?? 'true') == 'true';
          final isReviewed = values['isreview'] == 'true';

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(AppConfig.lineColorHex)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headline(values, from),
                        style: const TextStyle(
                          fontSize: AppConfig.textSizeLarge,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(
                            values['pickup_time'] ?? widget.args.pickupTime),
                        style: const TextStyle(
                            color: Color(AppConfig.textSecondaryColorHex)),
                      ),
                      const SizedBox(height: 18),
                      _DetailRow(
                        label: 'Pickup',
                        value: values['pickup_location'] ?? '',
                      ),
                      _DetailRow(
                        label: 'Drop',
                        value: values['drop_location'] ?? '',
                      ),
                      _DetailRow(
                        label: 'Vehicle',
                        value: values['vehicle_no'] ??
                            widget.args.vehicleNo ??
                            values['category_name'] ??
                            '',
                      ),
                      _DetailRow(
                        label: 'Fare',
                        value:
                            '${AppConfig.currencySymbol} ${_fareValue(values, from)}',
                      ),
                      if (isCompleted) ...[
                        _DetailRow(
                          label: 'Payment Type',
                          value: paymentDirectToDriver
                              ? 'Direct to driver'
                              : (values['payment_type'] ?? ''),
                        ),
                        _DetailRow(
                          label: 'Payment Status',
                          value: values['payment_status'] ?? 'unpaid',
                        ),
                        if (paymentDirectToDriver) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Payment for this ride is made directly to the driver. Shilota does not deduct a platform commission on new rides.',
                              style: TextStyle(
                                color: Color(AppConfig.textPrimaryColorHex),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isCompleted && isReviewed) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(AppConfig.lineColorHex)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Review',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index <
                                      (double.tryParse(
                                                  values['rating'] ?? '0') ??
                                              0)
                                          .round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color:
                                  const Color(AppConfig.notificationColorHex),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(values['review_message'] ?? ''),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (canReview)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await context.push(
                          WriteReviewPage.routePath,
                          extra: ReviewArgs(
                            onRideId: widget.args.onRideId,
                            from: widget.args.from,
                            rating: values['rating'],
                            reviewMessage: values['review_message'],
                          ),
                        );
                        await _refresh();
                      },
                      child: Text(isReviewed ? 'Edit Review' : 'Write Review'),
                    ),
                  ),
                if (from == 'scheduled' ||
                    from == 'scheduleridenotaccepted') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(
                        HomeShellPage.routePath,
                        extra: RideBookingDraft(
                          onRideId: widget.args.onRideId,
                          pickupAddress: values['pickup_location'] ?? '',
                          dropoffAddress: values['drop_location'] ?? '',
                          pickupLat:
                              double.tryParse(values['pickup_lat'] ?? '') ?? 0,
                          pickupLng:
                              double.tryParse(values['pickup_lng'] ?? '') ?? 0,
                          dropoffLat:
                              double.tryParse(values['drop_lat'] ?? '') ?? 0,
                          dropoffLng:
                              double.tryParse(values['drop_lng'] ?? '') ?? 0,
                          scheduleAt: values['pickup_time'],
                        ),
                      ),
                      child: const Text('Modify Schedule'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(accountRepositoryProvider)
                              .cancelRideById(widget.args.onRideId);
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Ride cancelled')),
                          );
                          this.context.pop();
                        } catch (error) {
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('$error')),
                          );
                        }
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
                if (isCompleted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final payload = await _showLostItemDialog(context);
                        if (payload == null ||
                            payload.description.trim().isEmpty ||
                            payload.contactPhone.trim().isEmpty) {
                          return;
                        }
                        try {
                          final lostItemId = await ref
                              .read(accountRepositoryProvider)
                              .reportLostItem(
                                rideId: widget.args.onRideId,
                                description: payload.description.trim(),
                                contactPhone: payload.contactPhone.trim(),
                              );
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                                content: Text('Lost item report submitted')),
                          );
                          await this.context.push(
                                SupportConversationPage.routePath,
                                extra: SupportConversationArgs(
                                  title: 'Lost Item Follow-up',
                                  subject:
                                      'Lost item follow-up for ride ${widget.args.onRideId}',
                                  recipientLabel: 'Shilota support',
                                  lostItemId: lostItemId,
                                  prefillMessage: null,
                                ),
                              );
                        } catch (error) {
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('$error')),
                          );
                        }
                      },
                      child: const Text('Report Lost Item'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          final lostItemId = await ref
                              .read(accountRepositoryProvider)
                              .getLostItemCaseIdForRide(widget.args.onRideId);
                          if (!mounted) {
                            return;
                          }
                          if (lostItemId == null || lostItemId.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No lost item case found for this ride yet',
                                ),
                              ),
                            );
                            return;
                          }
                          await this.context.push(
                                SupportConversationPage.routePath,
                                extra: SupportConversationArgs(
                                  title: 'Lost Item Follow-up',
                                  subject:
                                      'Lost item follow-up for ride ${widget.args.onRideId}',
                                  recipientLabel: 'Shilota support',
                                  lostItemId: lostItemId,
                                ),
                              );
                        } catch (error) {
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('$error')),
                          );
                        }
                      },
                      child: const Text('Lost Item Follow-up Chat'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go(
                      isActive
                          ? '${HomeShellPage.routePath}?activeRide=${Uri.encodeQueryComponent(widget.args.onRideId)}'
                          : HomeShellPage.routePath,
                    ),
                    child: Text(
                      isCompleted
                          ? 'Ride Again'
                          : isActive
                              ? 'Continue Ride'
                              : 'Open Home',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fareValue(Map<String, String> values, String from) {
    if (from == 'completed') {
      return values['ride_total'] ?? '0';
    }
    if (from == 'cancelled' ||
        from == 'scheduled' ||
        from == 'scheduleridenotaccepted') {
      return values['approx_price'] ?? '0';
    }
    return values['approx_price'] ?? values['ride_total'] ?? '0';
  }

  String _headline(Map<String, String> values, String from) {
    if (from == 'cancelled') {
      return 'Cancelled';
    }
    if (from == 'scheduled' || from == 'scheduleridenotaccepted') {
      return 'Scheduled';
    }
    if (from == 'completed') {
      return values['vehicle_no'] ?? 'Completed Ride';
    }
    return values['category_name'] ?? 'Ride';
  }

  String _formatTime(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return '-';

    DateTime? instant;
    final unixTimestamp = int.tryParse(value);
    if (unixTimestamp != null) {
      if (unixTimestamp <= 0) return '-';
      final milliseconds =
          unixTimestamp < 100000000000 ? unixTimestamp * 1000 : unixTimestamp;
      instant = DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      );
    } else {
      instant = DateTime.tryParse(value);
      if (instant == null) return value;
    }

    // Tanzania observes East Africa Time (UTC+3) throughout the year.
    final tanzaniaTime = instant.toUtc().add(const Duration(hours: 3));
    return DateFormat('dd MMM yyyy, HH:mm').format(tanzaniaTime);
  }

  Future<_LostItemPayload?> _showLostItemDialog(BuildContext context) async {
    final descriptionController = TextEditingController();
    final phoneController = TextEditingController(
      text: ref.read(sessionStorageProvider).phoneNumber ?? '',
    );
    return showDialog<_LostItemPayload>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report Lost Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact phone',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe lost item',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                _LostItemPayload(
                  description: descriptionController.text,
                  contactPhone: phoneController.text,
                ),
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}

class _LostItemPayload {
  const _LostItemPayload({
    required this.description,
    required this.contactPhone,
  });

  final String description;
  final String contactPhone;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: AppConfig.textSizeSmall,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Color(AppConfig.textSecondaryColorHex),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
