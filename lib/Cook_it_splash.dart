import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediapipe_2/login_screen.dart';
import 'Cook_it_main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 설정 (2초 동안 0.0 -> 1.0)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // 곡선 애니메이션 (EaseOut 등)
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // 컨트롤러 재생
    _controller.forward();

    // 애니메이션이 끝나면 메인 화면으로 이동
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 0.5초 정도 대기 후 메인 화면으로 이동
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // FadeTransition + ScaleTransition을 중첩해서
        // 로고와 텍스트를 동시에 페이드인/스케일업
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 크기 확대
                Image.asset(
                  'assets/images/cookie.png',
                  width: 300,
                  height: 300,
                ),
                const SizedBox(height: 20),
                Image.asset('assets/images/CookIT.png', width: 180, height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
