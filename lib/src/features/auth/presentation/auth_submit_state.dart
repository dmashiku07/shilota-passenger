import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

final authSubmitControllerProvider =
    AutoDisposeNotifierProvider<AuthSubmitController, bool>(
        AuthSubmitController.new);

class AuthSubmitController extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = true;
    try {
      await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
    } finally {
      state = false;
    }
  }

  Future<AuthResponse> requestOtp({
    required String phoneNumber,
  }) async {
    state = true;
    try {
      return await ref.read(authRepositoryProvider).requestOtp(
            phoneNumber: phoneNumber,
          );
    } finally {
      state = false;
    }
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    state = true;
    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            phoneNumber: phoneNumber,
            otp: otp,
          );
    } finally {
      state = false;
    }
  }

  Future<void> completeSignup({
    required PendingSignup signup,
    required String phoneNumber,
  }) async {
    state = true;
    try {
      await ref.read(authRepositoryProvider).completeSignup(
            signup: signup,
            phoneNumber: phoneNumber,
          );
    } finally {
      state = false;
    }
  }
}
