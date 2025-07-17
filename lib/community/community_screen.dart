// lib/community/community_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ← 추가

import '../color/colors.dart';
import 'community_post_create_screen.dart';
import 'community_post_detail_screen.dart';

class CommunityScreen extends StatefulWidget {
  final String userId;
  final String idToken;
  const CommunityScreen({Key? key, required this.userId, required this.idToken})
      : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

enum SortOption { latest, relevance }

class _CommunityScreenState extends State<CommunityScreen> {
  final _searchCtl = TextEditingController();
  final _scrollCtl = ScrollController();

  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  String? _errorMsg;

  int _page = 1;
  static const _limit = 10;
  bool _hasMore = true;

  SortOption _sort = SortOption.latest;
  String _tagFilter = '';

  @override
  void initState() {
    super.initState();
    _fetchPosts(reset: true);

    _scrollCtl.addListener(() {
      if (_scrollCtl.position.pixels >=
              _scrollCtl.position.maxScrollExtent - 300 &&
          !_isLoading &&
          _hasMore) {
        _page++;
        _fetchPosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  //──────────────────────────────── API
  Future<void> _fetchPosts({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _posts.clear();
    }
    setState(() {
      _isLoading = true;
      if (reset) _errorMsg = null;
    });

    final params = <String, String>{
      'page': '$_page',
      'limit': '$_limit',
      if (_searchCtl.text.trim().isNotEmpty) 'search': _searchCtl.text.trim(),
      if (_tagFilter.isNotEmpty) 'tag': _tagFilter,
      if (_sort == SortOption.relevance) 'sort': 'relevance',
    };
    final uri =
        Uri.http('gamdasal.iptime.org:3000', '/api/community/posts', params);

    try {
      final res = await http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.idToken}'});
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && j['success'] == true) {
        final list = (j['posts'] ?? []).cast<Map<String, dynamic>>();
        setState(() {
          _posts.addAll(list);
          _hasMore = list.length == _limit;
        });
      } else {
        setState(() => _errorMsg = j['message'] ?? '불러오기 실패');
      }
    } catch (e) {
      setState(() => _errorMsg = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //──────────────────────────────── Nav
  Future<void> _openCreatePage() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => CommunityPostCreateScreen(
              userId: widget.userId, idToken: widget.idToken)),
    );
    if (ok == true) _fetchPosts(reset: true);
  }

  Future<void> _openDetailPage(String id) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => CommunityPostDetailPage(
              postId: id, userId: widget.userId, idToken: widget.idToken)),
    );
    if (ok == true) _fetchPosts(reset: true);
  }

  //──────────────────────────────── UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _appBar(),
      body: RefreshIndicator(
        onRefresh: () => _fetchPosts(reset: true),
        child: _body(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPinkButtonColor,
        onPressed: _openCreatePage,
        child: const Icon(Icons.edit),
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: .5,
        titleSpacing: 0,
        title: _searchBar(),
        actions: [_sortSelector()],
      );

  Widget _searchBar() => Container(
        margin: const EdgeInsets.only(right: 8),
        height: 40,
        child: TextField(
          controller: _searchCtl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _fetchPosts(reset: true),
          decoration: InputDecoration(
            hintText: '게시물을 검색하세요',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchCtl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtl.clear();
                      _fetchPosts(reset: true);
                    },
                  ),
            filled: true,
            fillColor: const Color(0xFFF2F3F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none),
          ),
        ),
      );

  Widget _sortSelector() => DropdownButtonHideUnderline(
        child: DropdownButton(
          value: _sort,
          style: const TextStyle(color: kTextColor),
          items: const [
            DropdownMenuItem(value: SortOption.latest, child: Text('최신순')),
            DropdownMenuItem(value: SortOption.relevance, child: Text('관련도순')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _sort = v);
            _fetchPosts(reset: true);
          },
        ),
      );

  //──────────────────────────────── 본문
  Widget _body() {
    if (_isLoading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) return Center(child: Text('오류: $_errorMsg'));
    if (_posts.isEmpty) return const Center(child: Text('게시물이 없습니다.'));

    return ListView.builder(
      controller: _scrollCtl,
      padding: const EdgeInsets.all(8),
      itemCount: _posts.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _posts.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _postCard(_posts[i]);
      },
    );
  }

  //──────────────────────────────── 카드
  Widget _postCard(Map<String, dynamic> p) {
    final img = p['imageUrl'] ?? '';
    final title = p['title'] ?? '제목 없음';
    final likes = p['likeCount'] ?? 0;
    final cmts = p['commentCount'] ?? 0;
    final tags = List<String>.from(p['tags'] ?? []);
    final author = p['userName'] ?? 'Unknown';
    final date = _fmt(p['createdAt']);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 4)
          ]),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetailPage(p['id']),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12)),
              child: img.isEmpty
                  ? Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo, color: Colors.grey),
                    )
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
                    // 제목
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    // 작성자 · 날짜
                    Text('$author · $date',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    // 좋아요 · 댓글
                    Row(
                      children: [
                        const Icon(Icons.favorite_border,
                            size: 14, color: Colors.red),
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
                          final tagText = t.startsWith('#') ? t : '#$t';
                          return Chip(
                            label: Text(tagText,
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
            )
          ],
        ),
      ),
    );
  }

  // util ─ Firestore timestamp → yyyy.MM.dd
  String _fmt(dynamic ts) {
    try {
      final s = ts['_seconds'] as int;
      return DateFormat('yyyy.MM.dd')
          .format(DateTime.fromMillisecondsSinceEpoch(s * 1000));
    } catch (_) {
      return '';
    }
  }
}
