import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../welcome/presentation/welcome_page.dart';
import '../data/driver_repository.dart';
import '../domain/driver_models.dart';

class DriverWelcomePage extends StatelessWidget {
  const DriverWelcomePage({super.key});

  static const routePath = '/driver';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8F4), Color(0xFFF6ECE7)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.go(WelcomePage.routePath),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const Spacer(),
                const Center(child: BrandLogo(size: 90)),
                const SizedBox(height: 24),
                const _PillLabel('DRIVER APP'),
                const SizedBox(height: 18),
                const Text(
                  'Earn with Shilota',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF231814),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Go online, receive ride requests, manage your vehicle, track earnings, and keep every trip moving from one place.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF7F756F),
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Driver Login',
                  onPressed: () => context.push(DriverLoginPage.routePath),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => context.push(DriverSignupPage.routePath),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    side: const BorderSide(color: Color(0xFFF04E29)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Become a Driver'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DriverLoginPage extends ConsumerStatefulWidget {
  const DriverLoginPage({super.key});

  static const routePath = '/driver/login';

  @override
  ConsumerState<DriverLoginPage> createState() => _DriverLoginPageState();
}

class _DriverLoginPageState extends ConsumerState<DriverLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await ref.read(driverRepositoryProvider).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      context.go(DriverHomePage.routePath);
    } on DriverApiException catch (error) {
      if (mounted) {
        _showSnack(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DriverAuthScaffold(
      title: 'Driver login',
      subtitle: 'Sign in to manage trips, earnings, and availability.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _DriverTextField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: _requiredEmail,
            ),
            const SizedBox(height: 12),
            _DriverTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              validator: (value) => value == null || value.length < 6
                  ? 'Password should have at least 6 characters'
                  : null,
              suffix: IconButton(
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Login',
              isBusy: _isBusy,
              onPressed: _submit,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => context.push(DriverSignupPage.routePath),
              child: const Text('Create driver account'),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverSignupPage extends ConsumerStatefulWidget {
  const DriverSignupPage({super.key});

  static const routePath = '/driver/signup';

  @override
  ConsumerState<DriverSignupPage> createState() => _DriverSignupPageState();
}

class _DriverSignupPageState extends ConsumerState<DriverSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isBusy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await ref.read(driverRepositoryProvider).signup(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            location: _locationController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Driver account created. Login to continue.');
      context.go(DriverLoginPage.routePath);
    } on DriverApiException catch (error) {
      if (mounted) {
        _showSnack(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DriverAuthScaffold(
      title: 'Become a driver',
      subtitle:
          'Create your driver profile, then add vehicle and compliance details.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _DriverTextField(
              controller: _nameController,
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              validator: (value) => value == null || value.trim().length < 3
                  ? 'Full name should be at least 3 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            _DriverTextField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: _requiredEmail,
            ),
            const SizedBox(height: 12),
            _DriverTextField(
              controller: _locationController,
              label: 'Operating location',
              icon: Icons.location_on_outlined,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Choose your location'
                  : null,
            ),
            const SizedBox(height: 12),
            _DriverTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              validator: (value) => value == null || value.length < 6
                  ? 'Password should have at least 6 characters'
                  : null,
              suffix: IconButton(
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Create Account',
              isBusy: _isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

  static const routePath = '/driver/home';

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _mapController;
  Position? _position;
  bool _isOnline = false;
  bool _isLoadingLocation = true;
  String _locationStatus = 'Finding your current location...';
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapLocation());
    unawaited(_loadAdminData());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    try {
      await ref.read(driverRepositoryProvider).getAdminData();
    } on DriverApiException catch (error) {
      if (mounted) {
        _showSnack(context, error.message);
      }
    }
  }

  Future<void> _bootstrapLocation() async {
    try {
      final permission = await _ensureLocationPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Location permission is required for driver mode.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
        _isLoadingLocation = false;
        _locationStatus = 'Ready to receive trips nearby.';
      });
      await ref.read(driverRepositoryProvider).updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLocation = false;
        _locationStatus = 'Unable to load location: $error';
      });
    }
  }

  Future<void> _setOnline(bool value) async {
    final oldValue = _isOnline;
    setState(() => _isOnline = value);
    try {
      await ref.read(driverRepositoryProvider).setOnlineStatus(value);
    } on DriverApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isOnline = oldValue);
      _showSnack(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DriverDashboardTab(
        isOnline: _isOnline,
        locationStatus: _locationStatus,
        isLoadingLocation: _isLoadingLocation,
        position: _position,
        onOnlineChanged: _setOnline,
        onMapCreated: (controller) => _mapController = controller,
      ),
      const _DriverTripsTab(),
      const _DriverWalletTab(),
      const _DriverAccountTab(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: const DriverDrawer(),
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                context.push(DriverCollectionPage.path('notifications')),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class DriverCollectionPage extends ConsumerWidget {
  const DriverCollectionPage({
    super.key,
    required this.kind,
  });

  static const routePath = '/driver/list/:kind';

  static String path(String kind) => '/driver/list/$kind';

  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = _DriverCollectionConfig.fromKind(kind);
    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      body: FutureBuilder<List<DriverListItem>>(
        future: config.load(ref.read(driverRepositoryProvider)),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DriverEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load ${config.title.toLowerCase()}',
              subtitle: '${snapshot.error}',
            );
          }
          final items = snapshot.data ?? const <DriverListItem>[];
          if (items.isEmpty) {
            return _DriverEmptyState(
              icon: config.icon,
              title: 'No ${config.title.toLowerCase()} yet',
              subtitle: config.emptyMessage,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) =>
                _DriverListCard(item: items[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

class DriverVehicleSetupPage extends StatelessWidget {
  const DriverVehicleSetupPage({super.key});

  static const routePath = '/driver/vehicle';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Setup')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _VehicleStepCard(
            icon: Icons.directions_car_filled_outlined,
            title: 'Vehicle details',
            subtitle:
                'Vehicle name, plate number, seats, license, and insurance.',
          ),
          _VehicleStepCard(
            icon: Icons.verified_user_outlined,
            title: 'Inspection & security',
            subtitle: 'Upload inspection and security deposit documents.',
          ),
          _VehicleStepCard(
            icon: Icons.payments_outlined,
            title: 'Payment account',
            subtitle: 'Add payout details before receiving settlements.',
          ),
        ],
      ),
    );
  }
}

class DriverDrawer extends ConsumerWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStorageProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const BrandLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.fullName ?? 'Driver',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          session.email ?? 'Shilota driver',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF7F756F)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    onTap: () => context.go(DriverHomePage.routePath),
                  ),
                  _DrawerItem(
                    icon: Icons.upcoming_outlined,
                    label: 'Upcoming Rides',
                    onTap: () =>
                        context.push(DriverCollectionPage.path('upcoming')),
                  ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: 'Ride History',
                    onTap: () =>
                        context.push(DriverCollectionPage.path('history')),
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    onTap: () =>
                        context.push(DriverCollectionPage.path('wallet')),
                  ),
                  _DrawerItem(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Subscription Plans',
                    onTap: () => context
                        .push(DriverCollectionPage.path('subscriptions')),
                  ),
                  _DrawerItem(
                    icon: Icons.alt_route_rounded,
                    label: 'Destination Broadcasts',
                    onTap: () =>
                        context.push(DriverCollectionPage.path('broadcasts')),
                  ),
                  _DrawerItem(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle Setup',
                    onTap: () => context.push(DriverVehicleSetupPage.routePath),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              onTap: () async {
                await ref.read(driverRepositoryProvider).logout();
                if (context.mounted) {
                  context.go(DriverWelcomePage.routePath);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverDashboardTab extends ConsumerWidget {
  const _DriverDashboardTab({
    required this.isOnline,
    required this.locationStatus,
    required this.isLoadingLocation,
    required this.position,
    required this.onOnlineChanged,
    required this.onMapCreated,
  });

  final bool isOnline;
  final String locationStatus;
  final bool isLoadingLocation;
  final Position? position;
  final ValueChanged<bool> onOnlineChanged;
  final ValueChanged<GoogleMapController> onMapCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DriverDashboard>(
      future: ref.read(driverRepositoryProvider).getDashboard(),
      builder: (context, snapshot) {
        final dashboard = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DriverStatusPanel(
              isOnline: isOnline,
              locationStatus: locationStatus,
              isLoadingLocation: isLoadingLocation,
              onOnlineChanged: onOnlineChanged,
            ),
            const SizedBox(height: 14),
            _DriverMapCard(
              position: position,
              onMapCreated: onMapCreated,
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _MetricCard(
                  icon: Icons.route_rounded,
                  label: 'Total Rides',
                  value: dashboard?.totalRides ?? '0',
                ),
                _MetricCard(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Completed',
                  value: dashboard?.completedRides ?? '0',
                ),
                _MetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Wallet',
                  value: dashboard?.wallet ?? '0.00',
                ),
                _MetricCard(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Plan',
                  value: dashboard?.subscriptionStatus ?? 'Basic',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DriverTripsTab extends StatelessWidget {
  const _DriverTripsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ActionPanel(
          icon: Icons.upcoming_outlined,
          title: 'Upcoming Rides',
          subtitle: 'Scheduled trips waiting for pre-acceptance.',
          onTap: () => context.push(DriverCollectionPage.path('upcoming')),
        ),
        _ActionPanel(
          icon: Icons.history_rounded,
          title: 'Ride History',
          subtitle: 'Completed, cancelled, and cash payment trips.',
          onTap: () => context.push(DriverCollectionPage.path('history')),
        ),
        _ActionPanel(
          icon: Icons.alt_route_rounded,
          title: 'Destination Broadcasts',
          subtitle: 'Publish trips and handle passenger requests.',
          onTap: () => context.push(DriverCollectionPage.path('broadcasts')),
        ),
        _ActionPanel(
          icon: Icons.tune_rounded,
          title: 'Acceptance Settings',
          subtitle: 'Auto-accept, pickup distance, fare floor, and ride types.',
          onTap: () => _showNotReady(context),
        ),
      ],
    );
  }
}

class _DriverWalletTab extends StatelessWidget {
  const _DriverWalletTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ActionPanel(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Wallet History',
          subtitle: 'Review earnings, deductions, and payouts.',
          onTap: () => context.push(DriverCollectionPage.path('wallet')),
        ),
        _ActionPanel(
          icon: Icons.workspace_premium_outlined,
          title: 'Subscription Plans',
          subtitle: 'Choose driver plans and manage access.',
          onTap: () => context.push(DriverCollectionPage.path('subscriptions')),
        ),
        _ActionPanel(
          icon: Icons.payments_outlined,
          title: 'Payment Account',
          subtitle: 'Bank and payout details for settlements.',
          onTap: () => _showNotReady(context),
        ),
      ],
    );
  }
}

class _DriverAccountTab extends ConsumerWidget {
  const _DriverAccountTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DriverProfile>(
      future: ref.read(driverRepositoryProvider).getProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DriverProfileHeader(profile: profile),
            const SizedBox(height: 14),
            _ActionPanel(
              icon: Icons.directions_car_outlined,
              title: 'Vehicle Setup',
              subtitle: 'Vehicle details, inspection, and security deposit.',
              onTap: () => context.push(DriverVehicleSetupPage.routePath),
            ),
            _ActionPanel(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'System, trip, and payment alerts.',
              onTap: () =>
                  context.push(DriverCollectionPage.path('notifications')),
            ),
            _ActionPanel(
              icon: Icons.help_outline_rounded,
              title: 'Help & FAQ',
              subtitle: 'Driver help pages and support messages.',
              onTap: () => _showNotReady(context),
            ),
            _ActionPanel(
              icon: Icons.shield_outlined,
              title: 'Emergency Contacts',
              subtitle: 'Manage contacts used during SOS events.',
              onTap: () => _showNotReady(context),
            ),
          ],
        );
      },
    );
  }
}

