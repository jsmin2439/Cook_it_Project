import 'dart:async';
import 'package:flutter/material.dart';
import 'fmbt_survey_screen.dart';
import '../home/cook_it_main_screen.dart';

/// 색상/스타일은 기존 상수 재활용 (예: kPinkButtonColor 등)
const Color kPinkButtonColor = Color(0xFFFFC7B9);
const double kBorderRadius = 16.0;

class WelcomeFmbtScreen extends StatefulWidget {
  final String userId; // 사용자 UID
  final String idToken; // Firebase 인증 토큰
  final String userEmail; // 사용자 이메일

  const WelcomeFmbtScreen({
    Key? key,
    required this.userId,
    required this.idToken,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<WelcomeFmbtScreen> createState() => _WelcomeFmbtScreenState();
}

class _WelcomeFmbtScreenState extends State<WelcomeFmbtScreen> {
  /// 차례대로 보여줄 문구
  final List<String> _lines = [
    "처음 오셨군요? 환영합니다!",
    "나의 식습관 좌표를 알 수 있는\nFMBT 검사를 진행해볼까요?"
  ];

  /// 각 문구의 표시 여부 (AnimatedOpacity 사용)
  late List<bool> _linesVisible;

  @override
  void initState() {
    super.initState();
    _linesVisible = List.filled(_lines.length, false);
    _revealTextsSequentially();
  }

  /// 문구를 하나씩 시간차로 보여주는 함수
  Future<void> _revealTextsSequentially() async {
    for (int i = 0; i < _lines.length; i++) {
      // 약간의 지연 후 해당 라인 표시
      await Future.delayed(const Duration(milliseconds: 900));
      setState(() => _linesVisible[i] = true);
    }
  }

  /// "검사하기" 버튼 → SurveyScreen 이동
  void _goToSurvey() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyScreen(
          userId: widget.userId,
          idToken: widget.idToken,
          isFirstLogin: true,
        ),
      ),
    );
  }

  /// "건너뛰기" 버튼 → MainScreen 이동
  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          userId: widget.userId,
          idToken: widget.idToken,
          userEmail: widget.userEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색 (필요 시 변경)
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0), // 좌우 여백 증가
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1) 첫 문구
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _linesVisible[0] ? 1.0 : 0.0,
                child: Text(
                  _lines[0],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28, // 조금 더 크게
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 2) 두 번째 문구
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _linesVisible[1] ? 1.0 : 0.0,
                child: Text(
                  _lines[1],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22, // 조금 더 크게
                    height: 1.4, // 줄간격 살짝
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // 버튼 2개 (문구 모두 표시된 뒤에만)
              if (_linesVisible.every((v) => v == true))
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPinkButtonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                      onPressed: _goToSurvey,
                      child: const Text(
                        "검사하기",
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 20),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[800],
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                      onPressed: _skip,
                      child: const Text(
                        "건너뛰기",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
