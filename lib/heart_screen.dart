import 'package:flutter/material.dart';

const Color kBackgroundColor = Color(0xFFFFFFFF);
const Color kCardColor = Color(0xFFFFECD0);
const Color kPinkButtonColor = Color(0xFFFFC7B9);
const Color kTextColor = Colors.black87;
const double kBorderRadius = 16.0;

class HeartScreen extends StatelessWidget {
  const HeartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/cookie.png', // 쿠키 로고
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 8),
            const Text(
              'Cook it',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: const [
          Icon(Icons.notifications_none, color: Colors.black),
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 프로필 영역
            Row(
              children: [
                // 프로필 이미지
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/cat.jpeg'), // 프로필 사진
                ),
                const SizedBox(width: 16),
                // 프로필 텍스트 정보
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "냥이",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    Text(
                      "미야~옹",
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 탭 (게시물 / 좋아요)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kBorderRadius),
                border: Border.all(color: Colors.black),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.black)),
                      ),
                      child: const Text("게시물",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: const Text("좋아요",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 게시물 목록
            Expanded(
              child: ListView.builder(
                itemCount: 3, // 예제: 3개의 게시물
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(kBorderRadius),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("게시글 제목:",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const Text("사진", style: TextStyle(fontSize: 16)),
                        Icon(Icons.favorite, color: Colors.red[400]),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // -------------------- 하단 네비게이션 바 --------------------
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3, // Heart 탭 활성화
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context);
          }
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view), label: 'Category'),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined), label: 'Camera'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite, color: Colors.red), label: 'Heart'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }
}
