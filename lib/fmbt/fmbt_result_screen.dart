import 'package:flutter/material.dart';
import '../model/fmbt_result.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/cook_it_main_screen.dart';

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
        title: const Text("🍽️ 나의 식습관 진단 결과",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            )),
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 결과 요약 카드
              _buildResultCard(fmbtType, context),
              const SizedBox(height: 30),

              // 점수 표시 섹션
              _buildScoreSection(
                e_c_score,
                f_s_score,
                s_g_score,
                b_m_score,
                context,
              ),
              const SizedBox(height: 25),

              // 상세 설명
              _buildDescriptionCard(description),
              const SizedBox(height: 25),

              // 메인 화면 버튼
              _buildReturnButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(String fmbtType, BuildContext context) {
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
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            fmbtType,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.pink[800],
              fontFamily: 'NanumPen',
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "이 유형의 특징을 확인해보세요! 👇",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection(int e, int f, int s, int b, BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("식습관 지표", style: Theme.of(context).textTheme.titleLarge),
              Icon(Icons.insights_rounded, color: Colors.blue[300]),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            _buildScoreItem("E_C", "식사 성향", e, Icons.restaurant_menu),
            _buildScoreItem("F_S", "식사 속도", f, Icons.speed),
            _buildScoreItem("S_G", "식사 환경", s, Icons.group),
            _buildScoreItem("B_M", "맛 강도", b, Icons.local_fire_department),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreItem(String code, String label, int score, IconData icon) {
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
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 5),
                Text("$score 점",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w900,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
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
              Icon(Icons.star_rate_rounded, color: Colors.amber[400], size: 28),
              const SizedBox(width: 10),
              Text("이런 특징이 있어요!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[800],
                  )),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            desc,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.6,
            ),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }

  Widget _buildReturnButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.home_filled, size: 22),
        label: const Text("홈으로 돌아가기",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.pink[300],
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 3,
          shadowColor: Colors.pink[100],
        ),
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
      ),
    );
  }
}
