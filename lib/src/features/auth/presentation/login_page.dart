import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/auth_shell.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import 'auth_submit_state.dart';
import '../../home/presentation/home_shell_page.dart';
import 'signup_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static const routePath = '/login';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    try {
      await ref.read(authSubmitControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) {
        return;
      }

      context.go(HomeShellPage.routePath);
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(authSubmitControllerProvider);

    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Log in to continue your journey.',
      footer: Wrap(
        spacing: 6,
        alignment: WrapAlignment.center,
        children: [
          const Text("Don't have an account?"),
          GestureDetector(
            onTap: () => context.push(SignupPage.routePath),
            child: const Text(
              'Sign Up',
              style: TextStyle(
                color: Color(0xFFF04E29),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuthField(
              controller: _emailController,
              hintText: 'Email Address',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.mail_outline_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email cannot be empty';
                }
                if (!value.trim().contains('@')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _AuthField(
              controller: _passwordController,
              hintText: 'Password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              prefixIcon: Icons.lock_outline_rounded,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF7F756F),
                ),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Password cannot be empty'
                  : null,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Log In',
              isBusy: isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF8F5F3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF04E29)),
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: const Color(0xFF8A7A73))
            : null,
        suffixIcon: suffix,
      ),
    );
  }
}
