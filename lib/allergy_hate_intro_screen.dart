import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'allergy_hate_category_screen.dart';
import '../home/cook_it_main_screen.dart';

const Color kPinkButtonColor = Color(0xFFFFC7B9);
const double kBorderRadius = 16.0;
const Color kTextColor = Colors.black87;

class AllergyHateIntroScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  const AllergyHateIntroScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<AllergyHateIntroScreen> createState() => _AllergyHateIntroScreenState();
}

class _AllergyHateIntroScreenState extends State<AllergyHateIntroScreen> {
  final _lines = [
    "알레르기나 피하고 싶은 재료가 있으신가요?",
    "체크한 재료가 들어간 레시피는\n추천에서 제외해 드릴게요."
  ];
  late List<bool> _visible = List.filled(2, false);

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  Future<void> _reveal() async {
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _visible[0] = true);
    await Future.delayed(const Duration(milliseconds: 900));
    setState(() => _visible[1] = true);
  }

  // ───────── navigation helpers
  Future<void> _openSelector() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AllergyHateCategoryScreen(
          initialSelectedCategories: const [],
          initialCheckedIngredients: const [],
        ),
      ),
    );

    // null == 사용자가 뒤로가기 눌러버린 경우
    if (result == null) return;

    // Firestore 저장
    await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.userId)
        .update({
      'excludedCategories': result['categories'],
      'allergic_ingredients': result['ingredients'],
    });

    _goHome(showSnack: true);
  }

  void _goHome({bool showSnack = false}) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          idToken: widget.idToken,
          userId: widget.userId,
          userEmail: '', // 로그인 직후 flow라면 email을 다시 받아오세요
        ),
      ),
      (r) => false,
    );
    if (showSnack) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('취향 정보 입력이 완료되었습니다. 맛있는 여정 되세요! 😋'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: _visible[0] ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _lines[0],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedOpacity(
                opacity: _visible[1] ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _lines[1],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, height: 1.4, color: kTextColor),
                ),
              ),
              const SizedBox(height: 50),
              if (_visible.every((v) => v))
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPinkButtonColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                      ),
                      onPressed: _openSelector,
                      child: const Text('체크하기', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 20),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[800],
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                      ),
                      onPressed: () => _goHome(),
                      child: const Text('건너뛰기', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
