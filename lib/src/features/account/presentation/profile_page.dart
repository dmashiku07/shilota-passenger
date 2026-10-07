import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';
import 'emergency_contacts_page.dart';
import 'edit_profile_page.dart';
import '../../welcome/presentation/welcome_page.dart';
import 'help_page.dart';
import 'notifications_page.dart';
import 'passenger_subscriptions_page.dart';
import 'destination_broadcasts_page.dart';
import 'sos_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const routePath = '/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late Future<ProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ref.read(accountRepositoryProvider).getProfile();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(accountRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(title: const Text('My Account')),
      body: FutureBuilder<ProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}');
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const _ErrorState(message: 'Profile is unavailable');
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFFCE7E1),
                    child: (profile.userImage?.isNotEmpty ?? false)
                        ? ClipOval(
                            child: Image.network(
                              profile.userImage!,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 32,
                                color: Color(0xFFF04E29),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 32,
                            color: Color(0xFFF04E29),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profile.fullName ?? 'Rider',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile.email ?? '',
                    style: const TextStyle(color: Color(0xFF7F756F)),
                  ),
                  FutureBuilder<RiderBlockStatus>(
                    future: repository.getRiderBlockStatus(),
                    builder: (context, reviewSnapshot) {
                      final review = reviewSnapshot.data;
                      if (review == null || !review.hasAccountNotice) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4EF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF4D6CD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.pendingReview
                                  ? 'Account review in progress'
                                  : 'Account safety notice',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF231814),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              review.pendingReview
                                  ? 'Your account was flagged after repeated rider block reports. Operations will review recent trips before any further action.'
                                  : 'Recent rider block reports were recorded on your account.',
                              style: const TextStyle(color: Color(0xFF6A5D57)),
                            ),
                            if ((review.reason ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Latest note: ${review.reason}',
                                style:
                                    const TextStyle(color: Color(0xFF6A5D57)),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _Badge(
                        icon: Icons.star_rounded,
                        text:
                            '${profile.emergencyContacts.length + 4.8} rating',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('ACCOUNT'),
              _MenuTile(
                icon: Icons.person_outline_rounded,
                title: 'Profile',
                subtitle:
                    '${profile.countryCode ?? ''} ${profile.phoneNumber ?? ''}'
                        .trim(),
                onTap: () async {
                  final updated = await context.push<bool>(
                    EditProfilePage.routePath,
                  );
                  if (updated == true && mounted) {
                    setState(() {
                      _profileFuture =
                          ref.read(accountRepositoryProvider).getProfile();
                    });
                  }
                },
              ),
              _MenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                onTap: () => context.push(NotificationsPage.routePath),
              ),
              _MenuTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Passenger Plans',
                subtitle: 'Manage premium features',
                onTap: () => context.push(PassengerSubscriptionsPage.routePath),
              ),
              if (AppConfig
                      .featureFlags['driver_destination_broadcast_enabled'] ??
                  false)
                _MenuTile(
                  icon: Icons.alt_route_rounded,
                  title: 'Nearby Driver Trips',
                  subtitle: 'Request a seat from drivers heading your way',
                  onTap: () =>
                      context.push(DestinationBroadcastsPage.routePath),
                ),
              const _SectionLabel('PREFERENCES'),
              const _MenuTile(
                icon: Icons.language_rounded,
                title: 'Language',
                trailingText: 'English',
              ),
              _MenuTile(
                icon: Icons.security_rounded,
                title: 'User ID',
                trailingText: profile.userId ?? '-',
              ),
              const _SectionLabel('SUPPORT'),
              _MenuTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQ',
                onTap: () => context.push(HelpPage.routePath),
              ),
              _MenuTile(
                icon: Icons.shield_outlined,
                title: 'Emergency Contacts',
                trailingText: '${profile.emergencyContacts.length}',
                onTap: () => context.push(
                  EmergencyContactsPage.routePath,
                  extra: EmergencyContactsArgs(
                    contacts: profile.emergencyContacts,
                  ),
                ),
              ),
              _MenuTile(
                icon: Icons.emergency_outlined,
                title: 'Emergency Alert',
                subtitle: 'Send your location to Shilota operations',
                onTap: () => context.push(SosPage.routePath, extra: ''),
              ),
              const _SectionLabel('LEGAL'),
              const _MenuTile(
                icon: Icons.article_outlined,
                title: 'Terms of Service',
                trailingText: 'App policy',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(sessionStorageProvider).clear();
                  if (context.mounted) {
                    context.go(WelcomePage.routePath);
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF04E29),
                  side: const BorderSide(color: Color(0xFFF04E29)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9B8D86),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFEEE8),
          child: Icon(icon, color: const Color(0xFFF04E29)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: Color(0xFF7F756F)),
              ),
        trailing: trailingText != null
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                ),
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFF7F756F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF04E29)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF6A5D57),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
