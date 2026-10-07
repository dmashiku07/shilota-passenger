import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';
import '../domain/account_models.dart';

class FavoriteLocationsPage extends ConsumerStatefulWidget {
  const FavoriteLocationsPage({super.key});

  static const routePath = '/favorite-locations';

  @override
  ConsumerState<FavoriteLocationsPage> createState() =>
      _FavoriteLocationsPageState();
}

class _FavoriteLocationsPageState extends ConsumerState<FavoriteLocationsPage> {
  late Future<ApiListResponse<SavedPlace>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(accountRepositoryProvider).getSavedPlaces();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ref.read(accountRepositoryProvider).getSavedPlaces();
    });
  }

  void _usePlace(SavedPlace place) {
    Navigator.of(context).pop(place);
  }

  Future<void> _removePlace(SavedPlace place) async {
    try {
      await ref.read(accountRepositoryProvider).removeSavedPlace(place.placeId);
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${place.displayTitle} removed')),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Favorite Locations')),
      body: FutureBuilder<ApiListResponse<SavedPlace>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final items = snapshot.data?.items ?? const <SavedPlace>[];
          if (items.isEmpty) {
            return const Center(child: Text('No favorite locations yet'));
          }

          final homes = items.where((item) => item.isHome).toList();
          final works = items.where((item) => item.isWork).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (homes.isNotEmpty || works.isNotEmpty) ...[
                  const Text(
                    'Quick Shortcuts',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (homes.isNotEmpty)
                        Expanded(
                            child: _ShortcutCard(
                                place: homes.first,
                                onTap: () => _usePlace(homes.first))),
                      if (homes.isNotEmpty && works.isNotEmpty)
                        const SizedBox(width: 12),
                      if (works.isNotEmpty)
                        Expanded(
                            child: _ShortcutCard(
                                place: works.first,
                                onTap: () => _usePlace(works.first))),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
                const Text(
                  'All Saved Places',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (final item in items) ...[
                  _SavedPlaceRow(
                    item: item,
                    onUse: () => _usePlace(item),
                    onRemove: () => _removePlace(item),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.place,
    required this.onTap,
  });

  final SavedPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = place.isHome ? Icons.home_rounded : Icons.work_rounded;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFE7DF),
              child: Icon(icon, color: const Color(0xFFF04E29)),
            ),
            const SizedBox(height: 12),
            Text(
              place.displayTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              place.displayAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7F756F)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPlaceRow extends StatelessWidget {
  const _SavedPlaceRow({
    required this.item,
    required this.onUse,
    required this.onRemove,
  });

  final SavedPlace item;
  final VoidCallback onUse;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = item.isHome
        ? Icons.home_rounded
        : item.isWork
            ? Icons.work_rounded
            : Icons.place_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
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
                Text(
                  item.displayTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  item.displayAddress,
                  style: const TextStyle(color: Color(0xFF7F756F)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUse,
            child: const Text('Use'),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove saved place',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
