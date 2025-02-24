import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'my_fridge_page.dart';
import 'search_screen.dart';
import 'login_screen.dart';
import 'recipe_detail_page.dart';
import 'heart_screen.dart';
import 'survey_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 색상 팔레트
const Color kBackgroundColor = Color(0xFFFFFFFF);
const double kBorderRadius = 16.0;

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
  int _selectedIndex = 0;
  String? _fmbtResult;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  List<dynamic> _recommendedRecipes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedRecipes();
    _fetchFMBTResult();
  }

  Future<void> _fetchFMBTResult() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .get();
      if (userDoc.exists) {
        setState(() => _fmbtResult = userDoc['fmbt'] as String?);
      }
    } catch (e) {
      print('FMBT 결과 조회 오류: $e');
    }
  }

  Future<void> _fetchRecommendedRecipes() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("http://jsmin2439.iptime.org:3000/api/recommend-recipes"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.idToken}"
        },
        body: jsonEncode({"userId": widget.userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["recommendedRecipes"] != null) {
          setState(() => _recommendedRecipes =
              data["recommendedRecipes"].take(3).toList());
        }
      }
    } catch (e) {
      debugPrint('오류 발생: $e');
    }
    setState(() => _isLoading = false);
  }

  void _handleLogout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 2)
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SearchScreen()));
    if (index == 3)
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const HeartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildAppBar(),
              const SizedBox(height: 10),
              _buildUserGreeting(),
              const SizedBox(height: 20),
              _buildMainContent(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Row(children: [
            Image.asset('assets/images/cookie.png', width: 50, height: 50),
            const SizedBox(width: 8),
            const Text('Cook it',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.notifications_none), onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.logout),
              color: Colors.red[300],
              onPressed: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildUserGreeting() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        "${widget.userEmail.split('@').first}님 환영합니다!",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildMyFridgeCard(),
        const SizedBox(height: 20),
        _buildAiRecipeCard(),
        const SizedBox(height: 20),
        _buildTasteLabCard(),
        const SizedBox(height: 20),
        _buildIngredientsCard(),
      ],
    );
  }

  Widget _buildMyFridgeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius)),
        child: Container(
          height: 240,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple[100]!, Colors.pink[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.kitchen, color: Colors.deepPurple[800], size: 28),
                  const SizedBox(width: 10),
                  Text("나만의 냉장고",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[800])),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('user')
                      .doc(widget.userId)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Center(
                          child: Text("재료를 추가해보세요!",
                              style: TextStyle(color: Colors.grey[600])));
                    }
                    List<String> ingredients =
                        List<String>.from(snapshot.data!['ingredients'] ?? []);
                    return ingredients.isEmpty
                        ? Center(
                            child: Text("재료를 추가해보세요!",
                                style: TextStyle(color: Colors.grey[600])))
                        : SingleChildScrollView(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ...ingredients.take(10).map((ingredient) =>
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white),
                                      ),
                                      child: Text(ingredient,
                                          style: const TextStyle(
                                              color: Colors.black87)),
                                    )),
                                if (ingredients.length > 10)
                                  Text("+ ${ingredients.length - 10}개 더보기",
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text("관리하기"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyFridgePage(
                          userId: widget.userId, idToken: widget.idToken),
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

  Widget _buildAiRecipeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius)),
        child: Container(
          height: 240,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[100]!, Colors.cyan[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/cookbook.png',
                          width: 32, height: 32),
                      const SizedBox(width: 10),
                      Text("AI 맞춤 레시피",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          )),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.blue[800]),
                    onPressed: _fetchRecommendedRecipes,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.blue))
                    : _recommendedRecipes.isEmpty
                        ? Center(
                            child: Text("추천 레시피를 생성중입니다...",
                                style: TextStyle(color: Colors.grey[600])))
                        : PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) =>
                                setState(() => _currentPage = index),
                            itemCount: _recommendedRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = _recommendedRecipes[index];
                              return GestureDetector(
                                // GestureDetector 추가
                                onTap: () =>
                                    _navigateToRecipeDetail(recipe, context),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Image.network(
                                            recipe["ATT_FILE_NO_MAIN"] ?? "",
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.grey[200],
                                              child: Icon(Icons.fastfood,
                                                  size: 50,
                                                  color: Colors.grey[500]),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          color: Colors.white,
                                          child: Text(
                                            recipe["RCP_NM"] ?? "No Name",
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
                            },
                          ),
              ),
              if (!_isLoading && _recommendedRecipes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _recommendedRecipes.length,
                      (index) => Container(
                        width: _currentPage == index ? 12 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.blue[800]
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(4),
                        ),
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

  void _navigateToRecipeDetail(
      Map<String, dynamic> recipe, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailPage(
          recipeData: recipe,
          userId: widget.userId, // 사용자 ID 전달
        ),
      ),
    );
  }

  Widget _buildTasteLabCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kBorderRadius)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink[100]!, Colors.orange[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(kBorderRadius),
              ),
              child: Column(
                children: [
                  const Text("🍽️ 나의 식습관 좌표",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _fmbtResult != null
                      ? Column(
                          children: [
                            Text("FMBT 유형:",
                                style: TextStyle(color: Colors.grey[700])),
                            const SizedBox(height: 8),
                            Text(_fmbtResult!,
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                    letterSpacing: 4)),
                            const SizedBox(height: 10),
                            const Text(
                                "이 유형은 새로운 음식을 좋아하고,\n빠른 식사 속도를 가진 특징이 있습니다!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54)),
                          ],
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 243, 164, 222),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SurveyScreen(
                                userId: widget.userId,
                                idToken: widget.idToken,
                              ),
                            ),
                          ),
                          child: const Text("FMBT 검사 시작하기",
                              style: TextStyle(fontSize: 16)),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kBorderRadius)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[100]!, Colors.green[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(kBorderRadius),
              ),
              child: Column(
                children: [
                  const Text("👅 맛 취향 분석",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  const Icon(Icons.analytics_outlined,
                      size: 50, color: Colors.blue),
                  const SizedBox(height: 10),
                  Text(
                    _fmbtResult != null
                        ? "당신의 $_fmbtResult 유형에 맞는\n맛 취향 분석을 진행해보세요!"
                        : "FMBT 검사 후 이용 가능합니다",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], height: 1.4),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _fmbtResult != null ? Colors.green : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _fmbtResult != null ? () {} : null,
                    child:
                        const Text("분석 시작하기", style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.yellow[100]!, Colors.orange[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
          child: Column(
            children: [
              const Text("싫어하거나 피하고 싶은 재료가 있나요?",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  backgroundColor: Colors.orange[800],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {},
                child: const Text("수정하기"),
              ),
            ],
          ),
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

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black54,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Category'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border), label: 'Heart'),
        BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined), label: 'Comm'),
      ],
    );
  }
}
