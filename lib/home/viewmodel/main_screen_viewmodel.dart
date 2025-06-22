// lib/home/viewmodel/main_screen_viewmodel.dart
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../fmbt/fmbt_result_screen.dart';
import '../../fmbt/fmbt_survey_screen.dart';
import '../../model/fmbt_result.dart';
import '../model/recipe_model.dart';

class MainScreenViewModel extends ChangeNotifier {
  // ---------------------------
  // (1) 상태값들
  // ---------------------------
  // 하단 탭 인덱스
  int selectedIndex = 0;

  // HeartScreen 의 상태 제어용 (deleteMode toggle)
  // → 실제 HeartScreenState에 대한 접근은 View단에서 key 로 제어
  //   여기서는 필요 시 인터페이스만 정의 가능

  // FMBT 관련
  String? fmbtResult;
  String? fmbtSummary;

  // AI 레시피 추천 관련
  bool isLoading = false;
  List<Recipe> recommendedRecipes = [];
  int currentPage = 0;

  // 필요 정보
  late String userId;
  late String idToken;
  late String userEmail; // UI에서 userName 표시용

  // ---------------------------
  // (2) 초기화
  // ---------------------------
  void init({
    required String userId,
    required String idToken,
    required String userEmail,
  }) {
    this.userId = userId;
    this.idToken = idToken;
    this.userEmail = userEmail;
  }

  // ---------------------------
  // (3) 하단 탭 전환
  // ---------------------------
  void onItemTapped(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  // ---------------------------
  // (4) 로그아웃
  // ---------------------------
  void handleLogout(BuildContext context) {
    FirebaseAuth.instance.signOut();
    // pushReplacement
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ---------------------------
  // (5) AI 레시피 가져오기
  // ---------------------------
  Future<void> fetchRecommendedRecipes() async {
    isLoading = true;
    notifyListeners();

    try {
      final uri =
          Uri.parse("http://gamproject.iptime.org:3000/api/recommend-recipes");
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"userId": userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["recommendedRecipes"] != null) {
          final recipeList = data["recommendedRecipes"] as List<dynamic>;
          // 3개만 사용
          final firstThree = recipeList.take(3).toList();
          recommendedRecipes = firstThree
              .map((jsonItem) =>
                  Recipe.fromJson(jsonItem as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('오류 발생: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  // 페이지뷰 현재 페이지 바인딩
  void setCurrentPage(int index) {
    currentPage = index;
    notifyListeners();
  }

  // ---------------------------
  // (6) FMBT 결과 불러오기
  // ---------------------------
  Future<void> fetchFMBTResult() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('user').doc(userId).get();

      if (doc.exists) {
        fmbtResult = doc.data()?['fmbt'] as String?;
      }
    } catch (e) {
      debugPrint('FMBT 결과 조회 오류: $e');
    }
    notifyListeners();
  }

  Future<void> fetchFMBTSummary() async {
    if (fmbtResult == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('fmbt_descriptions')
          .doc(fmbtResult)
          .get();

      if (doc.exists) {
        fmbtSummary = doc.data()?['summary'] as String?;
      }
    } catch (e) {
      debugPrint('FMBT 요약 조회 오류: $e');
    }
    notifyListeners();
  }

  // ---------------------------
  // (7) FMBT 재검사
  // ---------------------------
  Future<void> resetSurveyAndRetest(BuildContext context) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('user').doc(userId);
      await docRef.update({
        'responses-1': [0, 0, 0, 0, 0],
        'responses-2': [0, 0, 0, 0, 0],
        'responses-3': [0, 0, 0, 0, 0],
        'responses-4': [0, 0, 0, 0, 0],
        'fmbt': FieldValue.delete(),
      });

      fmbtResult = null;
      fmbtSummary = null;
      notifyListeners();

      // Navigator.push 로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              // 원본 코드: SurveyScreen(userId: userId, idToken: idToken)
              // 실제 import 필요 (../fmbt/fmbt_survey_screen.dart)
              // 여기서는 예시 상단 import만 유지
              // "SurveyScreen" 그대로 사용
              SurveyScreen(
            userId: userId,
            idToken: idToken,
          ),
        ),
      );
    } catch (e) {
      debugPrint("재검사 초기화 오류: $e");
    }
  }

  // ---------------------------
  // (8) FMBT 결과 보기
  // ---------------------------
  Future<void> viewSurveyResults(BuildContext context) async {
    try {
      final uri = Uri.parse(
        'http://gamproject.iptime.org:3000/api/calculate-fmbt?userId=$userId',
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        if (responseJson['success'] == true) {
          final fmbt = responseJson['fmbt']?.toString() ?? '';
          final scores = responseJson['scores'] ?? {};
          final desc = responseJson['description']?.toString() ?? '';

          final Map<String, int> scoresMap = Map<String, int>.from(scores);
          final resultData = FmbtResult(
            fmbt: fmbt,
            scores: scoresMap,
            description: desc,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                resultData: resultData,
                userId: userId,
                idToken: idToken,
              ),
            ),
          );
        } else {
          final errorMsg = responseJson['error'] ?? 'FMBT 계산 실패';
          debugPrint('서버 오류: $errorMsg');
          showErrorSnackBar(context, errorMsg);
        }
      } else {
        debugPrint('서버 응답 오류: ${response.statusCode} / ${response.body}');
        showErrorSnackBar(context, '서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("❌ FMBT 계산 요청 오류: $e");
      showErrorSnackBar(context, "FMBT 결과 불러오기 오류: $e");
    }
  }

  // ---------------------------
  // (9) 에러 스낵바
  // ---------------------------
  void showErrorSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
