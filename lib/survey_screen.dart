import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/fmbt_result.dart'; // 추가
import 'result_screen.dart';

/// 설문 화면
class SurveyScreen extends StatefulWidget {
  final String userId; // 사용자 UID
  final String idToken; // Firebase 인증 토큰
  final bool isFirstLogin; // 추가

  const SurveyScreen({
    Key? key,
    required this.userId, // required 추가
    required this.idToken, // required 추가
    this.isFirstLogin = false,
  }) : super(key: key);

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  // 페이지 관련
  int _currentPage = 0;
  final int _questionsPerPage = 5;

  // 사용자의 답변(20문항)
  List<int?> _answers = List.filled(20, null);
  // 해당 문항이 미답변인지 여부
  List<bool> _isUnanswered = List.filled(20, false);

  // 질문 텍스트
  List<String> _pageTitles = []; // 각 페이지 타이틀(4개 정도)
  List<String> _questions = []; // 전체 질문(20개)

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// 초기 데이터 로드 (Firestore: userDoc, questions)
  Future<void> _initializeData() async {
    try {
      await _initializeUserDocument(); // userDoc 생성(없으면)
      await _fetchSurveyData(); // 질문 & 카테고리 로드
      await _loadExistingResponses(); // 기존 응답 로드
    } catch (e) {
      setState(() {
        _errorMessage = '데이터 불러오기 실패: $e';
        _isLoading = false;
      });
    }
  }

  /// Firestore에서 설문 'questions' 컬렉션 로드
  Future<void> _fetchSurveyData() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('questions').get();