class _DriverCollectionConfig {
  const _DriverCollectionConfig({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.load,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final Future<List<DriverListItem>> Function(DriverRepository repository) load;

  factory _DriverCollectionConfig.fromKind(String kind) {
    switch (kind) {
      case 'notifications':
        return _DriverCollectionConfig(
          title: 'Notifications',
          icon: Icons.notifications_none_rounded,
          emptyMessage: 'Driver notifications will appear here.',
          load: (repository) => repository.getNotifications(),
        );
      case 'upcoming':
        return _DriverCollectionConfig(
          title: 'Upcoming Rides',
          icon: Icons.upcoming_outlined,
          emptyMessage: 'Scheduled rides will appear here.',
          load: (repository) => repository.getUpcomingRides(),
        );
      case 'history':
        return _DriverCollectionConfig(
          title: 'Ride History',
          icon: Icons.history_rounded,
          emptyMessage: 'Completed and cancelled trips will appear here.',
          load: (repository) => repository.getRideHistory(),
        );
      case 'wallet':
        return _DriverCollectionConfig(
          title: 'Wallet History',
          icon: Icons.account_balance_wallet_outlined,
          emptyMessage: 'Wallet transactions will appear here.',
          load: (repository) => repository.getWalletHistory(),
        );
      case 'subscriptions':
        return _DriverCollectionConfig(
          title: 'Subscription Plans',
          icon: Icons.workspace_premium_outlined,
          emptyMessage: 'Driver subscription plans will appear here.',
          load: (repository) => repository.getSubscriptionPlans(),
        );
      case 'broadcasts':
        return _DriverCollectionConfig(
          title: 'Destination Broadcasts',
          icon: Icons.alt_route_rounded,
          emptyMessage: 'Destination broadcasts will appear here.',
          load: (repository) => repository.getDestinationBroadcasts(),
        );
      default:
        return _DriverCollectionConfig(
          title: 'Driver Items',
          icon: Icons.list_alt_rounded,
          emptyMessage: 'Nothing to show yet.',
          load: (_) async => const <DriverListItem>[],
        );
    }
  }
}

class _DriverAuthScaffold extends StatelessWidget {
  const _DriverAuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          const Center(child: BrandLogo(size: 66)),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF231814),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              height: 1.5,
              color: Color(0xFF7F756F),
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _DriverTextField extends StatelessWidget {
  const _DriverTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }
}

class _DriverStatusPanel extends StatelessWidget {
  const _DriverStatusPanel({
    required this.isOnline,
    required this.locationStatus,
    required this.isLoadingLocation,
    required this.onOnlineChanged,
  });

