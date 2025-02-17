import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final List<int?> answers;

  const ResultScreen({super.key, required this.answers});

  @override
  Widget build(BuildContext context) {
    int e_c_score = _calculateScore(0, 5);
    int s_l_score = _calculateScore(5, 10);
    int i_g_score = _calculateScore(10, 15);
    int d_m_score = _calculateScore(15, 20);

    // ✅ 점수에 따라 결과 결정 (15점 이상이면 Exploratory 등 / 15점 미만이면 Conservative 등)
    String e_c_result = e_c_score >= 15 ? "Exploratory" : "Conservative";
    String s_l_result = s_l_score >= 15 ? "Fast" : "Slow";
    String i_g_result = i_g_score >= 15 ? "Solo" : "Group";
    String d_m_result = d_m_score >= 15 ? "Bold" : "Mild";

    // ✅ 축약어 형태의 결과 (예: ESID)
    String shortResult =
        "${e_c_result[0]}${s_l_result[0]}${i_g_result[0]}${d_m_result[0]}";

    // ✅ 풀 네임 결과
    String fullResult = "$e_c_result, $s_l_result, $i_g_result, $d_m_result";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "나의 FMBT 는?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ), // ✅ 축약어 결과 표시
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // ✅ 결과 제목 수정 (축약어 추가)
            Text(
              "FMBT 검사 결과: $shortResult",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildScoreTile("E / C (새로운 음식 선호 / 보수적)", e_c_score),
            _buildScoreTile("F / S (식사 속도 빠름 / 느림)", s_l_score),
            _buildScoreTile("S / G (식사 환경 혼밥 / 단체)", i_g_score),
            _buildScoreTile("B / M (맛 선호도 자극 / 순한 맛)", d_m_score),

            const SizedBox(height: 30),

            // ✅ 결과 표시 (풀 영어 버전)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "나는 음식에 있어 \"$fullResult\" 입니다!!",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text("메인 화면으로 돌아가기"),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 점수 계산 함수
  int _calculateScore(int start, int end) {
    return answers
        .sublist(start, end)
        .fold<int>(0, (sum, value) => sum + (value ?? 0));
  }

  // ✅ 각 점수 박스 UI
  Widget _buildScoreTile(String title, int score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "$score 점",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
