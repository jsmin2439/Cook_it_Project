import 'package:flutter/material.dart';
import 'package:son_1/screens/feed_upload_screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cook it',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.red,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 5, vsync: this);
  }

  void bottomNavigationItemOnTab(int index) {
    setState(() {
      tabController.index = index;
    });
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('설정 내용을 여기에 추가하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onMenuSelected(String value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(value),
        content: Text('$value 페이지로 이동합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // false를 반환하여 뒤로가기 동작을 차단합니다.
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFFFF9800),
          title: Row(
            children: [
              const SizedBox(width: 8),
              const Text(
                'Cook it',
                style: TextStyle(
                  fontWeight: FontWeight.bold, // 텍스트를 굵게 설정
                  fontSize: 20.0,             // 텍스트 크기 조정 (옵션)
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: _openSettings,
              tooltip: 'Settings',
            ),
          ],
        ),
        body: TabBarView(
          controller: tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            Center(child: Text('Home')),
            Center(child: Text('Category')),
            Center(child: Text('Camera')),
            Center(child: Text('Favorite')),
            FeedUploadScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: tabController.index,
          onTap: bottomNavigationItemOnTab,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Category'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Receipt'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorite'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
          ],
        ),
      ),
    );
  }
}
