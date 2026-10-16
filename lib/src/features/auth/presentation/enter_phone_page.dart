import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/auth_shell.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';
import 'auth_submit_state.dart';
import '../../home/presentation/home_shell_page.dart';

class EnterPhonePage extends ConsumerStatefulWidget {
  const EnterPhonePage({
    super.key,
    this.pendingSignup,
  });

  static const routePath = '/phone';
  final PendingSignup? pendingSignup;

  @override
  ConsumerState<EnterPhonePage> createState() => _EnterPhonePageState();
}

class _EnterPhonePageState extends ConsumerState<EnterPhonePage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpRequested = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.pendingSignup?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if ((_phoneController.text.trim()).length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    try {
      await ref.read(authSubmitControllerProvider.notifier).requestOtp(
                phoneNumber: _phoneController.text.trim(),
              );

      if (!mounted) {
        return;
      }

      setState(() {
        _otpRequested = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent. Enter the code to continue.'),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _verifyAndContinue() async {
    if (!_otpRequested) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request an OTP first')),
      );
      return;
    }

    final enteredOtp = _otpController.text.replaceAll(RegExp(r'\D'), '');
    if (enteredOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect OTP')),
      );
      return;
    }

    final pendingSignup = widget.pendingSignup;
    if (pendingSignup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signup data is missing. Start again.')),
      );
      return;
    }

    try {
      await ref.read(authSubmitControllerProvider.notifier).verifyOtp(
            phoneNumber: _phoneController.text.trim(),
            otp: enteredOtp,
          );
      await ref.read(authSubmitControllerProvider.notifier).completeSignup(
            signup: pendingSignup,
            phoneNumber: _phoneController.text.trim(),
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
    final hasOtp = _otpRequested;

    return AuthShell(
      title: hasOtp ? 'Verify your number' : 'Phone verification',
      subtitle: hasOtp
          ? 'Enter the 6-digit code sent to +255 ${_phoneController.text.trim()}.'
          : 'Enter your phone number to receive a one-time code and finish account setup.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFF26B4E), Color(0xFFF04E29)],
                ),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            _OtpInputField(
              controller: _phoneController,
              enabled: !hasOtp,
              hintText: '712 XXX XXX',
              prefix: '+255',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            if (hasOtp) ...[
              _OtpInputField(
                controller: _otpController,
                hintText: '6-digit code',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onFieldSubmitted: (_) => _verifyAndContinue(),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Verify Code',
                isBusy: isBusy,
                onPressed: _verifyAndContinue,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: isBusy ? null : _requestOtp,
                child: const Text('Resend Code'),
              ),
            ] else ...[
              PrimaryButton(
                label: 'Send Code',
                isBusy: isBusy,
                onPressed: _requestOtp,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OtpInputField extends StatelessWidget {
  const _OtpInputField({
    required this.controller,
    required this.hintText,
    this.prefix,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final String? prefix;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onFieldSubmitted,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: hintText,
        prefixText: prefix == null ? null : '$prefix  ',
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
      ),
    );
  }
}
