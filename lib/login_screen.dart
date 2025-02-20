import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'signup_screen.dart';
import 'Cook_it_main.dart';

const Color kButtonColor = Color(0xFFF7C15E);
const Color kHintBorderColor = Colors.black54;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 이메일 로그인 및 서버 검증
  Future<void> _login() async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String? idToken = await userCredential.user?.getIdToken();
      if (idToken != null) {
        await _verifyLoginWithServer(idToken);
        print("ID 토큰: $idToken");
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("로그인 실패: ${e.message}")),
      );
    }
  }

  // 서버에 ID 토큰 검증 요청
  Future<void> _verifyLoginWithServer(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse("http://172.30.1.26:3000/api/verify-login"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken" // Bearer 토큰 추가
        },
        body: jsonEncode({"idToken": idToken}),
      );

      if (response.statusCode == 200) {
        print("서버 로그인 성공: ${response.body}");
        final responseData = jsonDecode(response.body);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(
              idToken: idToken,
              userId: responseData['uid'], // 서버 응답에서 uid 추출
              userEmail: _emailController.text.trim(),
            ),
          ),
        );
      } else {
        print("서버 로그인 실패: ${response.body}");
      }
    } catch (e) {
      print("서버 요청 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "Cook it !!",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  _buildInputField(
                    controller: _emailController,
                    hintText: "이메일 입력",
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    controller: _passwordController,
                    hintText: "비밀번호 입력",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 30),
                  _buildButton("로그인", _login),
                  const SizedBox(height: 20),
                  _buildButton("회원가입", () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignupScreen()));
                  }),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
      {required TextEditingController controller,
      required String hintText,
      required IconData icon,
      bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hintText,
        border: const OutlineInputBorder(),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: kHintBorderColor)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black87, width: 2)),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kButtonColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 3,
        ),
        onPressed: onPressed,
        child: Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
      ),
    );
  }
}
