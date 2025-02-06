/*
// 예시 색상 (오렌지톤 버튼용)
const Color kButtonColor = Color(0xFFF7C15E);
const Color kHintBorderColor = Colors.black54;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoginScreen(), // 시작 화면을 로그인 화면으로
  ));
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색을 흰색으로 설정
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // 키보드 열릴 때 화면 스크롤이 가능하도록
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1) 상단 여백
                  const SizedBox(height: 40),

                  // 2) 타이틀 "Cook it !!"
                  const Text(
                    "Cook it !!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 3) 첫 번째 텍스트필드: 사용자 이름 또는 이메일
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined),
                      hintText: "사용자 이름 또는 이메일",
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kHintBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black87, width: 2),
                      ),
                      // 레이블이나 힌트 스타일
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4) 두 번째 텍스트필드: 비밀번호
                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: "비밀 번호",
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: kHintBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black87, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 5) 로그인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 3,
                      ),
                      onPressed: () {
                        // 로그인 로직
                      },
                      child: const Text(
                        "로그인",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 6) 회원가입 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 3,
                      ),
                      onPressed: () {
                        // 회원가입 로직
                      },
                      child: const Text(
                        "회원이 아니신가요? 회원가입 하기",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
 */

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'Cook_it_main.dart';

class CookItLogin extends StatefulWidget {
  const CookItLogin({Key? key}) : super(key: key);

  @override
  _CookItLoginState createState() => _CookItLoginState();
}

class _CookItLoginState extends State<CookItLogin> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 입력 유효성 검사 메서드
  bool _validateInputs() {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog("이메일과 비밀번호를 모두 입력해주세요.");
      return false;
    }
    return true;
  }

  // 에러 다이얼로그 메서드
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          )
        ],
      ),
    );
  }

  // 메인 화면으로 이동
  void _moveToMainScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  // 구글 로그인
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _moveToMainScreen();
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  // 이메일 회원가입
  Future<void> _signUpWithEmailAndPassword() async {
    if (!_validateInputs()) return;

    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _moveToMainScreen();
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(_getErrorMessage(e));
    }
  }

  // 이메일 로그인
  Future<void> _signInWithEmailAndPassword() async {
    if (!_validateInputs()) return;

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _moveToMainScreen();
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(_getErrorMessage(e));
    }
  }

  // 애플 로그인
  Future<void> _signInWithApple() async {
    if (Theme.of(context).platform != TargetPlatform.iOS) {
      _showErrorDialog("애플 로그인은 iOS에서만 지원됩니다.");
      return;
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      await _auth.signInWithCredential(oauthCredential);
      _moveToMainScreen();
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  // 에러 메시지 처리 메서드
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return '비밀번호가 너무 쉽습니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'user-not-found':
        return '해당 사용자를 찾을 수 없습니다.';
      case 'wrong-password':
        return '비밀번호가 일치하지 않습니다.';
      default:
        return '로그인 중 오류가 발생했습니다: ${e.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cook It - 로그인'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _signInWithEmailAndPassword,
                  child: const Text('로그인'),
                ),
                ElevatedButton(
                  onPressed: _signUpWithEmailAndPassword,
                  child: const Text('회원가입'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signInWithGoogle,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('구글 로그인'),
            ),
            if (Theme.of(context).platform == TargetPlatform.iOS)
              SignInWithAppleButton(
                onPressed: _signInWithApple,
              ),
          ],
        ),
      ),
    );
  }
}
