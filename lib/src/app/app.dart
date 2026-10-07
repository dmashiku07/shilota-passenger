import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/app_router.dart';
import '../core/services/local_notification_service.dart';
import '../core/services/realtime_service.dart';
import '../features/account/domain/account_models.dart';
import '../features/account/presentation/active_call_page.dart';
import '../core/theme/app_theme.dart';

class ShilotaApp extends ConsumerWidget {
  const ShilotaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Shilota',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      builder: (context, child) {
        return SafeArea(
          top: false,
          left: false,
          right: false,
          minimum: const EdgeInsets.only(bottom: 8),
          child: _RuntimeBootstrap(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _RuntimeBootstrap extends ConsumerStatefulWidget {
  const _RuntimeBootstrap({
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<_RuntimeBootstrap> createState() => _RuntimeBootstrapState();
}

class _RuntimeBootstrapState extends ConsumerState<_RuntimeBootstrap> {
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription? _callEndedSubscription;

  @override
  void initState() {
    super.initState();
    final realtimeService = ref.read(realtimeServiceProvider);
    _incomingCallSubscription = realtimeService.incomingCalls.listen((event) {
      final activeRoom = ref.read(activeCallRoomProvider);
      if (activeRoom == event.roomId || !mounted) {
        return;
      }
      ref.read(appRouterProvider).push(
            ActiveCallPage.routePath,
            extra: ActiveCallArgs(
              roomId: event.roomId,
              partnerId: event.partnerId,
              partnerName: event.partnerName,
              partnerImageUrl: event.partnerImageUrl,
              isCaller: false,
              onRideId: event.onRideId,
            ),
          );
    });
    _callEndedSubscription = realtimeService.callEnded.listen((roomId) {
      final activeRoom = ref.read(activeCallRoomProvider);
      if (activeRoom == roomId && mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });
    Future<void>.microtask(() async {
      await ref.read(localNotificationServiceProvider).initialize();
      try {
        await realtimeService.connect();
      } catch (error) {
        debugPrint('Realtime bootstrap connection failed: $error');
      }
    });
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _callEndedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
