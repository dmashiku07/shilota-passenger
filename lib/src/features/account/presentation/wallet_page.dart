import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';
import 'wallet_history_page.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  static const routePath = '/wallet';

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  late Future<ApiListResponse<WalletHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ref.read(accountRepositoryProvider).getWalletHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = ref.read(accountRepositoryProvider).getWalletHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionStorageProvider);
    final wallet = session.wallet ?? '0.00';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          TextButton(
            onPressed: () => context.push(WalletHistoryPage.routePath),
            child: const Text('History'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF04E29), Color(0xFFFF7A59)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Balance',
                  style: TextStyle(color: Color(0xFFFCE7E1)),
                ),
                const SizedBox(height: 10),
                Text(
                  '${AppConfig.currencySymbol} $wallet',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track your recent wallet activity and keep an eye on credits and ride deductions in one place.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.35,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<ApiListResponse<WalletHistoryItem>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              final entries =
                  snapshot.data?.items ?? const <WalletHistoryItem>[];
              final creditTotal = _sumAmounts(
                entries.where((entry) => _isCredit(entry.type)),
              );
              final debitTotal = _sumAmounts(
                entries.where((entry) => !_isCredit(entry.type)),
              );

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _WalletInsightCard(
                          label: 'Credits',
                          value:
                              '${AppConfig.currencySymbol} ${creditTotal.toStringAsFixed(0)}',
                          accent: const Color(0xFF2E7D32),
                          icon: Icons.south_west_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _WalletInsightCard(
                          label: 'Debits',
                          value:
                              '${AppConfig.currencySymbol} ${debitTotal.toStringAsFixed(0)}',
                          accent: const Color(0xFFF04E29),
                          icon: Icons.north_east_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _WalletActivityCard(
                    isLoading: snapshot.connectionState != ConnectionState.done,
                    count: entries.length,
                    latest: entries.isEmpty ? null : entries.first,
                    onRefresh: _refresh,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _WalletActionCard(
            icon: Icons.history_rounded,
            title: 'View wallet history',
            subtitle: 'Review credits and deductions',
            onTap: () => context.push(WalletHistoryPage.routePath),
          ),
          const SizedBox(height: 12),
          const _WalletActionCard(
            icon: Icons.payments_outlined,
            title: 'Top-up support',
            subtitle:
                'Wallet history is live. Payment top-up flow can be added next when the Flutter payment path is approved.',
          ),
        ],
      ),
    );
  }

  bool _isCredit(String type) => type.toLowerCase().contains('credit');

  double _sumAmounts(Iterable<WalletHistoryItem> entries) {
    return entries.fold<double>(0, (total, entry) {
      return total + (double.tryParse(entry.amount) ?? 0);
    });
  }
}

class _WalletActionCard extends StatelessWidget {
  const _WalletActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFFCE7E1),
                child: Icon(icon, color: const Color(0xFFF04E29)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(color: Color(0xFF7F756F))),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletInsightCard extends StatelessWidget {
  const _WalletInsightCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.12),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7F756F),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletActivityCard extends StatelessWidget {
  const _WalletActivityCard({
    required this.isLoading,
    required this.count,
    required this.latest,
    required this.onRefresh,
  });

  final bool isLoading;
  final int count;
  final WalletHistoryItem? latest;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final latestTitle = latest == null
        ? 'No transactions yet'
        : latest!.transaction.isEmpty
            ? latest!.type
            : latest!.transaction;

    return Container(
      padding: const EdgeInsets.all(18),
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
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                tooltip: 'Refresh activity',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count transactions loaded',
            style: const TextStyle(color: Color(0xFF7F756F)),
          ),
          const SizedBox(height: 14),
          Text(
            latestTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            latest == null
                ? 'Your future credits and deductions will appear here.'
                : '${AppConfig.currencySymbol} ${latest!.amount}',
            style: const TextStyle(color: Color(0xFF7F756F)),
          ),
        ],
      ),
    );
  }
}
