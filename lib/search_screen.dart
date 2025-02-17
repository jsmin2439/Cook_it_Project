
import 'package:flutter/material.dart';
import 'recipe_detail_page.dart';

const Color kPinkButtonColor = Color(0xFFFFC7B9);
/// 새로 추가된 "검색 화면"
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kPinkButtonColor,
        title: const Text(
          '검색',
          style: TextStyle(color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Center(
        // 검색화면에 검색바 하나만 크게 배치 (예시)
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black26),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: "검색어를 입력하세요",
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: Icon(Icons.search, color: Colors.black45),
            ),
          ),
        ),
      ),
    );
  }
}