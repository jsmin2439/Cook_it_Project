import 'package:flutter/material.dart';
import 'result_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  _SurveyScreenState createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _currentPage = 0; // 현재 페이지 인덱스
  List<int?> _answers = List.filled(20, null); // 선택된 답변 저장
  final int _questionsPerPage = 5; // 한 페이지당 5개 질문

  // ✅ 페이지별 제목 추가
  final List<String> _pageTitles = [
    "E / C = 새로운 음식 선호 / 불호",
    "F / S = 식사 속도 빠름 / 느림",
    "S / G = 식사 환경 혼밥 / 단체",
    "B / M = 맛 선호도 자극 / 자극 X"
  ];

  // ✅ 질문 리스트 (20개)
  final List<String> _questions = [
    // E / C 관련 질문
    "나는 한 번도 먹어보지 않은 음식을 보면 꼭 시도해보고 싶다.",
    "외국 음식이나 독특한 조리법의 요리를 자주 경험하려 한다.",
    "새로운 레스토랑을 발견하면 직접 가서 먹어보는 것이 즐겁다.",
    "익숙하지 않은 식재료가 들어간 요리를 보면 궁금증이 생긴다.",
    "처음 보는 음식은 맛을 보기 전에 어떤 맛일지 먼저 예상해보는 편이다.",

    // S / L 관련 질문
    "나는 식사할 때 빠르게 먹는 편이다.",
    "나는 식사를 하면서 여러 가지 맛을 충분히 느낀 후에 다음 한 입을 먹는다.",
    "나는 보통 주변 사람들보다 식사를 빨리 끝내는 편이다.",
    "나는 음식이 나오자마자 천천히 준비하고 즐기는 편보다는 바로 먹는 편이다.",
    "음식을 씹는 횟수가 10회 미만이다.",

    // I / G 관련 질문
    "나는 혼자 밥을 먹는 것이 더 편하다.",
    "활발한 환경보다는 조용한 환경을 선호한다.",
    "사람들과 대화하는 것보다 혼자 음악 들으면서 먹는 것을 선호한다.",
    "식당을 선택할 때 혼자 가기 좋은 곳을 선호한다.",
    "가족이나 친구들과 함께하는 식사를 더 중요하게 생각하지 않는다.",

    // D / M 관련 질문
    "나는 매운 음식이나 강한 향신료가 들어간 요리를 좋아한다.",
    "담백하고 부드러운 맛보다는 자극적인 맛을 선호한다.",
    "음식에서 단맛, 신맛, 짠맛 등 다양한 맛을 즐기는 것이 중요하다.",
    "너무 강한 향이 나는 음식(예: 블루치즈, 홍어)을 선호한다.",
    "만약에 간이 잘 맞지 않는다면 어떻게든 소스를 넣으려고 한다."
  ];

  @override
  Widget build(BuildContext context) {
    int startIndex = _currentPage * _questionsPerPage;
    int endIndex = (startIndex + _questionsPerPage > _questions.length)
        ? _questions.length
        : startIndex + _questionsPerPage;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "나의 FMBT 는?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // 뒤로가기
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ✅ 배너 스타일 박스
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD2B48C), // 베이지색 배경
                borderRadius: BorderRadius.circular(10), // 둥근 모서리
              ),
              child: const Column(
                children: [
                  Text(
                    "쉽고 재밌는 나의 식습관 파악하기",
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "나의 FMBT 알아 보기",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ✅ 현재 페이지 제목 표시
            if (_currentPage < _pageTitles.length)
              Text(
                _pageTitles[_currentPage],
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 20),

            // ✅ 현재 페이지 질문 5개 표시
            Expanded(
              child: ListView.builder(
                itemCount: endIndex - startIndex,
                itemBuilder: (context, index) {
                  int questionIndex = startIndex + index;
                  return _buildQuestionTile(
                      _questions[questionIndex], questionIndex);
                },
              ),
            ),

            // ✅ Next 버튼
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                _currentPage == (_questions.length ~/ _questionsPerPage)
                    ? "완료"
                    : "Next",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✅ 다음 페이지로 이동
  void _nextPage() {
    if (_currentPage < (_questions.length ~/ _questionsPerPage) - 1) {
      setState(() {
        _currentPage++;
      });
    } else {
      // 마지막 페이지에서 완료하면 결과 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => ResultScreen(answers: _answers)),
      );
    }
  }

  // ✅ 질문 박스 + 선택지 UI
  Widget _buildQuestionTile(String question, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Text(
          question,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // ✅ 선택지 (5개)
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("그렇지 않다"),
                Text("그렇다"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) => _buildOption(i + 1, index)),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ✅ 선택지 버튼 스타일
  Widget _buildOption(int value, int questionIndex) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _answers[questionIndex] = value;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color:
                _answers[questionIndex] == value ? Colors.blue : Colors.black45,
            width: _answers[questionIndex] == value ? 3 : 1.5, // 선택 시 굵게
          ),
          color: Colors.white,
        ),
      ),
    );
  }
}
