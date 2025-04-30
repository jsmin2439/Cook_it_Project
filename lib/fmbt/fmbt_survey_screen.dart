import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../model/fmbt_result.dart';
import 'fmbt_result_screen.dart';

class SurveyScreen extends StatefulWidget {
  final String userId;
  final String idToken;
  final bool isFirstLogin;

  const SurveyScreen({
    Key? key,
    required this.userId,
    required this.idToken,
    this.isFirstLogin = false,
  }) : super(key: key);

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _currentPage = 0;
  final int _questionsPerPage = 5;
  List<int?> _answers = List.filled(20, null);
  List<bool> _isUnanswered = List.filled(20, false);
  List<String> _pageTitles = [];
  List<String> _questions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _initializeUserDocument();
      await _fetchSurveyData();
      await _loadExistingResponses();
    } catch (e) {
      setState(() {
        _errorMessage = '데이터 불러오기 실패: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSurveyData() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('questions').get();
    final List<String> tempTitles = [];
    final List<String> tempQuestions = [];

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
  }

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

  Future<void> _saveAnswersToFirestore() async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('user').doc(widget.userId);
      Map<String, dynamic> responsesData = {};

      for (int page = 0; page < 4; page++) {
        int startIndex = page * 5;
        final pageAnswers = _answers
            .sublist(startIndex, startIndex + 5)
            .map((a) => a ?? 0)
            .toList();
        responsesData['responses-${page + 1}'] = pageAnswers;
      }

      await userDoc.set(responsesData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore 저장 오류: $e");
    }
  }

  Future<void> _requestFmbtResult() async {
    try {
      final uri = Uri.parse(
          'http://jsmin2439.iptime.org:3000/api/calculate-fmbt?userId=${widget.userId}');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.idToken}',
      });

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        if (responseJson['success'] == true) {
          final resultData = FmbtResult(
            fmbt: responseJson['fmbt'].toString(),
            scores: Map<String, int>.from(responseJson['scores']),
            description: responseJson['description'].toString(),
          );
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
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("오류 발생: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _nextPage() async {
    final currentPageQuestions = List.generate(
        _questionsPerPage, (idx) => _currentPage * _questionsPerPage + idx);
    bool hasUnanswered =
        currentPageQuestions.any((idx) => _answers[idx] == null);

    if (hasUnanswered) {
      setState(() {
        for (int idx in currentPageQuestions)
          _isUnanswered[idx] = _answers[idx] == null;
      });
      return;
    }

    if (_currentPage < 3) {
      setState(() => _currentPage++);
    } else {
      await _saveAnswersToFirestore();
      await _requestFmbtResult();
    }
  }

  Future<void> _saveSingleAnswer(int questionIndex, int? value) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('user').doc(widget.userId);
      final pageNumber = (questionIndex ~/ 5) + 1;
      final indexInPage = questionIndex % 5;

      final docSnap = await userDoc.get();
      List<dynamic> current = docSnap.exists
          ? (docSnap.data()!['responses-$pageNumber'] ?? List.filled(5, 0))
          : List.filled(5, 0);
      List<int> updated = List<int>.from(current);
      updated[indexInPage] = value ?? 0;

      await userDoc
          .set({'responses-$pageNumber': updated}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("단일 저장 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage.isNotEmpty)
      return Scaffold(body: Center(child: Text(_errorMessage)));

    final startIndex = _currentPage * _questionsPerPage;
    final endIndex = startIndex + _questionsPerPage;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🍴 식습관 진단 설문",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink[300]!, Colors.orange[300]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildProgressIndicator(),
            const SizedBox(height: 25),
            _buildCategoryDescription(), // 추가된 부분
            Expanded(
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: ListView.builder(
                    itemCount: endIndex - startIndex,
                    itemBuilder: (context, idx) {
                      final questionIndex = startIndex + idx;
                      return _buildQuestionTile(
                          _questions[questionIndex], questionIndex);
                    },
                  ),
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  // 추가된 위젯
  Widget _buildCategoryDescription() {
    if (_currentPage >= _pageTitles.length) return const SizedBox.shrink();

    final categoryMap = {
      'E_C': 'E/C (새로운 음식 선호 vs 보수적)',
      'F_S': 'F/S (식사 속도 빠름 vs 느림)',
      'S_G': 'S/G (혼밥 선호 vs 단체 선호)',
      'B_M': 'B/M (강한 맛 선호 vs 순한 맛 선호)',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Text(
        categoryMap[_pageTitles[_currentPage]] ?? _pageTitles[_currentPage],
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.pink[800],
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentPage + 1) / 4,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[300]!),
          minHeight: 12,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 10),
        Text(
          "${_currentPage + 1} / 4 페이지",
          style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildQuestionTile(String question, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.pink[50], shape: BoxShape.circle),
                child: Text("${index + 1}",
                    style: TextStyle(
                        color: Colors.pink[800], fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isUnanswered[index] ? Colors.red : Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildOptionsRow(index),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("전혀 아님",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text("매우 그럼",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsRow(int index) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => _buildOption(i + 1, index),
      ),
    );
  }

  Widget _buildOption(int value, int questionIndex) {
    final isSelected = _answers[questionIndex] == value;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _answers[questionIndex] =
              _answers[questionIndex] == value ? null : value;
          _isUnanswered[questionIndex] = false;
        });
        await _saveSingleAnswer(questionIndex, _answers[questionIndex]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        decoration: BoxDecoration(
          color: isSelected ? Colors.pink[100] : Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.pink[300]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            "$value",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.pink[800] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 25),
      child: ElevatedButton.icon(
        icon: Icon(_currentPage == 3 ? Icons.check_circle : Icons.arrow_forward,
            size: 22),
        label: Text(
          _currentPage == 3 ? "결과 확인하기" : "다음 문항",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.pink[300],
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 35),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 3,
          shadowColor: Colors.pink[100],
        ),
        onPressed: _nextPage,
      ),
    );
  }
}
