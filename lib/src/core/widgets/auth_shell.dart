import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'brand_logo.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFF6F2),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 40,
                  child: canPop
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                const Center(child: BrandLogo(size: 42)),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF231814),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF7F756F),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: child,
                ),
                if (footer != null) ...[
                  const SizedBox(height: 18),
                  Center(child: footer!),
                ],
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    AppConfig.appName,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7F756F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
