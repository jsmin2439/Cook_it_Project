import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ───────────────────────────────────────── 상수 (기존 프로젝트 값 재사용)
const Color kBackgroundColor = Color(0xFFFFFFFF);
const Color kCardColor = Color(0xFFFFECD0);
const Color kPinkButtonColor = Color(0xFFFFC7B9);
const Color kTextColor = Colors.black87;
const double kBorderRadius = 16.0;
const Color kAccentColor = Color(0xFF6B8E23);

// ───────────────────────────────────────── 위젯
class AllergyHateCategoryScreen extends StatefulWidget {
  final List<String> initialSelectedCategories; // 이미 선택된 카테고리
  final List<String> initialCheckedIngredients; // 이미 체크된 개별 재료

  const AllergyHateCategoryScreen({
    Key? key,
    required this.initialSelectedCategories,
    required this.initialCheckedIngredients,
  }) : super(key: key);

  @override
  State<AllergyHateCategoryScreen> createState() =>
      _IngredientCategorySelectScreenState();
}

class _IngredientCategorySelectScreenState
    extends State<AllergyHateCategoryScreen> {
  // ───────── state
  late Future<Map<String, List<String>>> _dataFuture;
  Map<String, List<String>>? _categoryData;
  late final Set<String> _checkedIngredients =
      widget.initialCheckedIngredients.toSet();

  // ───────── init
  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData().then((map) {
      _categoryData = map;

      // 초기 카테고리(전부 선택) 반영
      for (final cat in widget.initialSelectedCategories) {
        _checkedIngredients.addAll(map[cat] ?? const []);
      }
      return map;
    });
  }

  // Firestore → {카테고리: [재료 …]}
  Future<Map<String, List<String>>> _loadData() async {
    final snap =
        await FirebaseFirestore.instance.collection('ingredients').get();
    final map = <String, List<String>>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final cat = data['카테고리']?.toString().trim() ?? '';
      final name = data['식재료']?.toString().trim() ?? '';
      if (cat.isEmpty || name.isEmpty) continue;
      map.putIfAbsent(cat, () => []).add(name);
    }

    for (final e in map.entries) {
      e.value.sort();
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return sorted;
  }

  // 현재 ‘완전히 선택된’ 카테고리
  List<String> _fullyCheckedCategories() {
    if (_categoryData == null) return [];
    final res = <String>[];
    _categoryData!.forEach((cat, ingreds) {
      if (ingreds.every(_checkedIngredients.contains)) res.add(cat);
    });
    return res..sort();
  }

  // 3-state 체크 계산
  CheckboxState _categoryState(List<String> ingreds) {
    final c = ingreds.where(_checkedIngredients.contains).length;
    if (c == 0) return CheckboxState.unchecked;
    if (c == ingreds.length) return CheckboxState.checked;
    return CheckboxState.partial;
  }

  // ───────── build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildAppBar(),
      body: FutureBuilder<Map<String, List<String>>>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text('카테고리가 없습니다'));
          }

          final data = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
            itemCount: data.length,
            itemBuilder: (context, idx) {
              final cat = data.keys.elementAt(idx);
              final ingreds = data[cat]!;
              final state = _categoryState(ingreds);

              return ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                childrenPadding:
                    const EdgeInsets.only(left: 12, right: 12, bottom: 4),
                iconColor: kAccentColor,
                collapsedIconColor: kAccentColor,
                title: Row(
                  children: [
                    _TriStateCheckbox(
                      value: state,
                      onChanged: (newState) {
                        setState(() {
                          if (newState == CheckboxState.checked) {
                            _checkedIngredients.addAll(ingreds);
                          } else {
                            _checkedIngredients.removeAll(ingreds);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(cat,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kTextColor,
                        )),
                  ],
                ),
                children: ingreds.map((ing) {
                  final checked = _checkedIngredients.contains(ing);
                  return Card(
                    elevation: 0,
                    color: kCardColor.withOpacity(0.55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      activeColor: kAccentColor,
                      title: Text(ing,
                          style: const TextStyle(
                            fontSize: 14,
                            color: kTextColor,
                          )),
                      value: checked,
                      onChanged: (_) => setState(() {
                        checked
                            ? _checkedIngredients.remove(ing)
                            : _checkedIngredients.add(ing);
                      }),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kAccentColor),
        title: const Text(
          '제외할 식재료 카테고리',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: kAccentColor,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(context, {
              'categories': _fullyCheckedCategories(),
              'ingredients': _checkedIngredients.toList()..sort(),
            }),
            child: const Text('저장'),
          ),
        ],
      );
}

// ───────── util ────────────────────────────────────────────────
enum CheckboxState { unchecked, partial, checked }

class _TriStateCheckbox extends StatelessWidget {
  final CheckboxState value;
  final ValueChanged<CheckboxState> onChanged;

  const _TriStateCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (value) {
      case CheckboxState.checked:
        icon = Icons.check_box;
        break;
      case CheckboxState.partial:
        icon = Icons.indeterminate_check_box;
        break;
      default:
        icon = Icons.check_box_outline_blank;
    }
    return InkWell(
      onTap: () {
        final next = value == CheckboxState.checked
            ? CheckboxState.unchecked
            : CheckboxState.checked;
        onChanged(next);
      },
      borderRadius: BorderRadius.circular(4),
      child: Icon(icon, color: kAccentColor),
    );
  }
}
