import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../account/presentation/favorite_locations_page.dart';
import '../../account/presentation/help_page.dart';
import '../../account/presentation/invite_page.dart';
import '../../account/presentation/passenger_subscriptions_page.dart';
import '../../account/presentation/profile_page.dart';
import '../../account/presentation/ride_history_page.dart';
import 'home_shell_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.fullName,
    required this.email,
  });

  final String fullName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF04E29), Color(0xFFFF7A59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandLogo(size: 42, white: true),
                  const SizedBox(height: 10),
                  Text(
                    fullName.isEmpty ? AppConfig.appName : fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email.isEmpty ? 'Rider account' : email,
                    style: const TextStyle(
                      color: Color(0xFFFCE7E1),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: () => context.go(HomeShellPage.routePath),
                  ),
                  _DrawerItem(
                    icon: Icons.local_taxi_rounded,
                    label: 'Your Rides',
                    onTap: () => context.push(RideHistoryPage.routePath),
                  ),
                  _DrawerItem(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Subscription Plans',
                    onTap: () =>
                        context.push(PassengerSubscriptionsPage.routePath),
                  ),
                  _DrawerItem(
                    icon: Icons.place_rounded,
                    label: 'Favorite Locations',
                    onTap: () => context.push(FavoriteLocationsPage.routePath),
                  ),
                  _DrawerItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    onTap: () => context.push(ProfilePage.routePath),
                  ),
                  _DrawerItem(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Invite',
                    onTap: () => context.push(InvitePage.routePath),
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help',
                    onTap: () => context.push(HelpPage.routePath),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFF04E29)),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}
