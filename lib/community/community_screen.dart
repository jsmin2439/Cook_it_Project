import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 글 상세 페이지 (예: PostDetailPage)
import 'community_post_detail_screen.dart';

// 글 작성 페이지
import 'community_post_create_screen.dart';

class CommunityScreen extends StatefulWidget {
  final String userId;
  final String idToken;

  const CommunityScreen({
    Key? key,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 실제 서버에서 가져온 게시물 목록
  List<Map<String, dynamic>> _posts = [];

  // 페이지, 페이지당 limit
  int _currentPage = 1;
  int _limit = 10;

  // 간단한 로딩/에러 표시
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPosts(); // 화면 초기 로딩 시 목록 가져오기
  }

  //------------------------------------------------------------------------------
  // (A) 서버에 GET 요청 -> 게시물 목록 가져오기
  //------------------------------------------------------------------------------
  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.parse(
      "http://gamproject.iptime.org:3000/api/community/posts"
      "?page=$_currentPage&limit=$_limit",
    );

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${widget.idToken}",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data["success"] == true) {
          final List<dynamic> postsJson = data["posts"] ?? [];
          _posts = postsJson
              .map((item) {
                // item 예: {"id":"...","title":"...","content":"...",...}
                final map = item as Map<String, dynamic>;

                return {
                  "id": map["id"] ?? "",
                  "title": map["title"] ?? "No Title",
                  "content": map["content"] ?? "",
                  "imageUrl": map["imageUrl"] ?? "",
                  "author": map["userName"] ?? "Unknown",
                  "recipeName": map["recipeName"] ?? "",
                  "likes": map["likeCount"] ?? 0,
                  "comments": map["commentCount"] ?? 0,
                  "createdAt": map["createdAt"] ?? "",
                };
              })
              .toList()
              .cast<Map<String, dynamic>>();
          // pagination 등도 data["pagination"]에서 파싱 가능
        } else {
          _errorMessage = data["message"] ?? "목록 조회 실패";
        }
      } else {
        _errorMessage = "서버 오류: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "네트워크/통신 오류: $e";
    }

    setState(() {
      _isLoading = false;
    });
  }

  //------------------------------------------------------------------------------
  // (B) 검색
  //------------------------------------------------------------------------------
  void _performSearch() {
    final query = _searchController.text.trim();
    // TODO: 실제 검색 로직 (파라미터 query를 서버로 보내거나)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("검색어: $query (아직 미구현)")),
    );
  }

  //------------------------------------------------------------------------------
  // (C) 글 작성 화면 이동
  //------------------------------------------------------------------------------
  void _goToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPostCreateScreen(
          userId: widget.userId,
          idToken: widget.idToken,
        ),
      ),
    );

    if (result == true) {
      // 작성 후 돌아왔다면 → 다시 목록 요청
      await _fetchPosts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("게시물이 성공적으로 작성되었습니다.")),
      );
    }
  }

  //------------------------------------------------------------------------------
  // 빌드
  //------------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단바
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: _showSearchDialog,
          ),
        ],
      ),

      // 본문: 에러 / 로딩 / 목록
      body: RefreshIndicator(
        onRefresh: () async {
          _currentPage = 1; // 페이지를 초기화
          await _fetchPosts(); // 게시물 재조회
        },
        child: _buildBody(),
      ),

      // 글 작성 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCreatePost,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text("오류: $_errorMessage"));
    }
    if (_posts.isEmpty) {
      return const Center(child: Text("아직 게시물이 없습니다."));
    }

    // 목록 표시
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _posts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final post = _posts[index];
        return _buildListItem(post);
      },
    );
  }

  //------------------------------------------------------------------------------
  // (D) 단일 게시물 아이템
  //------------------------------------------------------------------------------
  Widget _buildListItem(Map<String, dynamic> post) {
    final imageUrl = post["imageUrl"] ?? "";
    final title = post["title"] ?? "No Title";
    final author = post["author"] ?? "Unknown";
    final likes = post["likes"] ?? 0;
    final comments = post["comments"] ?? 0;
    final postId = post["id"] ?? "";

    return GestureDetector(
      onTap: () {
        // ★ 수정: 게시물을 누르면 PostDetailPage로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityPostDetailPage(
              postId: postId, // 목록에서 가져온 게시물 ID
              userId: widget.userId,
              idToken: widget.idToken,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // (1) 왼쪽 썸네일
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: imageUrl.isEmpty
                  ? Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.photo,
                        size: 40,
                        color: Colors.grey,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
            ),
            // (2) 오른쪽 텍스트
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 작성자
                    Text(
                      "by $author",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    // 좋아요, 댓글
                    Row(
                      children: [
                        // 좋아요
                        const Icon(
                          Icons.favorite_border,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 2),
                        Text("$likes", style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 10),
                        // 댓글
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 2),
                        Text("$comments", style: const TextStyle(fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------
  // (E) 검색 다이얼로그
  //------------------------------------------------------------------------------
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("검색"),
          content: TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: "검색어를 입력"),
            onSubmitted: (_) => _performSearch(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _performSearch();
              },
              child: const Text("확인"),
            ),
          ],
        );
      },
    );
  }
}
