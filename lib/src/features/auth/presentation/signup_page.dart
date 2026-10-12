import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/auth_shell.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';
import 'auth_submit_state.dart';
import 'enter_phone_page.dart';
import 'login_page.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  static const routePath = '/signup';

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final signup = PendingSignup(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    context.push(
      EnterPhonePage.routePath,
      extra: signup.copyWithPhone(_phoneController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(authSubmitControllerProvider);

    return AuthShell(
      title: 'Create your account',
      subtitle:
          'Setup your profile once and start booking rides, tracking trips, and moving faster around town.',
      footer: Wrap(
        spacing: 6,
        alignment: WrapAlignment.center,
        children: [
          const Text('Already have an account?'),
          GestureDetector(
            onTap: () => context.push(LoginPage.routePath),
            child: const Text(
              'Log In',
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
            const Center(child: BrandLogo(size: 34)),
            const SizedBox(height: 16),
            _AuthEntryField(
              controller: _nameController,
              hintText: 'Full Name',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().length < 3)
                  ? 'Full name should be at least 3 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            _AuthEntryField(
              controller: _phoneController,
              hintText: 'Phone Number',
              prefixWidget: const _PhonePrefix(),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(
                  9,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                ),
              ],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || !RegExp(r'^\d{9}$').hasMatch(value.trim()))
                      ? 'Enter a valid phone number'
                      : null,
            ),
            const SizedBox(height: 12),
            _AuthEntryField(
              controller: _emailController,
              hintText: 'Email Address',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Email cannot be empty'
                  : null,
            ),
            const SizedBox(height: 12),
            _AuthEntryField(
              controller: _passwordController,
              hintText: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) => (value == null || value.trim().length < 6)
                  ? 'Password should have at least 6 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            _AuthEntryField(
              controller: _referralController,
              hintText: 'Referral Code (Optional)',
              prefixIcon: Icons.sell_outlined,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Create Account',
              isBusy: isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

extension on PendingSignup {
  PendingSignup copyWithPhone(String phoneNumber) {
    return PendingSignup(
      fullName: fullName,
      email: email,
      password: password,
      countryCode: countryCode,
      phoneNumber: phoneNumber,
    );
  }
}

class _AuthEntryField extends StatelessWidget {
  const _AuthEntryField({
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.prefixWidget,
    this.keyboardType,
    this.inputFormatters,
    this.autovalidateMode,
    this.textInputAction,
    this.validator,
    this.suffix,
    this.obscureText = false,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? prefixWidget;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final bool obscureText;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autovalidateMode: autovalidateMode,
      textInputAction: textInputAction,
      validator: validator,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF8F5F3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFF04E29)),
        ),
        prefixIcon: prefixWidget ??
            (prefixIcon != null
                ? Icon(prefixIcon, color: const Color(0xFF8A7A73))
                : null),
        suffixIcon: suffix,
      ),
    );
  }
}

class _PhonePrefix extends StatelessWidget {
  const _PhonePrefix();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 94,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_outlined, color: Color(0xFF8A7A73)),
          SizedBox(width: 8),
          Text(
            '+255',
            style: TextStyle(
              color: Color(0xFF231814),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
