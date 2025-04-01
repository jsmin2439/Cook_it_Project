import 'package:flutter/material.dart';
import 'package:mediapipe_2/community_post_create_screen.dart';

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
  // 검색창 제어
  final TextEditingController _searchController = TextEditingController();

  // 예시 게시글 데이터(더미)
  final List<Map<String, dynamic>> _posts = [
    {
      "title": "김치볶음밥",
      "author": "cookMaster",
      "likes": 12,
      "comments": 3,
      "rating": 4.2,
    },
    {
      "title": "해물 파전",
      "author": "seafoodFan",
      "likes": 8,
      "comments": 5,
      "rating": 4.5,
    },
    {
      "title": "초코 브라우니",
      "author": "sweetLover",
      "likes": 25,
      "comments": 10,
      "rating": 4.9,
    },
    // ... 필요하면 더미 데이터 추가
  ];

  // 검색 액션
  void _performSearch() {
    final query = _searchController.text.trim();
    // TODO: 실제 검색 로직 (예: Firestore나 서버 API 호출)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("검색어: $query (아직 미구현)")),
    );
  }

  // 새 글 작성 액션 (FAB)
  void _goToCreatePost() {
    // TODO: 실제 글 작성 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPostCreateScreen(
          userId: widget.userId,
          idToken: widget.idToken,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단바: Community + 검색 아이콘
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

      // 리스트 형식으로 게시글 표시
      body: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _posts.length,
        // 각 항목 사이 구분선
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildListItem(post);
        },
      ),

      // 글 작성 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCreatePost,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.edit),
      ),
    );
  }

  //------------------------------------------------------------------------------
  // 한 줄짜리 List Item (이미지 왼쪽, 텍스트/카운트 오른쪽)
  //------------------------------------------------------------------------------
  Widget _buildListItem(Map<String, dynamic> post) {
    final imageUrl = post["imageUrl"] as String? ?? "";
    final title = post["title"] ?? "No Title";
    final author = post["author"] ?? "Unknown";
    final likes = post["likes"] ?? 0;
    final comments = post["comments"] ?? 0;
    final rating = post["rating"] ?? 0.0;

    return GestureDetector(
      onTap: () {
        // TODO: 상세 페이지로 이동
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$title 게시글 선택 (아직 미구현)")),
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
        // Row: 이미지 + 텍스트
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
                      child:
                          const Icon(Icons.photo, size: 40, color: Colors.grey),
                    )
                  : Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
            ),

            // (2) 오른쪽 정보
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
                    // 좋아요, 댓글, 평점
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
                        const SizedBox(width: 10),
                        // 평점
                        const Icon(
                          Icons.star_rate_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text("$rating", style: const TextStyle(fontSize: 12)),
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
  // 검색 다이얼로그
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
