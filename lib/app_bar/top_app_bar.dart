// lib/app_bar/top_app_bar.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

AppBar buildCommonAppBar({
  required BuildContext context,
  bool showDeleteIcon = false,
  VoidCallback? onDeleteTap,
}) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    // 왼쪽에 Cook it 로고 (이미지 자리에 본인 로고/텍스트 넣으면 됨)
    leading: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.asset('assets/images/cookie.png'),
    ),
    // 제목
    title: const Text(
      'Cook it',
      style: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    centerTitle: true,
    // 오른쪽 액션 아이콘들
    actions: [
      // 알림 아이콘
      IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.black),
        onPressed: () {
          // TODO: 알림 화면 이동 or 기능
        },
      ),
      // 로그아웃 아이콘
      IconButton(
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        onPressed: () {
          FirebaseAuth.instance.signOut();
          // 로그아웃 후 로그인화면으로 이동
          Navigator.popUntil(context, (route) => route.isFirst);
        },
      ),
      // 삭제 아이콘 (HeartScreen 전용)
      if (showDeleteIcon)
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: onDeleteTap,
        ),
    ],
  );
}
