import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'result_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  _SurveyScreenState createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _currentPage = 0;
  List<int?> _answers = List.filled(20, null);
  final int _questionsPerPage = 5;

  // Firebase data
  List<String> _pageTitles = [];
  List<String> _questions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchSurveyData();
  }

  Future<void> _fetchSurveyData() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('questions').get();

      // Temporary storage
      final List<String> tempTitles = [];
      final List<String> tempQuestions = [];

      // Process documents in order
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        tempTitles.add(data['category']);
        tempQuestions.addAll(List<String>.from(data['questions']));
      }

      setState(() {
        _pageTitles = tempTitles;
        _questions = tempQuestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '데이터를 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Text(_errorMessage),
        ),
      );
    }
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
