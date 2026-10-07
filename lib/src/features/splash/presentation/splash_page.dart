import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../home/presentation/home_shell_page.dart';
import '../../welcome/presentation/welcome_page.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  static const routePath = '/';

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final session = ref.read(sessionStorageProvider);
    if (!mounted) {
      return;
    }
    context.go(
        session.isLoggedIn ? HomeShellPage.routePath : WelcomePage.routePath);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF04E29),
      body: Center(
        child: BrandLogo(size: 92, white: true),
      ),
    );
  }
}
