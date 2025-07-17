// lib/community/community_post_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../ai_recipe/recipe_detail_screen.dart';
import '../color/colors.dart'; // kTextColor · kPinkButtonColor

const Color _chipColor = Color(0xFFF2F3F5); // community_screen 과 동일

class CommunityPostDetailPage extends StatefulWidget {
  final String postId, userId, idToken;
  const CommunityPostDetailPage(
      {super.key,
      required this.postId,
      required this.userId,
      required this.idToken});

  @override
  State<CommunityPostDetailPage> createState() =>
      _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  Map<String, dynamic>? _post;
  bool _loading = false;
  String? _error;

  bool _liked = false;
  int _likeCnt = 0;

  final _commentCtl = TextEditingController();

  // ―― 인-라인 편집용 상태
  String? _editingCid;
  final _editCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  //────────────────────────────────── API
  bool _isLiked(Map<String, dynamic> p) =>
      p['liked'] == true ||
      List<String>.from(p['likedBy'] ?? []).contains(widget.userId);

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
          'http://gamdasal.iptime.org:3000/api/community/post/${widget.postId}');
      final res = await http
          .get(uri, headers: {'Authorization': 'Bearer ${widget.idToken}'});
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        _post = data['post'];
        _liked = _isLiked(_post!);
        _likeCnt = _post?['likeCount'] ?? (_post?['likedBy']?.length ?? 0);
      } else {
        _error = data['message'] ?? '불러오기 실패';
      }
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleLike() async {
    setState(() {
      _liked = !_liked;
      _likeCnt += _liked ? 1 : -1;
    });

    await http.post(
      Uri.parse(
          'http://gamdasal.iptime.org:3000/api/community/post/${widget.postId}/like'),
      headers: {'Authorization': 'Bearer ${widget.idToken}'},
    );
    _fetch(); // 동기화
  }

  //────────────────────── 댓글 CRUD
  Future<void> _sendComment() async {
    final txt = _commentCtl.text.trim();
    if (txt.isEmpty) return;

    await http.post(
      Uri.parse(
          'http://gamdasal.iptime.org:3000/api/community/post/${widget.postId}/comment'),
      headers: {
        'Authorization': 'Bearer ${widget.idToken}',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'content': txt}),
    );
    _commentCtl.clear();
    _fetch();
  }

  Future<void> _saveEdited() async {
    final newTxt = _editCtl.text.trim();
    if (_editingCid == null || newTxt.isEmpty) {
      setState(() => _editingCid = null);
      return;
    }
    await http.put(
      Uri.parse(
          'http://gamdasal.iptime.org:3000/api/community/post/${widget.postId}/comment/$_editingCid'),
      headers: {
        'Authorization': 'Bearer ${widget.idToken}',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'content': newTxt}),
    );
    _editingCid = null;
    _fetch();
  }

  Future<void> _deleteComment(String cid) async {
    await http.delete(
      Uri.parse(
          'http://gamdasal.iptime.org:3000/api/community/post/${widget.postId}/comment/$cid'),
      headers: {'Authorization': 'Bearer ${widget.idToken}'},
    );
    _fetch();
  }

  //────────────────────────────────── UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(child: Text(_error!))
              : _post == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Expanded(child: _body()),
                        _inputBar(),
                      ],
                    ),
    );
  }

  //―――― AppBar
  AppBar _appBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: .6,
        iconTheme: const IconThemeData(color: kTextColor),
        title: Text(_post?['title'] ?? '',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 18, color: kTextColor)),
        actions: [
          Row(children: [
            Text('$_likeCnt', style: const TextStyle(color: kTextColor)),
            IconButton(
              icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border_outlined,
                  color: _liked ? kPinkButtonColor : kTextColor),
              onPressed: _toggleLike,
            ),
          ])
        ],
      );

  //―――― BODY
  Widget _body() => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _author(),
            if (_post?['imageUrl'] != null) _photo(),
            _content(),
            _tagWrap(),
            if (_post?['recipe'] != null) _recipeSection(),
            _commentList(),
          ],
        ),
      );

  Widget _author() => ListTile(
        leading: CircleAvatar(
          backgroundColor: kPinkButtonColor,
          child: Text((_post?['userName'] ?? 'U')[0]),
        ),
        title: Text(_post?['userName'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_dateStr(_post?['createdAt'])),
      );

  Widget _photo() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(_post!['imageUrl'], fit: BoxFit.cover),
        ),
      );

  Widget _content() => (_post?['content'] ?? '').isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(_post!['content'],
              style: const TextStyle(fontSize: 15, height: 1.55)),
        );

  Widget _tagWrap() {
    final tags = List<String>.from(_post?['tags'] ?? []);
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: tags.map((t) {
          final tag = t.startsWith('#') ? t : '#$t';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _chipColor, borderRadius: BorderRadius.circular(20)),
            child: Text(tag,
                style: const TextStyle(fontSize: 12, color: kTextColor)),
          );
        }).toList(),
      ),
    );
  }

  //―――― 레시피 카드 영역
  Widget _recipeSection() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 32),
            const Text('레시피북',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kTextColor)),
            const SizedBox(height: 12),
            _recipeCard(),
          ],
        ),
      );

  Widget _recipeCard() {
    final r = _post!['recipe'];
    final img = r['ATT_FILE_NO_MAIN'] ?? '';
    final name = r['RCP_NM'] ?? '';
    final way = r['RCP_WAY2'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeDetailPage(
              recipeData: r,
              userId: widget.userId,
              idToken: widget.idToken,
              showEditIcon: false),
        ),
      ),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // img
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  children: [
                    Image.network(img,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.menu_book,
                                size: 48, color: Colors.grey))),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(.55),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  height: 1.2)),
                          const SizedBox(height: 4),
                          Text(way,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(.9),
                                  fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            // bottom bar
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_dining, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(way,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  const Icon(Icons.star_rate_rounded,
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('${r['rating'] ?? 4.5}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  //―――― 댓글 LIST
  Widget _commentList() {
    final list = List<Map<String, dynamic>>.from(_post?['comments'] ?? []);
    if (list.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 60),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        reverse: true,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _commentCard(list[list.length - 1 - i]),
      ),
    );
  }

  Widget _commentCard(Map<String, dynamic> c) {
    final mine = c['userId'] == widget.userId;
    final editing = _editingCid == c['commentId'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1) header ─ name + date + menu
          Row(
            children: [
              CircleAvatar(
                  radius: 14,
                  backgroundColor: kPinkButtonColor,
                  child: Text(c['userName'][0],
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12))),
              const SizedBox(width: 10),
              // 이름이 길어도 overflow 안나게 Expanded
              Expanded(
                child: Text(c['userName'],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text(_dateStr(c['createdAt']),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (mine)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (v) {
                    if (v == 'edit') {
                      setState(() {
                        _editingCid = c['commentId'];
                        _editCtl.text = c['content'];
                      });
                    }
                    if (v == 'del') _deleteComment(c['commentId']);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'del', child: Text('삭제')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 2) 내용 or 편집 UI
          editing
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _editCtl,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: _chipColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _saveEdited,
                      style: TextButton.styleFrom(
                          foregroundColor: kPinkButtonColor),
                      child: const Text('완료'),
                    )
                  ],
                )
              : Text(c['content']),
        ],
      ),
    );
  }

  //―――― 입력 바
  Widget _inputBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black26, blurRadius: 4, offset: Offset(0, -1))
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtl,
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요',
                    filled: true,
                    fillColor: _chipColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: kPinkButtonColor,
                child: IconButton(
                  icon: const Icon(Icons.send, size: 18, color: Colors.white),
                  onPressed: _sendComment,
                ),
              )
            ],
          ),
        ),
      );

  // util
  String _dateStr(dynamic ts) {
    try {
      final sec = (ts?['_seconds'] ?? 0) as int;
      return DateFormat('yy.MM.dd HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(sec * 1000));
    } catch (_) {
      return '';
    }
  }
}
