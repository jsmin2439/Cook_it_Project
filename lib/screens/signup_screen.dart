import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:son_1/screens/signin_screen.dart';
import 'package:validators/validators.dart';
import 'package:son_1/providers/auth_provider.dart' as myAuthProvider;

import 'main_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _globalKey = GlobalKey<FormState>();
  final TextEditingController _emailEditingController = TextEditingController();
  final TextEditingController _nameEditingController = TextEditingController();
  final TextEditingController _passwordEditingController = TextEditingController();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  bool _isEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _globalKey,
            autovalidateMode: _autovalidateMode,
            child: ListView(
              shrinkWrap: true,
              reverse: true,
              children: [
                // 로고
                SvgPicture.asset(
                  'assets/images/ic_cookit.svg',
                  height: 64,
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                SizedBox(height: 20),

                // 프로필 사진
                Container(
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/images/cookit.png',
                        width: 150,
                        height: 150,

                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // 이메일
                TextFormField(
                  controller: _emailEditingController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty || !isEmail(value.trim())) {
                      return '이메일을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // 이름
                TextFormField(
                  controller: _nameEditingController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.account_circle),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해주세요.';
                    }
                    if (value.length < 3 || value.length > 10) {
                      return '이름은 최소 3글자, 최대 10글자까지 입력 가능합니다.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // 패스워드
                TextFormField(
                  controller: _passwordEditingController,
                  obscureText: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '패스워드를 입력해주세요.';
                    }
                    if (value.length < 6) {
                      return '패스워드는 6글자 이상 입력해주세요.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),

                // 패스워드 확인
                TextFormField(
                  obscureText: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock),
                    filled: true,
                  ),
                  validator: (value) {
                    if (_passwordEditingController.text != value) {
                      return '패스워드가 일치하지 않습니다.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 40),

                // 회원가입 버튼
                ElevatedButton(
                  onPressed: _isEnabled
                      ? () async {
                    final form = _globalKey.currentState;

                    setState(() {
                      _isEnabled = false;
                      _autovalidateMode = AutovalidateMode.always;
                    });

                    if (form == null || !form.validate()) {
                      setState(() {
                        _isEnabled = true; // 유효성 검사 실패 시 버튼 활성화
                      });
                      return;
                    }

                    try {
                      // 회원가입 로직
                      await context.read<myAuthProvider.AuthProvider>().signUp(
                        email: _emailEditingController.text,
                        name: _nameEditingController.text,
                        password: _passwordEditingController.text,
                      );
                    } catch (e) {
                      // 에러 처리
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('회원가입에 실패했습니다: $e')),
                      );
                    } finally {
                      setState(() {
                        _isEnabled = true; // 작업 완료 후 버튼 활성화
                      });
                    }
                  }
                      : null,
                  child: Text('회원가입'),
                  style: ElevatedButton.styleFrom(
                    textStyle: TextStyle(fontSize: 20),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
                SizedBox(height: 10),

                // 로그인 버튼
                TextButton(
                  onPressed: _isEnabled
                      ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SigninScreen(),
                    ),
                  )
                      : null,
                  child: Text(
                    '이미 회원이신가요? 로그인하기',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                SizedBox(height: 20),

                // 비회원 로그인
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(),
                      ),
                    );
                  },
                  child: Text(
                    '비회원 로그인 하기',
                    style: TextStyle(fontSize: 20),
                  ),
                )
              ].reversed.toList(),
            ),
          ),
        ),
      ),
    );
  }
}