    final List<String> tempTitles = [];
    final List<String> tempQuestions = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      tempTitles.add(data['category']); // 페이지 타이틀
      tempQuestions.addAll(List<String>.from(data['questions'])); // 질문 여러개
    }

    setState(() {
      _pageTitles = tempTitles; // ["페이지1","페이지2",...]
      _questions = tempQuestions; // 총 20개의 질문
      _isLoading = false;
    });
  }

  /// Firestore에서 기존 응답 로드 (responses-1,2,3,4)
  Future<void> _loadExistingResponses() async {
    final userDoc =
        FirebaseFirestore.instance.collection('user').doc(widget.userId);

    final docSnap = await userDoc.get();
    if (docSnap.exists) {
      final data = docSnap.data() as Map<String, dynamic>;
      for (int page = 1; page <= 4; page++) {
        final responses = data['responses-$page'] as List<dynamic>?;
        if (responses != null) {
          int startIndex = (page - 1) * 5;
          for (int i = 0; i < responses.length; i++) {
            _answers[startIndex + i] = responses[i] != 0 ? responses[i] : null;
          }
        }
      }
      setState(() {});
    }
  }

  /// 만약 user 문서가 없으면 초기화
  Future<void> _initializeUserDocument() async {
    final userDoc =
        FirebaseFirestore.instance.collection('user').doc(widget.userId);

    final docSnap = await userDoc.get();
    if (!docSnap.exists) {
      await userDoc.set({
        'responses-1': List.filled(5, 0),
        'responses-2': List.filled(5, 0),
        'responses-3': List.filled(5, 0),
        'responses-4': List.filled(5, 0),
      });
    }
  }

  /// 전체 답변을 Firestore에 저장 (완료 시 호출)
  Future<void> _saveAnswersToFirestore() async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('user').doc(widget.userId);

      // 4페이지 (각 페이지 5개)
      Map<String, dynamic> responsesData = {};
      for (int page = 0; page < 4; page++) {
        int startIndex = page * 5;
        final pageAnswers = _answers
            .sublist(startIndex, startIndex + 5)
            .map((a) => a ?? 0)
            .toList();
        responsesData['responses-${page + 1}'] = pageAnswers;
      }

      // merge:true 로 기존 필드 유지
      await userDoc.set(responsesData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore 저장 오류: $e");
    }
  }

  /// "완료" 버튼 시 서버에게 GET 요청 -> FMBT 결과 받기
  Future<void> _requestFmbtResult() async {
    try {
      final uri = Uri.parse(
        'http://jsmin2439.iptime.org:3000/api/calculate-fmbt?userId=${widget.userId}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.idToken}',
        },
      );

      debugPrint('서버 응답: ${response.body}'); // 디버깅용 로그 추가

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);

        if (responseJson['success'] == true) {
          // null 체크 추가
          final fmbt = responseJson['fmbt']?.toString();
          if (fmbt == null) throw Exception('FMBT 값이 없습니다');

          final scores = responseJson['scores'];
          if (scores == null) throw Exception('점수 데이터가 없습니다');

          final desc = responseJson['description']?.toString();
          if (desc == null) throw Exception('설명 데이터가 없습니다');

          // 데이터 변환
          final scoresMap = Map<String, int>.from(scores);

          // FmbtResult 객체 생성
          final resultData = FmbtResult(
            fmbt: fmbt,
            scores: scoresMap,
            description: desc,
          );

          // 결과 화면으로 이동
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                resultData: resultData,
                userId: widget.userId,
                idToken: widget.idToken,
              ),
            ),
          );
        } else {
          throw Exception(responseJson['error'] ?? 'FMBT 계산 실패');
        }
      } else {
        throw Exception('서버 오류 (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint("❌ FMBT 계산 요청 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("FMBT 계산 중 오류가 발생했습니다: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// "다음" or "완료" 버튼 클릭
  Future<void> _nextPage() async {
    // 현재 페이지 질문 인덱스 (예: 페이지0->0..4)
    final currentPageQuestions = List.generate(
      _questionsPerPage,
      (idx) => _currentPage * _questionsPerPage + idx,
    );

    // 해당 페이지 중 null 있으면 빨간색 표시
    bool hasUnanswered =
        currentPageQuestions.any((idx) => _answers[idx] == null);
    if (hasUnanswered) {
      setState(() {
        for (int idx in currentPageQuestions) {
          _isUnanswered[idx] = _answers[idx] == null;
        }
      });
      return; // 페이지 이동 중단
    }

    // 아직 마지막 페이지가 아니면 _currentPage++ 후 setState
    if (_currentPage < (_questions.length ~/ _questionsPerPage) - 1) {
      setState(() {
        _currentPage++;
      });
    } else {
      // 마지막 페이지 -> Firestore 저장 후 서버에 GET 요청
      await _saveAnswersToFirestore();
      await _requestFmbtResult();
    }
  }

  /// 개별 문항 선택 시 즉시 Firestore에 저장 (단일 업데이트)
  Future<void> _saveSingleAnswer(int questionIndex, int? value) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('user').doc(widget.userId);

      final pageNumber = (questionIndex ~/ 5) + 1; // 1~4
      final indexInPage = questionIndex % 5; // 0~4

      final docSnap = await userDoc.get();
      List<dynamic> current = docSnap.exists
          ? (docSnap.data() as Map<String, dynamic>)['responses-$pageNumber'] ??
              List.filled(5, 0)
          : List.filled(5, 0);

      final updated = List<int>.from(current);
      updated[indexInPage] = value ?? 0;

      await userDoc.set({
        'responses-$pageNumber': updated,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("단일 저장 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(child: Text(_errorMessage)),
      );
    }

    final startIndex = _currentPage * _questionsPerPage;
    final endIndex = startIndex + _questionsPerPage;

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
          children: [
            _buildBanner(),
            const SizedBox(height: 20),

            if (_currentPage < _pageTitles.length)
              Text(
                _pageTitles[_currentPage],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 20),

            // 현재 페이지 질문들
            Expanded(
              child: ListView.builder(
                itemCount: endIndex - startIndex,
                itemBuilder: (context, idx) {
                  final questionIndex = startIndex + idx;
                  final questionText = _questions[questionIndex];
                  return _buildQuestionTile(questionText, questionIndex);
                },
              ),
            ),

            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                _currentPage == (_questions.length ~/ _questionsPerPage) - 1
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

  /// 상단 배너
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFD2B48C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        children: [
          Text(
            "쉽고 재밌는 나의 식습관 파악하기",
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          SizedBox(height: 8),
          Text(
            "나의 FMBT 알아보기",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// 질문 + 선택지 UI
  Widget _buildQuestionTile(String question, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        // 질문 텍스트
        Text(
          question,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _isUnanswered[index] ? Colors.red : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // 선택지 (1~5)
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

  /// 단일 선택지
  Widget _buildOption(int value, int questionIndex) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          // 이미 선택되어 있으면 해제
          if (_answers[questionIndex] == value) {
            _answers[questionIndex] = null;
          } else {
            _answers[questionIndex] = value;
          }
          // 빨간 표시 해제
          _isUnanswered[questionIndex] = false;
        });
        // 선택 즉시 Firestore에 반영 (단일)
        await _saveSingleAnswer(questionIndex, _answers[questionIndex]);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color:
                _answers[questionIndex] == value ? Colors.blue : Colors.black45,
            width: _answers[questionIndex] == value ? 3 : 1.5,
          ),
          color: Colors.white,
        ),
      ),
    );
  }
}
