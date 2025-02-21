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

    // ✅ 점수에 따라 결과 결정
    String e_c_result =
        e_c_score >= 15 ? "Exploratory" : "Conservative"; // 새로운 음식 / 보수적
    String s_l_result = s_l_score >= 15 ? "Fast" : "Slow"; // 식사 속도 빠름 / 느림
    String i_g_result = i_g_score >= 15 ? "Solo" : "Group"; // 혼밥 / 단체
    String d_m_result = d_m_score >= 15 ? "Bold" : "Mild"; // 자극적인 맛 / 순한 맛

    // ✅ 축약어 형태 결과 (예: "EFSG")
    String shortResult =
        "${e_c_result[0]}${s_l_result[0]}${i_g_result[0]}${d_m_result[0]}";

    // ✅ 풀 네임 결과
    String fullResult = "$e_c_result, $s_l_result, $i_g_result, $d_m_result";

    Map<String, String> resultDescriptions = {
      "EFSB": "🌟 혼자서 새로운 맛을 모험하는 도전가!\n\n"
          "당신은 새로운 음식에 호기심이 많고, 한 번도 먹어보지 않은 요리는 꼭 도전해봐야 직성이 풀리는 타입입니다. "
          "신선한 메뉴나 독특한 맛을 찾는 것이 재미있고, 남들이 쉽게 도전하지 않는 강렬한 맛도 마다하지 않습니다. "
          "매운맛, 짠맛, 강한 향이 있는 음식도 거리낌 없이 즐깁니다.",
      "EFSM": "🌿 혼자서 새로운 음식을 탐험하는 미식가!\n\n"
          "자극적인 맛보다는 부드럽고 담백한 요리를 즐기는 편입니다. "
          "새로운 식재료를 경험하는 것을 좋아하지만, 너무 강한 맛보다는 은은한 감칠맛이 나는 요리를 선호합니다. "
          "웰빙 음식, 건강식, 채소 위주의 식단을 자주 선택하는 경향이 있습니다.",
      "EFGB": "🍽 친구들과 함께 미식 탐험을 떠나는 미각 리더!\n\n"
          "새로운 맛에 대한 두려움이 없으며, 사람들이 잘 모르는 숨은 맛집을 찾아다니는 걸 즐깁니다. "
          "매운맛, 향신료가 강한 음식, 전통 요리보다 퓨전 요리를 선호하는 경우가 많습니다. "
          "다양한 음식 문화에 관심이 많으며, 해외여행을 가면 현지 음식을 꼭 경험하는 스타일입니다.",
      "EFGM": "🍷 새로운 음식을 즐기지만 조화로운 맛을 선호하는 타입!\n\n"
          "자극적이지 않은 부드러운 맛을 즐기면서도 새로운 요리를 경험하는 것에 거부감이 없습니다. "
          "건강을 고려하여 순한 맛을 선택하는 경우가 많으며, 식재료 본연의 맛을 살린 음식들을 좋아합니다. "
          "한식보다는 서양식, 샐러드, 스프류의 요리를 자주 먹습니다.",
      "CFSB": "🍖 혼자 먹는 것이 편하고, 강한 맛을 선호하는 미식가!\n\n"
          "익숙한 음식 중에서도 강렬한 맛을 좋아하는 편입니다. "
          "짠맛, 매운맛, 감칠맛이 강한 요리를 즐기며, 한 번 맛을 들인 음식은 자주 반복해서 먹습니다. "
          "햄버거, 치킨, 짜장면 같은 패스트푸드를 선호하는 경향이 있습니다.",
      "CFSM": "🍚 혼밥을 즐기며 담백한 맛을 선호하는 타입!\n\n"
          "평소 익숙한 요리를 선호하며, 순한 맛의 가정식을 자주 찾습니다. "
          "외식을 하더라도 크게 자극적이지 않은 메뉴를 선택하는 편이며, 국물 요리나 한식에 익숙합니다. "
          "밥과 함께 먹는 반찬 위주의 식사를 즐깁니다.",
      "CFGB": "🍛 단체 식사를 즐기고 강한 맛을 좋아하는 유형!\n\n"
          "친구들과 함께 먹는 걸 좋아하며, 외식할 때는 매운 요리, 양념이 강한 음식, 자극적인 맛을 찾는 경우가 많습니다. "
          "삼겹살, 떡볶이, 치킨, 족발처럼 한국식 양념이 강한 음식들을 선호합니다. "
          "소셜 다이닝을 즐기고, 함께 음식을 나누는 문화를 좋아하는 스타일입니다.",
      "CFGM": "🥗 친구들과 함께 익숙한 요리를 즐기는 타입!\n\n"
          "건강하고 순한 맛을 선호하며, 사람들과 함께 먹을 때도 익숙한 메뉴를 선택하는 경우가 많습니다. "
          "한식, 가정식, 웰빙 음식, 저자극적인 요리를 선호하는 경향이 있습니다.",
      "ESFB": "🔥 강한 맛을 두려워하지 않는 혼밥 모험가!\n\n"
          "혼자서도 새로운 음식을 도전하는 것을 즐기며, 매운맛과 강한 향의 음식을 선호하는 경향이 있습니다. "
          "길거리 음식이나 해외 음식에도 관심이 많으며, 다양한 향신료를 사용한 요리를 선호합니다.",
      "ESFM": "🍽 혼자서도 차분하게 새로운 음식을 탐색하는 미식가!\n\n"
          "강한 맛보다는 부드럽고 조화로운 맛을 좋아하며, 새로운 음식이라도 너무 자극적이지 않다면 쉽게 시도하는 편입니다. "
          "건강을 고려한 식단을 선호하며, 자연식 위주의 메뉴를 선택하는 경우가 많습니다.",
      "ESGB": "🥘 강렬한 맛을 즐기고 새로운 경험을 중요하게 여기는 유형!\n\n"
          "새로운 요리에 대한 도전 정신이 강하며, 향이 강한 세계 요리나 이국적인 음식을 즐기는 경향이 있습니다. "
          "인도 요리, 태국 요리, 멕시코 요리 같은 다채로운 음식을 시도하는 걸 좋아합니다.",
      "ESGM": "🍵 새로운 음식을 경험하면서도 부드러운 맛을 즐기는 타입!\n\n"
          "한식이나 유럽식 요리를 선호하며, 너무 강한 향이나 자극적인 맛보다는 재료 본연의 맛을 즐깁니다. "
          "가벼운 요리, 깔끔한 한식, 샐러드와 같은 음식을 선호합니다.",
      "CSFB": "🍜 익숙한 음식 중에서도 강한 맛을 선호하는 전통 미식가!\n\n"
          "보편적인 음식 중에서도 양념이 강한 요리를 선호하는 편입니다. "
          "특히 한국식 매운맛, 달짝지근한 맛을 즐기며, 매운 라면, 불닭, 짬뽕 같은 음식을 자주 먹습니다.",
      "CSFM": "🍚 익숙한 음식과 순한 맛을 선호하는 가정식 마니아!\n\n"
          "어릴 때부터 먹던 익숙한 음식을 가장 선호하며, 자극적인 맛보다는 조화롭고 담백한 음식을 선택하는 경우가 많습니다. "
          "된장찌개, 백숙, 나물 요리 등 한식 스타일의 건강식을 자주 찾습니다.",
      "CSGB": "🍗 친구들과 익숙한 맛을 즐기는 정통파 미식가!\n\n"
          "친구들과 외식할 때 늘 가던 단골집을 선호하며, 큰 변화 없이 익숙한 메뉴를 고르는 경우가 많습니다. "
          "전통적인 한국 요리나 특정 브랜드의 메뉴를 꾸준히 먹는 스타일입니다.",
      "CSGM": "🥦 익숙한 음식과 건강한 맛을 함께 즐기는 타입!\n\n"
          "자극적이지 않고 균형 잡힌 맛을 중요하게 여기며, 가벼운 음식과 신선한 식재료를 선호하는 편입니다. "
          "샐러드, 닭가슴살, 죽, 연어 같은 건강식이 주요 선택지입니다.",
    };

    // ✅ 결과 설명 가져오기
    String resultDescription = resultDescriptions[shortResult] ??
        "자신만의 독특한 식습관을 가진 당신! 다양한 음식 경험을 쌓으며, 자신만의 스타일을 찾아가고 있습니다.";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "나의 FMBT 는?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // ✅ FMBT 검사 결과 제목
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

            // ✅ 풀 네임 결과 (배경색 유지)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink[200], // 유지됨
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

            const SizedBox(height: 20),

            // ✅ 결과 설명 (첫 줄 Bold, 나머지는 일반 글씨)
            Text.rich(
              TextSpan(
                children: [
                  // 첫 번째 줄 (유형 제목) -> Bold 유지
                  TextSpan(
                    text: resultDescription.split("\n\n")[0] + "\n\n",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  // 나머지 설명 부분 -> 일반 글씨
                  TextSpan(
                    text:
                        resultDescription.split("\n\n").sublist(1).join("\n\n"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            // ✅ 메인 화면으로 돌아가기 버튼
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
