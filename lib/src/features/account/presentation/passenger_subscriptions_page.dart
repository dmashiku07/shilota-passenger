import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/account_repository.dart';
import '../domain/account_models.dart';

class PassengerSubscriptionsPage extends ConsumerStatefulWidget {
  const PassengerSubscriptionsPage({super.key});

  static const routePath = '/passenger-subscriptions';

  @override
  ConsumerState<PassengerSubscriptionsPage> createState() =>
      _PassengerSubscriptionsPageState();
}

class _PassengerSubscriptionsPageState
    extends ConsumerState<PassengerSubscriptionsPage> {
  late Future<_PassengerSubscriptionsViewData> _loader;
  String? _pendingVerificationTransId;

  @override
  void initState() {
    super.initState();
    _loader = _load();
  }

  Future<_PassengerSubscriptionsViewData> _load() async {
    final repository = ref.read(accountRepositoryProvider);
    final plans = await repository.getPassengerSubscriptionPlans();
    final overview = await repository.getPassengerSubscriptionOverview();
    final history = await repository.getPassengerSubscriptionHistory();
    return _PassengerSubscriptionsViewData(
      plans: plans.items,
      overview: overview,
      history: history.items,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _loader = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(title: const Text('Passenger Plans')),
      body: FutureBuilder<_PassengerSubscriptionsViewData>(
        future: _loader,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '${snapshot.error}',
              onRetry: _refresh,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return _ErrorState(
              message: 'Subscription plans are unavailable',
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SubscriptionSummaryCard(
                  overview: data.overview,
                  pendingVerificationTransId: _pendingVerificationTransId,
                  onVerify: _verifyPendingPayment,
                ),
                const SizedBox(height: 20),
                Text(
                  'Available plans',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF231814),
                      ),
                ),
                const SizedBox(height: 12),
                ...data.plans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(
                      plan: plan,
                      onSelect: () => _startPurchase(plan),
                    ),
                  ),
                ),
                if (data.history.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Subscription history',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF231814),
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...data.history.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HistoryCard(subscription: item),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startPurchase(PassengerPlan plan) async {
    final repository = ref.read(accountRepositoryProvider);
    try {
      final payment =
          await repository.initiatePassengerSubscriptionPurchase(plan.id);
      setState(() {
        _pendingVerificationTransId = payment.transId;
      });
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your payment',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Use the payment link below to complete the ${plan.name} subscription, then come back and verify it.',
                    style: const TextStyle(color: Color(0xFF6A5D57)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4EF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SelectableText(
                      payment.paymentUrl,
                      style: const TextStyle(
                        color: Color(0xFF231814),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: payment.paymentUrl),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment link copied'),
                                ),
                              );
                            }
                          },
                          child: const Text('Copy link'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _openPaymentLink(payment.paymentUrl),
                          child: const Text('Open payment'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _verifyPendingPayment(payment.transId);
                      },
                      child: const Text('I have paid, verify now'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _openPaymentLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _verifyPendingPayment(String transId) async {
    final repository = ref.read(accountRepositoryProvider);
    try {
      await repository.verifyPassengerSubscriptionPayment(transId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription activated successfully')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _PassengerSubscriptionsViewData {
  const _PassengerSubscriptionsViewData({
    required this.plans,
    required this.overview,
    required this.history,
  });

  final List<PassengerPlan> plans;
  final PassengerSubscriptionOverview overview;
  final List<PassengerSubscriptionData> history;
}

class _SubscriptionSummaryCard extends StatelessWidget {
  const _SubscriptionSummaryCard({
    required this.overview,
    required this.pendingVerificationTransId,
    required this.onVerify,
  });

  final PassengerSubscriptionOverview overview;
  final String? pendingVerificationTransId;
  final Future<void> Function(String transId) onVerify;

  @override
  Widget build(BuildContext context) {
    final subscription =
        overview.currentSubscription ?? overview.pendingSubscription;
    if (subscription == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF04E29), Color(0xFFFF7446)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No active passenger plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Choose a premium plan to unlock passenger features on Shilota.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3D7CF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4EF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subscription.status.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: Color(0xFFF04E29),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${subscription.currency} ${subscription.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subscription.planName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subscription.validityLabel,
            style: const TextStyle(color: Color(0xFF6A5D57)),
          ),
          if (subscription.expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expires ${_formatDate(subscription.expiresAt)}',
              style: const TextStyle(color: Color(0xFF6A5D57)),
            ),
          ],
          if (subscription.features.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subscription.features.map((feature) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4EF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    feature.label,
                    style: const TextStyle(
                      color: Color(0xFF5F4D46),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (subscription.isPending && pendingVerificationTransId != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onVerify(pendingVerificationTransId!),
                child: const Text('Verify pending payment'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onSelect,
  });

  final PassengerPlan plan;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3D7CF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    if (plan.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        plan.description,
                        style: const TextStyle(color: Color(0xFF6A5D57)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${plan.currency} ${plan.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            plan.validityLabel,
            style: const TextStyle(color: Color(0xFF6A5D57)),
          ),
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFFF04E29),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature.label,
                        style: const TextStyle(
                          color: Color(0xFF5F4D46),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF04E29),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Choose plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.subscription,
  });

  final PassengerSubscriptionData subscription;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3D7CF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.planName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${subscription.currency} ${subscription.price.toStringAsFixed(0)} • ${subscription.status.replaceAll('_', ' ')}',
                  style: const TextStyle(color: Color(0xFF6A5D57)),
                ),
              ],
            ),
          ),
          if (subscription.expiresAt != null)
            Text(
              _formatDate(subscription.expiresAt),
              style: const TextStyle(
                color: Color(0xFF6A5D57),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFF04E29),
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6A5D57)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                onRetry();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String? value) {
  if (value == null || value.isEmpty) {
    return '-';
  }
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) {
    return value;
  }
  return DateFormat('dd MMM yyyy').format(date);
}
