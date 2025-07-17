//lib/fmbt/fmbt_result_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/fmbt_result.dart';
import '../home/cook_it_main_screen.dart';
import '../allergy_hate_intro_screen.dart';

/// 색상‧테두리 상수는 기존 프로젝트에 이미 정의돼 있으므로 그대로 사용합니다.
const Color kPinkButtonColor = Color(0xFFFFC7B9);
const double kBorderRadius = 16.0;

/// ────────────────────────────────────────────────────────────────
///  🍽️  F M B T   R e s u l t   S c r e e n
/// ────────────────────────────────────────────────────────────────
/// * 기존 결과 화면의 UI‧애니메이션은 유지하면서
/// * 최초 사용자라면 → 하단에 "다음" 버튼을 띄워 알레르기/싫어-재료 인트로로 이동
/// * 일반 사용자라면 → "홈으로 돌아가기" 버튼 유지
///
///  - isFirstUser : true  → Welcome → Survey → Result 로 이어지는 첫 로그인 플로우
///  - isFirstUser : false → 앱 내 어디서든 결과 재확인할 때
///
class ResultScreen extends StatelessWidget {
  final FmbtResult resultData;
  final String userId;
  final String idToken;
  final bool isFirstUser;

  const ResultScreen({
    Key? key,
    required this.resultData,
    required this.userId,
    required this.idToken,
    this.isFirstUser = false,
  }) : super(key: key);

  // ─────────────────────────────────────── build helpers
  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.pink[100]!, Colors.orange[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.assignment_turned_in_rounded,
              size: 50, color: Colors.deepOrange),
          const SizedBox(height: 15),
          Text(
            "진단 완료!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.deepOrange[800],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            resultData.fmbt,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.pink[800],
              fontFamily: 'NanumPen',
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "이 유형의 특징을 확인해보세요! 👇",
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(String name, String label, int score, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.orange[600], size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text("$score 점",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w900)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildScoreGrid(BuildContext context) {
    final s = resultData.scores;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('식습관 지표', style: Theme.of(context).textTheme.titleLarge),
              const Icon(Icons.insights_rounded, color: Colors.blueAccent),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            _buildIndicator(
                'E_C', '식사 성향', s['E_C'] ?? 0, Icons.restaurant_menu),
            _buildIndicator('F_S', '식사 속도', s['F_S'] ?? 0, Icons.speed),
            _buildIndicator('S_G', '식사 환경', s['S_G'] ?? 0, Icons.group),
            _buildIndicator(
                'B_M', '맛 강도', s['B_M'] ?? 0, Icons.local_fire_department),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rate_rounded,
                  color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text('이런 특징이 있어요!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  )),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            resultData.description,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────── main build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍽️ 나의 식습관 진단 결과'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange[300]!, Colors.pink[300]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSummaryCard(context),
            const SizedBox(height: 30),
            _buildScoreGrid(context),
            const SizedBox(height: 25),
            _buildDescriptionCard(),
            const SizedBox(height: 90), // bottom bar 공간
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: _actionButton(context),
      ),
    );
  }

  /// 하단 버튼 (다음 or 홈으로)
  Widget _actionButton(BuildContext context) {
    if (isFirstUser) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPinkButtonColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AllergyHateIntroScreen(
                userId: userId,
                idToken: idToken,
              ),
            ),
          );
        },
        child: const Text('다음', style: TextStyle(fontSize: 18)),
      );
    }

    // 일반 사용자 – 홈으로
    return ElevatedButton.icon(
      icon: const Icon(Icons.home_filled),
      label: const Text('홈으로 돌아가기', style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink[300],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainScreen(
              idToken: idToken,
              userId: userId,
              userEmail: user.email!,
            ),
          ),
          (r) => false,
        );
      },
    );
  }
}
