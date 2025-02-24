import 'package:flutter/material.dart';
import 'models/fmbt_result.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Cook_it_main.dart';

/// FMBT 결과 화면
class ResultScreen extends StatelessWidget {
  final FmbtResult resultData;
  final String userId; // 사용자 UID
  final String idToken; // Firebase 인증 토큰

  const ResultScreen({
    Key? key,
    required this.resultData,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 점수들
    final int e_c_score = resultData.scores["E_C"] ?? 0;
    final int f_s_score = resultData.scores["F_S"] ?? 0;
    final int s_g_score = resultData.scores["S_G"] ?? 0;
    final int b_m_score = resultData.scores["B_M"] ?? 0;

    // 최종 코드
    final String fmbtType = resultData.fmbt;
    // 설명
    final String description = resultData.description;

    return Scaffold(
      appBar: AppBar(
        title: const Text("나의 FMBT 는?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              "FMBT 검사 결과: $fmbtType",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildScoreTile("E_C (새로운 음식 / 보수적)", e_c_score),
            _buildScoreTile("F_S (식사 속도 빠름 / 느림)", f_s_score),
            _buildScoreTile("S_G (식사 환경 혼밥 / 단체)", s_g_score),
            _buildScoreTile("B_M (맛 선호도 자극 / 순함)", b_m_score),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "당신의 FMBT 유형은\n\"$fmbtType\" 입니다!!",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // 모든 이전 화면 제거 후 메인으로 이동
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainScreen(
                        idToken: idToken, // widget. 제거
                        userId: userId, // widget. 제거
                        userEmail: user.email!,
                      ),
                    ),
                    (route) => false,
                  );
                }
              },
              child: const Text("메인 화면으로 돌아가기"),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreTile(String title, int score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("$score 점",
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}
