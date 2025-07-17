// lib/setting/setting_screen.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../color/colors.dart';
import '../login/login_screen.dart';
import 'my_posts_screen.dart';
import 'push_notification_settings_screen.dart';

class SettingScreen extends StatefulWidget {
  final String userEmail;
  final String userId;
  final String idToken;

  const SettingScreen({
    Key? key,
    required this.userEmail,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String? _profileUrl; // Firestore 에 저장된 프로필 URL
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.userId)
        .get();

    if (mounted) {
      setState(() => _profileUrl = doc.data()?['profileUrl'] as String?);
    }
  }

  // ───────────────────────── 프로필 이미지 선택 & 업로드
  Future<void> _changeProfile() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploading = true);

    try {
      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${widget.userId}.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // Firestore & FirebaseAuth photoURL 업데이트
      await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .update({'profileUrl': url});

      await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);

      if (mounted) setState(() => _profileUrl = url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진이 변경되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ───────────────────────── 로그아웃
  void _handleLogout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ───────────────────────── UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ───── 프로필 카드 ─────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(kBorderRadius),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      // 프로필 이미지
                      GestureDetector(
                        onTap: _changeProfile,
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _profileUrl != null
                              ? NetworkImage(_profileUrl!)
                              : null,
                          child: _profileUrl == null
                              ? const Icon(Icons.person,
                                  size: 32, color: Colors.white70)
                              : null,
                        ),
                      ),
                      // 업로드 중 로딩 스피너
                      if (_uploading)
                        const Positioned.fill(
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      // 카메라 아이콘
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: GestureDetector(
                          onTap: _changeProfile,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: kPinkButtonColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.userEmail,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ───── 알림 설정 ─────
            ListTile(
              leading: const Icon(Icons.notifications_none, color: kTextColor),
              title: const Text('알림 설정', style: TextStyle(color: kTextColor)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PushNotificationSettingsScreen(
                    userId: widget.userId,
                    idToken: widget.idToken,
                  ),
                ),
              ),
            ),

            // ───── 내 게시물 관리 ─────
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('내 게시물 관리'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyPostsScreen(
                    userId: widget.userId,
                    idToken: widget.idToken,
                  ),
                ),
              ),
            ),

            // ───── 로그아웃 ─────
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }
}
