import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/enter_phone_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/account/presentation/favorite_locations_page.dart';
import '../../features/account/presentation/emergency_contacts_page.dart';
import '../../features/account/presentation/edit_profile_page.dart';
import '../../features/account/presentation/help_page.dart';
import '../../features/account/presentation/invite_page.dart';
import '../../features/account/presentation/notifications_page.dart';
import '../../features/account/presentation/passenger_subscriptions_page.dart';
import '../../features/account/presentation/profile_page.dart';
import '../../features/account/domain/account_models.dart';
import '../../features/account/presentation/ride_detail_page.dart';
import '../../features/account/presentation/ride_chat_page.dart';
import '../../features/account/presentation/ride_history_page.dart';
import '../../features/account/presentation/sos_page.dart';
import '../../features/account/presentation/support_conversation_page.dart';
import '../../features/account/presentation/active_call_page.dart';
import '../../features/account/presentation/destination_broadcasts_page.dart';
import '../../features/account/presentation/write_review_page.dart';
import '../../features/home/domain/ride_models.dart';
import '../../features/home/presentation/home_shell_page.dart';
import '../../features/home/presentation/select_location_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/welcome/presentation/welcome_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: SplashPage.routePath,
    routes: [
      GoRoute(
        path: SplashPage.routePath,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: WelcomePage.routePath,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: LoginPage.routePath,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: SignupPage.routePath,
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: EnterPhonePage.routePath,
        builder: (context, state) => EnterPhonePage(
          pendingSignup: state.extra as PendingSignup?,
        ),
      ),
      GoRoute(
        path: HomeShellPage.routePath,
        builder: (context, state) => HomeShellPage(
          shortcutType: state.uri.queryParameters['shortcut'],
          activeRideId: state.uri.queryParameters['activeRide'],
          draft: state.extra as RideBookingDraft?,
        ),
      ),
      GoRoute(
        path: SelectLocationPage.routePath,
        builder: (context, state) => SelectLocationPage(
          args: state.extra as LocationSelectionArgs,
        ),
      ),
      GoRoute(
        path: ProfilePage.routePath,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: EditProfilePage.routePath,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: PassengerSubscriptionsPage.routePath,
        builder: (context, state) => const PassengerSubscriptionsPage(),
      ),
      GoRoute(
        path: DestinationBroadcastsPage.routePath,
        builder: (context, state) => const DestinationBroadcastsPage(),
      ),
      GoRoute(
        path: NotificationsPage.routePath,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: HelpPage.routePath,
        builder: (context, state) => const HelpPage(),
      ),
      GoRoute(
        path: FavoriteLocationsPage.routePath,
        builder: (context, state) => const FavoriteLocationsPage(),
      ),
      GoRoute(
        path: EmergencyContactsPage.routePath,
        builder: (context, state) => EmergencyContactsPage(
          args: state.extra as EmergencyContactsArgs,
        ),
      ),
      GoRoute(
        path: RideHistoryPage.routePath,
        builder: (context, state) => const RideHistoryPage(),
      ),
      GoRoute(
        path: InvitePage.routePath,
        builder: (context, state) => const InvitePage(),
      ),
      GoRoute(
        path: RideDetailPage.routePath,
        builder: (context, state) => RideDetailPage(
          args: state.extra as RideDetailArgs,
        ),
      ),
      GoRoute(
        path: WriteReviewPage.routePath,
        builder: (context, state) => WriteReviewPage(
          args: state.extra as ReviewArgs,
        ),
      ),
      GoRoute(
        path: SosPage.routePath,
        builder: (context, state) => SosPage(
          rideId: state.extra as String,
        ),
      ),
      GoRoute(
        path: SupportConversationPage.routePath,
        builder: (context, state) => SupportConversationPage(
          args: state.extra as SupportConversationArgs,
        ),
      ),
      GoRoute(
        path: RideChatPage.routePath,
        builder: (context, state) => RideChatPage(
          args: state.extra as RideChatArgs,
        ),
      ),
      GoRoute(
        path: ActiveCallPage.routePath,
        builder: (context, state) => ActiveCallPage(
          args: state.extra as ActiveCallArgs,
        ),
      ),
    ],
  );
});

final rootNavigatorKey = GlobalKey<NavigatorState>();
