// lib/setting/my_posts_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../color/colors.dart';
import '../community/community_post_detail_screen.dart';
import '../community/community_post_create_screen.dart';

class MyPostsScreen extends StatefulWidget {
  final String userId;
  final String idToken;
  const MyPostsScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  //──────────────── data
  final List<Map<String, dynamic>> _myPosts = [];
  final List<Map<String, dynamic>> _likedPosts = [];

  bool _loadingMy = false, _loadingLiked = false;
  String? _errMy, _errLiked;

  //──────────────── init
  @override
  void initState() {
    super.initState();
    _fetchMyPosts();
    _fetchLikedPosts();
  }

  //──────────────── API
  Future<void> _fetchMyPosts() async {
    setState(() => _loadingMy = true);
    const url = 'http://gamdasal.iptime.org:3000/api/community/user-posts';
    try {
      final r = await http.get(Uri.parse(url),
          headers: {'Authorization': 'Bearer ${widget.idToken}'});
      final j = jsonDecode(r.body);
      if (r.statusCode == 200 && j['success'] == true) {
        _myPosts
          ..clear()
          ..addAll((j['posts'] as List).cast<Map<String, dynamic>>());
      } else {
        _errMy = j['message'] ?? '불러오기 실패';
      }
    } catch (e) {
      _errMy = '네트워크 오류: $e';
    }
    if (mounted) setState(() => _loadingMy = false);
  }

  Future<void> _fetchLikedPosts() async {
    setState(() => _loadingLiked = true);
    const url = 'http://gamdasal.iptime.org:3000/api/community/liked-posts';
    try {
      final r = await http.get(Uri.parse(url),
          headers: {'Authorization': 'Bearer ${widget.idToken}'});
      final j = jsonDecode(r.body);
      if (r.statusCode == 200 && j['success'] == true) {
        _likedPosts
          ..clear()
          ..addAll((j['posts'] as List).cast<Map<String, dynamic>>());
      } else {
        _errLiked = j['message'] ?? '불러오기 실패';
      }
    } catch (e) {
      _errLiked = '네트워크 오류: $e';
    }
    if (mounted) setState(() => _loadingLiked = false);
  }

  Future<void> _deletePost(String id) async {
    final url = 'http://gamdasal.iptime.org:3000/api/community/post/$id';
    try {
      final r = await http.delete(Uri.parse(url),
          headers: {'Authorization': 'Bearer ${widget.idToken}'});
      if (r.statusCode ~/ 100 == 2) {
        _snack('삭제되었습니다');
        _myPosts.removeWhere((p) => p['id'] == id);
        setState(() {});
      } else {
        _snack('삭제 실패: ${r.statusCode}', true);
      }
    } catch (e) {
      _snack('오류: $e', true);
    }
  }

  //──────────────── utils
  void _snack(String m, [bool err = false]) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: err ? Colors.red : null),
      );

  String _fmt(dynamic ts) {
    try {
      final sec = ts['_seconds'] as int;
      return DateFormat('yyyy.MM.dd')
          .format(DateTime.fromMillisecondsSinceEpoch(sec * 1000));
    } catch (_) {
      return '';
    }
  }

  //──────────────── UI
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('내 게시물 관리', style: TextStyle(color: kTextColor)),
          iconTheme: const IconThemeData(color: kTextColor),
          bottom: const TabBar(
            labelColor: kTextColor,
            indicatorColor: kPinkButtonColor,
            tabs: [
              Tab(text: '작성글'),
              Tab(text: '좋아요한 글'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _tabBody(_loadingMy, _errMy, _myPosts,
                mine: true, onRefresh: _fetchMyPosts),
            _tabBody(_loadingLiked, _errLiked, _likedPosts,
                mine: false, onRefresh: _fetchLikedPosts),
          ],
        ),
      ),
    );
  }

  Widget _tabBody(bool loading, String? err, List<Map<String, dynamic>> list,
      {required bool mine, required Future<void> Function() onRefresh}) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (err != null) return Center(child: Text(err));
    if (list.isEmpty) {
      return Center(child: Text(mine ? '작성한 글이 없습니다.' : '좋아요한 글이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _card(list[i], mine),
      ),
    );
  }

  //──────────────── 카드
  Widget _card(Map<String, dynamic> p, bool mine) {
    final img = p['imageUrl'] ?? '';
    final title = p['title'] ?? '제목 없음';
    final likes = p['likeCount'] ?? 0;
    final cmts = p['commentCount'] ?? 0;
    final author = p['userName'] ?? '';
    final date = _fmt(p['createdAt']);
    final metaText = mine ? date : '$author · $date';
    final tags = List<String>.from(p['tags'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 4)
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityPostDetailPage(
              postId: p['id'],
              userId: widget.userId,
              idToken: widget.idToken,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: img.isEmpty
                  ? Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo, color: Colors.grey))
                  : Image.network(img,
                      width: 100, height: 100, fit: BoxFit.cover),
            ),
            // 정보
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    // meta (작성자 · 날짜 or 날짜만)
                    Text(metaText,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    // 좋아요 · 댓글
                    Row(
                      children: [
                        const Icon(Icons.favorite,
                            size: 14, color: Colors.redAccent),
                        const SizedBox(width: 2),
                        Text('$likes', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_outline,
                            size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 2),
                        Text('$cmts', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: -4,
                        children: tags.take(3).map((t) {
                          final tt = t.startsWith('#') ? t : '#$t';
                          return Chip(
                            label: Text(tt,
                                style: const TextStyle(
                                    fontSize: 11, color: kTextColor)),
                            backgroundColor: kPinkButtonColor.withOpacity(.25),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 우측 아이콘
            mine
                ? Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          final ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityPostCreateScreen(
                                userId: widget.userId,
                                idToken: widget.idToken,
                                existingPost: {
                                  ...p,
                                  'recipeIndex': p['recipeIndex'] ?? 0,
                                  'recipeName': p['recipeName'] ?? '',
                                  'recipeImageUrl': p['recipeImageUrl'] ?? '',
                                },
                              ),
                            ),
                          );
                          if (ok == true) _fetchMyPosts();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.redAccent),
                        onPressed: () => _deletePost(p['id']),
                      ),
                    ],
                  )
                : const Padding(
                    padding: EdgeInsets.only(right: 8, top: 8),
                    child:
                        Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                  ),
          ],
        ),
      ),
    );
  }
}
