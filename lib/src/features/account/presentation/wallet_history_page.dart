import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

class WalletHistoryPage extends ConsumerWidget {
  const WalletHistoryPage({super.key});

  static const routePath = '/wallet-history';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet History')),
      body: FutureBuilder<ApiListResponse<WalletHistoryItem>>(
        future: repository.getWalletHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final entries = snapshot.data?.items ?? const <WalletHistoryItem>[];
          if (entries.isEmpty) {
            return const Center(child: Text('No wallet transactions yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isCredit = entry.type.toLowerCase().contains('credit');
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isCredit
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF1EC),
                      child: Icon(
                        isCredit
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: isCredit
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF04E29),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.transaction.isEmpty
                                ? entry.type
                                : entry.transaction,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(entry.date),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF7F756F)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${AppConfig.currencySymbol} ${entry.amount}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isCredit
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF04E29),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(String input) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm')
          .format(DateTime.parse(input).toLocal());
    } catch (_) {
      return input;
    }
  }
}
