import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/login_page.dart';
import '../../auth/presentation/signup_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const routePath = '/welcome';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    42,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    const Center(child: BrandLogo(size: 68)),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x14F04E29),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'RIDE HAILING',
                        style: TextStyle(
                          color: Color(0xFFF04E29),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Go anywhere without the wait',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF231814),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Book fast city rides, follow your trip live, and move through town with a cleaner Shilota experience.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF7F756F),
                      ),
                    ),
                    const Spacer(),
                    PrimaryButton(
                      label: 'Login',
                      onPressed: () => context.push(LoginPage.routePath),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.push(SignupPage.routePath),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: Color(0xFFF04E29)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
