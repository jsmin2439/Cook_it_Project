import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'my_fridge_page.dart';
import 'search_screen.dart';
import 'heart_screen.dart';
import 'survey_screen.dart';
import 'recipe_detail_page.dart';
import 'models/fmbt_result.dart';
import 'result_screen.dart';

// 테마/컬러 설정
const Color kBackgroundColor = Color(0xFFFFFFFF); // 전체 배경: 흰색
const Color kCardColor = Color(0xFFFFECD0); // 카드 배경: 연한 베이지
const Color kPinkButtonColor = Color(0xFFFFC7B9); // 핑크
const Color kTextColor = Colors.black87; // 텍스트 색상
const double kBorderRadius = 16.0; // 둥근 모서리

class MainScreen extends StatefulWidget {
  final String idToken;
  final String userId;
  final String userEmail;

  const MainScreen({
    Key? key,
    required this.idToken,
    required this.userId,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 현재 선택된 하단 탭 인덱스
  int _selectedIndex = 0;

  // 홈 탭(0번)에서 사용될 상태값들
  String? _fmbtResult;
  String? _fmbtSummary;
  int _currentPage = 0;
  bool _isLoading = false;
  List<dynamic> _recommendedRecipes = [];

  // PageView 컨트롤러 (AI 레시피 카드 슬라이드용)
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // 홈 탭에서 필요한 것들 불러오기
    _fetchRecommendedRecipes();
    _fetchFMBTResult().then((_) => _fetchFMBTSummary());
  }

  // -------------------------
  // (A) 하단 탭 전환
  // -------------------------
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // -------------------------
  // (B) 로그아웃 처리
  // -------------------------
  void _handleLogout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ==========================================================================
  // == 전체 화면: 하단바 + body( _screens[_selectedIndex] )
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    // 탭별로 보여줄 화면을 배열로 준비
    final List<Widget> screens = [
      _buildHomeTab(), // 0번 탭: Home
      _buildCategoryTab(), // 1번 탭: Category (미구현 -> 임시)
      SearchScreen(), // 2번 탭: Search (이미 구현된 화면)
      HeartScreen(
        // 3번 탭: Heart (즐겨찾기)
        userId: widget.userId,
        idToken: widget.idToken,
      ),
      _buildCommTab(), // 4번 탭: Community (미구현 -> 임시)
    ];

    return Scaffold(
      backgroundColor: kBackgroundColor,

      // body: 현재 선택된 탭의 화면을 보여줌
      body: screens[_selectedIndex],

      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: '카테고리'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '검색'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border), label: '저장'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined), label: '커뮤니티'),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 0) Home 탭: 기존 MainScreen의 홈 화면 로직
  //--------------------------------------------------------------------------
  Widget _buildHomeTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 상단 앱바 부분
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/CookIT.png',
                          width: 100, height: 50),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    color: Colors.redAccent,
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),

            // 사용자 환영 문구
            _buildUserGreeting(),
            const SizedBox(height: 20),

            // 실제 메인 컨텐츠
            _buildMainContent(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Category 탭(1번)의 임시 화면
  Widget _buildCategoryTab() {
    return const Center(
      child: Text("Category Screen (아직 구현 전)"),
    );
  }

  /// 커뮤니티 탭(4번)의 임시 화면
  Widget _buildCommTab() {
    return const Center(
      child: Text("Community Screen (아직 구현 전)"),
    );
  }

  //--------------------------------------------------------------------------
  // 사용자 환영 문구
  //--------------------------------------------------------------------------
  Widget _buildUserGreeting() {
    final userName = widget.userEmail.split('@').first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        "$userName님 환영합니다!",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // 홈 화면의 전체 컨텐츠
  //--------------------------------------------------------------------------
  Widget _buildMainContent() {
    return Column(
      children: [
        _buildMyFridgeCard(), // 냉장고
        const SizedBox(height: 20),
        _buildAiRecipeCard(), // AI 맞춤 레시피
        const SizedBox(height: 20),
        _buildTasteLabCard(), // FMBT
        const SizedBox(height: 20),
        _buildIngredientsCard(), // 싫어하는 재료
      ],
    );
  }

  //--------------------------------------------------------------------------
  // (1) 나만의 냉장고 카드
  //--------------------------------------------------------------------------
  Widget _buildMyFridgeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(kBorderRadius),
          border: Border.all(color: Colors.black26),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              Row(
                children: [
                  Icon(Icons.kitchen, color: Colors.brown[700], size: 28),
                  const SizedBox(width: 10),
                  Text(
                    "나만의 냉장고",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 재료 목록
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('user')
                      .doc(widget.userId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.data!.exists) {
                      return _buildFridgeEmptyText();
                    }
                    final docData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final rawList = docData['ingredients'] ?? [];

                    if (rawList == null || rawList.isEmpty) {
                      return _buildFridgeEmptyText();
                    }

                    List<String> ingredients = List<String>.from(rawList);
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...ingredients.take(10).map(
                                (i) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white),
                                  ),
                                  child: Text(
                                    i,
                                    style:
                                        const TextStyle(color: Colors.black87),
                                  ),
                                ),
                              ),
                          if (ingredients.length > 10)
                            Text(
                              "+ ${ingredients.length - 10}개 더보기",
                              style: const TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 관리하기 버튼
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text("관리하기"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[300],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () {
                    // 냉장고 관리 페이지로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyFridgePage(
                          userId: widget.userId,
                          idToken: widget.idToken,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFridgeEmptyText() {
    return Center(
      child: Text(
        "재료를 추가해보세요!",
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // (2) AI 맞춤 레시피 카드
  //--------------------------------------------------------------------------
  Future<void> _fetchRecommendedRecipes() async {
    setState(() => _isLoading = true);

    try {
      final uri =
          Uri.parse("http://jsmin2439.iptime.org:3000/api/recommend-recipes");
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.idToken}",
        },
        body: jsonEncode({"userId": widget.userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["recommendedRecipes"] != null) {
          setState(() {
            // 3개만 사용
            _recommendedRecipes = data["recommendedRecipes"].take(3).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('오류 발생: $e');
    }

    setState(() => _isLoading = false);
  }

  Widget _buildAiRecipeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(kBorderRadius),
          border: Border.all(color: Colors.black26),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 제목 + 새로고침
              Row(
                children: [
                  Image.asset('assets/images/cookbook.png',
                      width: 30, height: 30),
                  const SizedBox(width: 8),
                  Text(
                    "AI 맞춤 레시피",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[700],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.brown[600]),
                    onPressed: _fetchRecommendedRecipes,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 레시피 내용 or 로딩
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _recommendedRecipes.isEmpty
                        ? Center(
                            child: Text(
                              "추천 레시피를 가져오는 중...",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: _recommendedRecipes.length,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            itemBuilder: (context, index) {
                              final recipe = _recommendedRecipes[index];
                              return _buildRecipeItem(recipe);
                            },
                          ),
              ),
              const SizedBox(height: 10),

              // 페이지 인디케이터
              if (!_isLoading && _recommendedRecipes.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _recommendedRecipes.length,
                    (index) => Container(
                      width: _currentPage == index ? 12 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.brown[700]
                            : Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeItem(dynamic recipe) {
    final String imageUrl = recipe["ATT_FILE_NO_MAIN"] ?? "";
    final String recipeName = recipe["RCP_NM"] ?? "No Name";

    return GestureDetector(
      onTap: () {
        // 레시피 상세 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailPage(
              recipeData: recipe,
              userId: widget.userId,
              idToken: widget.idToken,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // 이미지
              Expanded(
                child: imageUrl.isEmpty
                    ? Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.fastfood,
                          size: 50,
                          color: Colors.grey,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
              ),
              // 텍스트
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                child: Text(
                  recipeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // (3) 나의 식습관 좌표 FMBT
  //--------------------------------------------------------------------------
  Future<void> _fetchFMBTResult() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        setState(() {
          _fmbtResult = doc.data()?['fmbt'] as String?;
        });
      }
    } catch (e) {
      debugPrint('FMBT 결과 조회 오류: $e');
    }
  }

  Future<void> _fetchFMBTSummary() async {
    if (_fmbtResult == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('fmbt_descriptions')
          .doc(_fmbtResult)
          .get();

      if (doc.exists) {
        setState(() {
          _fmbtSummary = doc.data()?['summary'] as String?;
        });
      }
    } catch (e) {
      debugPrint('FMBT 요약 조회 오류: $e');
    }
  }

  Widget _buildTasteLabCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(kBorderRadius),
              border: Border.all(color: Colors.black26),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "🍽️ 나의 식습관 좌표 FMBT",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 아직 검사 안 했을 때
                if (_fmbtResult == null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPinkButtonColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onPressed: _goToSurvey,
                    child:
                        const Text("FMBT 검사하기", style: TextStyle(fontSize: 16)),
                  )
                else
                  // 이미 검사한 경우
                  Column(
                    children: [
                      const Text(
                        "이미 검사하셨습니다!",
                        style: TextStyle(color: Colors.brown),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "FMBT 유형: $_fmbtResult",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_fmbtSummary != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _fmbtSummary!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 10),

                      // 다시 검사하기 / 결과 보기
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onPressed: _resetSurveyAndRetest,
                            child: const Text(
                              "다시 검사하기",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onPressed: _viewSurveyResults,
                            child: const Text(
                              "검사 결과 보기",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _goToSurvey() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyScreen(
          userId: widget.userId,
          idToken: widget.idToken,
        ),
      ),
    );
  }

  Future<void> _resetSurveyAndRetest() async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('user').doc(widget.userId);
      await docRef.update({
        'responses-1': [0, 0, 0, 0, 0],
        'responses-2': [0, 0, 0, 0, 0],
        'responses-3': [0, 0, 0, 0, 0],
        'responses-4': [0, 0, 0, 0, 0],
        'fmbt': FieldValue.delete(),
      });
      setState(() {
        _fmbtResult = null;
        _fmbtSummary = null;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurveyScreen(
            userId: widget.userId,
            idToken: widget.idToken,
          ),
        ),
      );
    } catch (e) {
      debugPrint("재검사 초기화 오류: $e");
    }
  }

  Future<void> _viewSurveyResults() async {
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
                userId: widget.userId,
                idToken: widget.idToken,
              ),
            ),
          );
        } else {
          final errorMsg = responseJson['error'] ?? 'FMBT 계산 실패';
          debugPrint('서버 오류: $errorMsg');
          _showErrorSnackBar(errorMsg);
        }
      } else {
        debugPrint('서버 응답 오류: ${response.statusCode} / ${response.body}');
        _showErrorSnackBar('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("❌ FMBT 계산 요청 오류: $e");
      _showErrorSnackBar("FMBT 결과 불러오기 오류: $e");
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  //--------------------------------------------------------------------------
  // (4) 싫어하거나 피하고 싶은 재료
  //--------------------------------------------------------------------------
  Widget _buildIngredientsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(kBorderRadius),
          border: Border.all(color: Colors.black26),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "싫어하거나 피하고 싶은 재료가 있나요?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildIngredientChip("알코올"),
                _buildIngredientChip("달걀"),
                _buildIngredientChip("우유"),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPinkButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                // TODO: 수정하기 기능
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("수정하기 기능은 준비 중입니다.")),
                );
              },
              child: const Text("수정하기"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black45),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}