  final bool isOnline;
  final String locationStatus;
  final bool isLoadingLocation;
  final ValueChanged<bool> onOnlineChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF04E29),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'You are online' : 'You are offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  locationStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (isLoadingLocation)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          else
            Switch(
              value: isOnline,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF1F8A4C),
              onChanged: onOnlineChanged,
            ),
        ],
      ),
    );
  }
}

class _DriverMapCard extends StatelessWidget {
  const _DriverMapCard({
    required this.position,
    required this.onMapCreated,
  });

  final Position? position;
  final ValueChanged<GoogleMapController> onMapCreated;

  @override
  Widget build(BuildContext context) {
    final latLng = position == null
        ? const LatLng(-6.7924, 39.2083)
        : LatLng(position!.latitude, position!.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 230,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: latLng,
            zoom: 14,
          ),
          onMapCreated: onMapCreated,
          myLocationEnabled: position != null,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('driver'),
              position: latLng,
              infoWindow: const InfoWindow(title: 'Driver location'),
            ),
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E5E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: const Color(0xFFF04E29)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF7F756F)),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5E0)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFEEE8),
          child: Icon(icon, color: const Color(0xFFF04E29)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _DriverProfileHeader extends StatelessWidget {
  const _DriverProfileHeader({required this.profile});

  final DriverProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E5E0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFFFEEE8),
            backgroundImage: profile?.userImage == null
                ? null
                : NetworkImage(profile!.userImage!),
            child: profile?.userImage == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Color(0xFFF04E29),
                    size: 34,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName ?? 'Driver',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.email ?? 'Profile details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF7F756F)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallChip(
                      label: profile?.vehicleApproval ?? 'Vehicle pending',
                    ),
                    _SmallChip(
                      label: 'Wallet ${profile?.wallet ?? '0.00'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverListCard extends StatelessWidget {
  const _DriverListCard({required this.item});

  final DriverListItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFEEE8),
            child: Icon(Icons.local_taxi_outlined, color: Color(0xFFF04E29)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle!,
                    style: const TextStyle(color: Color(0xFF7F756F)),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.status != null) _SmallChip(label: item.status!),
                    if (item.amount != null) _SmallChip(label: item.amount!),
                    if (item.createdAt != null)
                      _SmallChip(label: item.createdAt!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleStepCard extends StatelessWidget {
  const _VehicleStepCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _ActionPanel(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _showNotReady(context),
    );
  }
}

class _DriverEmptyState extends StatelessWidget {
  const _DriverEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFFFEEE8),
              child: Icon(icon, color: const Color(0xFFF04E29), size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7F756F)),
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
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6A5D57),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14F04E29),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF04E29),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

Future<LocationPermission> _ensureLocationPermission() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  return permission;
}

String? _requiredEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email cannot be empty';
  }
  if (!value.contains('@')) {
    return 'Enter a valid email address';
  }
  return null;
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void _showNotReady(BuildContext context) {
  _showSnack(context, 'This driver flow is ready for API wiring next.');
}
