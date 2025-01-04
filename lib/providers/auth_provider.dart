import 'dart:typed_data';

import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:son_1/providers/auth_state.dart';
import 'package:son_1/repositories/auth_repository.dart';

class AuthProvider extends StateNotifier<AuthState> with LocatorMixin {
  AuthProvider() : super(AuthState.init());

  Future<void> signUp({
    required String email,
    required String name,
    required String password,
  }) async {

    await read<AuthRepository>().signUp(
        email: email,
        name: name,
        password: password
    );
  }
}