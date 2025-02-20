import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Cook_it_splash.dart'; // SplashScreen import 추가
import 'dart:async';
import 'login_screen.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';

void main() async {
  bool firebaseInitialized = false;

  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('Flutter binding 초기화 완료');

    await Future.delayed(Duration(seconds: 1)); // 플랫폼 채널 초기화 대기

    print('Firebase 옵션 확인 중...');
    final options = DefaultFirebaseOptions.currentPlatform;
    print('Firebase 옵션: ${options.toString()}');

    print('Firebase 초기화 시도...');
    await Firebase.initializeApp(
      options: options,
    ).timeout(
      Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('Firebase 초기화 시간 초과');
      },
    );

    firebaseInitialized = true;
    print('Firebase 초기화 성공');
  } on TimeoutException catch (e) {
    print('초기화 시간 초과: $e');
  } on PlatformException catch (e) {
    print('플랫폼 예외: ${e.message}');
    print('코드: ${e.code}');
    print('상세: ${e.details}');
  } catch (e, stack) {
    print('기타 예외: $e');
    print('스택 트레이스: $stack');
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;

  const MyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    if (!firebaseInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Firebase 초기화 실패'),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
