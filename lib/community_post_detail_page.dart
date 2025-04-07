import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'recipe_detail_page.dart';

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
  bool _isKeyboardVisible = false;
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

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    setState(() {
      _isKeyboardVisible = bottomInset > 0;
    });
  }

  Future<void> _fetchPostDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
            "http://jsmin2439.iptime.org:3000/api/community/post/${widget.postId}"),
        headers: {"Authorization": "Bearer ${widget.idToken}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"]) {
          setState(() {
            _postData = data["post"];
            _isLiked = _postData?["liked"] == true;
          });
        }
      } else {
        setState(() => _errorMessage = "서버 오류: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "네트워크 오류: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_postData == null) return;

    try {
      final response = await http.post(
        Uri.parse(
            "http://jsmin2439.iptime.org:3000/api/community/post/${_postData!["id"]}/like"),
        headers: {"Authorization": "Bearer ${widget.idToken}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"]) {
          setState(() {
            _isLiked = data["liked"] == true;
          });
        }
      }
    } catch (e) {
      _showErrorSnackbar("좋아요 처리 실패: $e");
    }
  }

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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData["comment"] != null) {
          setState(() {
            _postData?["comments"].add(responseData["comment"]);
          });
        }
        _commentController.clear();
        await _fetchPostDetail();
      }
    } catch (e) {
      _showErrorSnackbar("댓글 작성 실패: $e");
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final response = await http.delete(
        Uri.parse(
            "http://jsmin2439.iptime.org:3000/api/community/post/${widget.postId}/comment/$commentId"),
        headers: {"Authorization": "Bearer ${widget.idToken}"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _postData?["comments"]
              .removeWhere((c) => c["commentId"] == commentId);
        });
        _showSuccessSnackbar("댓글이 삭제되었습니다.");
      }
    } catch (e) {
      _showErrorSnackbar("댓글 삭제 실패: $e");
    }
  }

  Future<void> _editComment(String commentId, String currentContent) async {
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("댓글 수정"),
        content: TextField(
          controller: TextEditingController(text: currentContent),
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "댓글 내용을 입력하세요",
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
            onPressed: () => Navigator.pop(
              context,
              (context.findAncestorWidgetOfExactType<AlertDialog>()?.content
                      as TextField)
                  .controller
                  ?.text,
            ),
            child: const Text("저장", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (newContent == null ||
        newContent.isEmpty ||
        newContent == currentContent) return;

    try {
      final response = await http.put(
        Uri.parse(
            "http://jsmin2439.iptime.org:3000/api/community/post/${widget.postId}/comment/$commentId"),
        headers: {
          "Authorization": "Bearer ${widget.idToken}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"content": newContent}),
      );

      if (response.statusCode == 200) {
        await _fetchPostDetail();
        _showSuccessSnackbar("댓글이 수정되었습니다.");
      }
    } catch (e) {
      _showErrorSnackbar("댓글 수정 실패: $e");
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBody(),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildCommentInputBar(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          ClipOval(
            child: Image.network(
              "https://cdn-icons-png.flaticon.com/512/847/847969.png",
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _postData?["userName"] ?? "Unknown",
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.red : Colors.grey,
            size: 28,
          ),
          onPressed: _toggleLike,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));
    if (_postData == null) return const SizedBox.shrink();

    final comments = _postData!["comments"] as List<dynamic>;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: _isKeyboardVisible ? 100 : 80,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostTitle(),
          const SizedBox(height: 8),
          _buildPostAuthor(),
          const SizedBox(height: 16),
          _buildPostImage(),
          const SizedBox(height: 16),
          if (_postData?["recipe"] != null) _buildRecipeCard(),
          const SizedBox(height: 24),
          _buildCommentSection(comments),
        ],
      ),
    );
  }

  Widget _buildPostTitle() {
    return Text(
      _postData?["title"] ?? "제목 없음",
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
    );
  }

  Widget _buildPostAuthor() {
    return Row(
      children: [
        Text(
          "작성자: ${_postData?["userName"] ?? "Unknown"}",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          _formatDate(_postData?["createdAt"]),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildPostImage() {
    if (_postData?["imageUrl"] == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        _postData!["imageUrl"],
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildRecipeCard() {
    final recipe = _postData!["recipe"] as Map<String, dynamic>;
    final imageUrl = recipe["ATT_FILE_NO_MAIN"] ?? "";

    return GestureDetector(
      onTap: () => Navigator.push(
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
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe["RCP_NM"] ?? "레시피",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    recipe["RCP_WAY2"] ?? "",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSection(List<dynamic> comments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "댓글",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                "첫 번째 댓글을 작성해보세요!",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildCommentItem(comments[index]),
          ),
      ],
    );
  }

  Widget _buildCommentItem(dynamic comment) {
    final isCurrentUser = comment["userId"] == widget.userId;
    final hasUpdated = comment["updatedAt"] != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                comment["userName"] ?? "Unknown",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      _editComment(comment["commentId"], comment["content"]),
                  child: Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _deleteComment(comment["commentId"]),
                  child: Icon(Icons.delete_outline,
                      size: 16, color: Colors.red[300]),
                ),
              ],
              const Spacer(),
              Text(
                _formatDate(
                    hasUpdated ? comment["updatedAt"] : comment["createdAt"]),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment["content"],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputBar() {
    return Material(
      elevation: 5,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  focusNode: _commentFocusNode,
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: "댓글을 입력하세요...",
                    fillColor: Colors.grey[100],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, color: Colors.blue[400]),
                onPressed: _submitComment,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      final seconds = timestamp["_seconds"] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      return DateFormat("yyyy.MM.dd HH:mm").format(date);
    } catch (e) {
      return "";
    }
  }
}
