import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:son_1/providers/auth_state.dart';
import 'package:son_1/screens/signin_screen.dart';

import 'main_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authStatus = context.watch<AuthState>().authStatus;

    if (authStatus == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_){
        Navigator.push(context, MaterialPageRoute(builder: (context) => MainScreen(),
        ),
        );
      });
    } else if (authStatus == AuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SigninScreen(),
          ),
        );
      });
    }
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}