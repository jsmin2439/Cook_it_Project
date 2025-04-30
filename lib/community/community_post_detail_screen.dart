import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../ai_recipe/recipe_detail_screen.dart';
import '../color/colors.dart';

class CommunityPostDetailPage extends StatefulWidget {
  final String postId;
  final String userId;
  final String idToken;

  const CommunityPostDetailPage({
    Key? key,
    required this.postId,
    required this.userId,
    required this.idToken,
  }) : super(key: key);

  @override
  State<CommunityPostDetailPage> createState() =>
      _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _postData;
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  // 키보드 표시 여부
  bool _isKeyboardVisible = false;
  // 좋아요 상태
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchPostDetail();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  /// 키보드 표시 여부 체크
  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    setState(() {
      _isKeyboardVisible = bottomInset > 0;
    });
  }

  //----------------------------------------------------------------------------
  // 1) 게시물 상세 조회
  //----------------------------------------------------------------------------
  Future<void> _fetchPostDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.parse(
        "http://jsmin2439.iptime.org:3000/api/community/post/${widget.postId}");
    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${widget.idToken}",
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          setState(() {
            _postData = data["post"];
            // 서버에서 liked 여부를 받았다면
            _isLiked = _postData?["liked"] == true;
          });
        } else {
          _errorMessage = data["message"] ?? "상세 조회 실패";
        }
      } else {
        _errorMessage = "서버 오류: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "네트워크 오류: $e";
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //----------------------------------------------------------------------------
  // 2) 좋아요 토글
  //----------------------------------------------------------------------------
  Future<void> _toggleLike() async {
    if (_postData == null) return;
    final postId = _postData!["id"];

    try {
      final url = Uri.parse(
          "http://jsmin2439.iptime.org:3000/api/community/post/$postId/like");
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer ${widget.idToken}",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          setState(() {
            _isLiked = data["liked"] == true;
          });
        }
      } else {
        _showErrorSnackBar("좋아요 처리 실패(${response.statusCode})");
      }
    } catch (e) {
      _showErrorSnackBar("좋아요 처리 중 오류: $e");
    }
  }

  //----------------------------------------------------------------------------
  // 3) 댓글 등록
  //    - 전송 성공하면 _postData["comments"]에 직접 추가하여 실시간 반영
  //----------------------------------------------------------------------------

  //----------------------------------------------------------------------------
  // 4) 댓글 삭제
  //----------------------------------------------------------------------------
  Future<void> _deleteComment(String commentId) async {
    final postId = widget.postId;
    final url = Uri.parse(
        "http://jsmin2439.iptime.org:3000/api/community/post/$postId/comment/$commentId");

    try {
      final response = await http.delete(
        url,
        headers: {
          "Authorization": "Bearer ${widget.idToken}",
        },
      );

      if (response.statusCode == 200) {
        // 로컬 상태 반영
        setState(() {
          _postData?["comments"]
              .removeWhere((item) => item["commentId"] == commentId);
        });
        _showSuccessSnackBar("댓글이 삭제되었습니다.");
      } else {
        _showErrorSnackBar("댓글 삭제 실패(${response.statusCode})");
      }
    } catch (e) {
      _showErrorSnackBar("댓글 삭제 중 오류: $e");
    }
  }

  //----------------------------------------------------------------------------
  // 5) 댓글 수정
  //----------------------------------------------------------------------------
  Future<void> _editComment(String commentId, String oldContent) async {
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("댓글 수정"),
        content: TextField(
          controller: TextEditingController(text: oldContent),
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "수정할 댓글 내용을 입력하세요",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              final textField = (context
                      .findAncestorWidgetOfExactType<AlertDialog>()!
                      .content as TextField)
                  .controller;
              Navigator.pop(context, textField?.text ?? "");
            },
            child: const Text("저장", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (newContent == null || newContent.isEmpty || newContent == oldContent) {
      return;
    }

    final postId = widget.postId;
    final url = Uri.parse(
        "http://jsmin2439.iptime.org:3000/api/community/post/$postId/comment/$commentId");

    try {
      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer ${widget.idToken}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"content": newContent}),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar("댓글이 수정되었습니다.");
        await _fetchPostDetail();
      } else {
        _showErrorSnackBar("댓글 수정 실패(${response.statusCode})");
      }
    } catch (e) {
      _showErrorSnackBar("댓글 수정 중 오류: $e");
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.greenAccent,
      ),
    );
  }

  //----------------------------------------------------------------------------
  // build
  //----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 본문 콘텐츠 (스크롤 가능 영역)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80), // 하단 입력창 공간 확보
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 포스트 내용 + 이미지 통합 위젯
                  _buildPostContentWithImage(),

                  // 레시피 카드
                  if (_postData?["recipe"] != null) _buildRecipeCard(),

                  // 댓글 섹션
                  _buildCommentSection(),
                ],
              ),
            ),
          ),

          // 고정된 댓글 입력창
          _buildCommentInputBar(),
        ],
      ),
    );
  }

  //----------------------------------------------------------------------------
  // AppBar
  //----------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kCardColor,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(kBorderRadius),
        ),
      ),
      title: Text(
        _postData?["title"] ?? "커뮤니티 포스트",
        style: const TextStyle(
          color: kTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
      iconTheme: const IconThemeData(color: kTextColor),
      actions: [
        IconButton(
          icon: Icon(
            _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            color: _isLiked ? kPinkButtonColor : kTextColor.withOpacity(0.6),
            size: 28,
          ),
          onPressed: _toggleLike,
        ),
      ],
    );
  }

  Widget _buildPostContentWithImage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 정보
          _buildAuthorSection(),
          const SizedBox(height: 20),

          // 텍스트 내용
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(kBorderRadius),
            ),
            child: Text(
              _postData?["content"] ?? "",
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: kTextColor,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 이미지
          if (_postData?["imageUrl"] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(kBorderRadius),
              child: Image.network(
                _postData!["imageUrl"],
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 240,
                    color: kCardColor,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  color: kCardColor,
                  child: const Icon(Icons.photo_library_rounded, size: 50),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthorSection() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _postData?["userName"] ?? "Unknown",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kTextColor,
              ),
            ),
            Text(
              _formatDate(_postData?["createdAt"]),
              style: TextStyle(
                fontSize: 12,
                color: kTextColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 레시피 카드
  Widget _buildRecipeCard() {
    final recipe = _postData!["recipe"];
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(kBorderRadius)),
            child: Stack(
              children: [
                Image.network(
                  recipe["ATT_FILE_NO_MAIN"] ?? "",
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Text(
                      recipe["RCP_NM"] ?? "레시피 제목",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPinkButtonColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    recipe["RCP_WAY2"] ?? "종류",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailPage(
                        recipeData: recipe,
                        userId: widget.userId,
                        idToken: widget.idToken,
                        showEditIcon: false,
                      ),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        '레시피 보기',
                        style: TextStyle(color: kTextColor),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: kTextColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 댓글 메뉴 표시 함수 추가
  void _showCommentMenu(dynamic comment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: kTextColor),
              title: const Text('수정하기'),
              onTap: () {
                Navigator.pop(context);
                _editComment(comment["commentId"], comment["content"]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title:
                  const Text('삭제하기', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _deleteComment(comment["commentId"]);
              },
            ),
          ],
        ),
      ),
    );
  }

// 댓글 등록 부분 수정 (맨 뒤에 추가)
  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(
            "http://jsmin2439.iptime.org:3000/api/community/post/${widget.postId}/comment"),
        headers: {
          "Authorization": "Bearer ${widget.idToken}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"content": content}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data["success"] == true && data["comment"] != null) {
          setState(() {
            _postData?["comments"].add(data["comment"]); // 맨 뒤에 추가
          });
          _commentController.clear();
          FocusScope.of(context).unfocus();

          // 댓글 목록 자동 스크롤
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Scrollable.ensureVisible(
              context,
              alignment: 1.0, // 하단 정렬
              duration: const Duration(milliseconds: 300),
            );
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar("댓글 작성 중 오류: $e");
    }
  }

// 댓글 목록 역순 출력 수정
  Widget _buildCommentSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '댓글',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _postData?["comments"]?.length ?? 0,
            reverse: true,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final reversedIndex = _postData!["comments"].length - 1 - index;
              return _buildCommentItem(_postData!["comments"][reversedIndex]);
            },
          ),
          const SizedBox(height: 20), // 하단 여백 추가
        ],
      ),
    );
  }

  Widget _buildCommentItem(dynamic comment) {
    final isCurrentUser = comment["userId"] == widget.userId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: kPinkButtonColor,
                child: Text(
                  comment["userName"].toString().substring(0, 1),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment["userName"],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextColor,
                ),
              ),
              if (isCurrentUser) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onPressed: () => _showCommentMenu(comment),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment["content"],
            style: const TextStyle(
              fontSize: 14,
              color: kTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(comment["createdAt"]),
            style: TextStyle(
              fontSize: 11,
              color: kTextColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: "댓글을 입력하세요...",
                  filled: true,
                  fillColor: kCardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: kPinkButtonColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _submitComment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "";
    try {
      final seconds = timestamp["_seconds"] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      return DateFormat("yyyy.MM.dd HH:mm").format(date);
    } catch (e) {
      return "";
    }
  }
}
