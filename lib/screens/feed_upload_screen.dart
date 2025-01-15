import 'package:flutter/material.dart';

class FeedUploadScreen extends StatelessWidget {
  const FeedUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 섹션
              Row(
                children: [
                  // 프로필 이미지
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '까미',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'luckybicky',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // 관리 버튼
                  ElevatedButton(
                    onPressed: () {
                      // 버튼 액션 추가
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                    ),
                    child: const Text('관리'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 메뉴 섹션
              const Divider(),
              _buildMenuItem(Icons.notifications, '알림 설정'),
              const Divider(),
              _buildMenuItem(Icons.headset, '문의 하기'),
              const Divider(),
              _buildMenuItem(Icons.info, '개발자 정보'),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Icon(
            icon,
            size: 30,
            color: Colors.black,
          ),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
