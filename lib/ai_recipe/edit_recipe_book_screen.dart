// lib/screens/edit_recipe_book_screen.dart
//
//  EditRecipeBook  – pastel redesign 2025
//  * 밝은 배경·카드 컬러
//  * STEP 카드 상단 휴지통 아이콘 삭제
//  * STEP 사이·끝에 ‘삽입’ 버튼
//  * ReorderableListView 지원
//  * HEIC 변환·sRGB 재인코딩 → Firebase Storage 업로드
//  * Firestore savedRecipes 배열 업데이트
// ─────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:heif_converter/heif_converter.dart';

/// 내부 모델 : 한 STEP 에 들어갈 데이터
class _StepData {
  _StepData({required this.text, this.networkUrl, this.localFile});

  String text; // 조리 설명
  String? networkUrl; // 원본 이미지를 그대로 쓰는 경우
  File? localFile; // 새로 선택된 이미지
}

/// ─────────────────────────────────────────────
///                    Stateful
/// ─────────────────────────────────────────────
class EditRecipeBook extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> originalRecipe;

  const EditRecipeBook({
    super.key,
    required this.userId,
    required this.originalRecipe,
  });

  @override
  State<EditRecipeBook> createState() => _EditRecipeBookState();
}

class _EditRecipeBookState extends State<EditRecipeBook> {
  /* 기본 정보 컨트롤러 */
  final _nameCtrl = TextEditingController();
  final _ingCtrl = TextEditingController();
  final _tipCtrl = TextEditingController();

  /* 메인 이미지 */
  String? _mainNetUrl;
  File? _mainLocal;

  /* STEP 리스트 */
  final List<_StepData> _steps = [];

  /* 진행 플래그 */
  bool _saving = false;

  static const _maxSteps = 20;

  //──────────────────────────── init
  @override
  void initState() {
    super.initState();
    final r = widget.originalRecipe;

    _nameCtrl.text = r['RCP_NM'] ?? '';
    _ingCtrl.text = r['RCP_PARTS_DTLS'] ?? '';
    _tipCtrl.text = r['RCP_NA_TIP'] ?? '';
    _mainNetUrl = r['ATT_FILE_NO_MAIN'];

    /* MANUALxx 로드 */
    for (int i = 1; i <= _maxSteps; i++) {
      final idx = i.toString().padLeft(2, '0');
      final t = (r['MANUAL$idx'] ?? '').toString();
      final img = (r['MANUAL_IMG$idx'] ?? '').toString();
      if (t.isEmpty && img.isEmpty) continue;
      _steps.add(_StepData(text: t, networkUrl: img.isEmpty ? null : img));
    }
    if (_steps.isEmpty) _steps.add(_StepData(text: ''));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ingCtrl.dispose();
    _tipCtrl.dispose();
    super.dispose();
  }

  //──────────────────────────── build
  @override
  Widget build(BuildContext context) {
    /* 부드러운 파스텔 배경 */
    const bgColor = Color(0xFFFFFAF3);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cs.primaryContainer.withOpacity(.85),
        foregroundColor: cs.onPrimaryContainer,
        title: const Text('레시피 편집'),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save_rounded),
                  onPressed: _saveRecipe,
                ),
        ],
      ),

      /* STEP 추가 FAB */
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _insertStep(_steps.length),
        label: const Text('STEP 추가'),
        icon: const Icon(Icons.add),
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
      ),

      /* 본문 : ReorderableListView */
      body: ReorderableListView(
        padding: const EdgeInsets.only(top: 16, bottom: 120),
        onReorder: _reorder,
        children: [
          _buildBasicCard(cs).withKey(const ValueKey('basic')),
          const SizedBox(height: 16).withKey(const ValueKey('sp0')),
          for (int i = 0; i < _steps.length; i++) ...[
            _buildStepCard(i, cs).withKey(ValueKey('step_$i')),
            if (i != _steps.length - 1)
              _insertBtn(i + 1).withKey(ValueKey('ins_$i')),
          ],
          _insertBtn(_steps.length, tail: true)
              .withKey(const ValueKey('ins_tail')),
        ],
      ),
    );
  }

  //──────────────────────────── Widgets
  Widget _buildBasicCard(ColorScheme cs) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: cs.primaryContainer.withOpacity(.35),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: InkWell(
                onTap: _pickMainImage,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _imageWidget(_mainLocal, _mainNetUrl,
                      height: 190, width: double.infinity),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _textField(_nameCtrl, '레시피 이름', Icons.edit),
            const SizedBox(height: 14),
            _textField(_ingCtrl, '재료 (쉼표로 분리)', Icons.kitchen, lines: 3),
            const SizedBox(height: 14),
            _textField(_tipCtrl, 'TIP', Icons.lightbulb, lines: 3),
          ]),
        ),
      );

  Widget _buildStepCard(int idx, ColorScheme cs) {
    final s = _steps[idx];

    return Card(
      key: ValueKey('card_$idx'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cs.secondaryContainer.withOpacity(.30),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('STEP ${idx + 1}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            IconButton(
              tooltip: '이미지 선택',
              onPressed: () => _pickStepImage(idx),
              icon: const Icon(Icons.photo),
            ),
            IconButton(
              tooltip: '삭제',
              onPressed: () => setState(() => _steps.removeAt(idx)),
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            ),
          ]),
          if (s.localFile != null || s.networkUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _imageWidget(
                s.localFile,
                s.networkUrl,
                height: 170,
                width: double.infinity,
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: TextEditingController(text: s.text)
              ..selection = TextSelection.collapsed(offset: s.text.length),
            onChanged: (v) => s.text = v,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '조리 설명',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _insertBtn(int idx, {bool tail = false}) => Padding(
        padding: EdgeInsets.fromLTRB(16, tail ? 16 : 4, 16, tail ? 60 : 4),
        child: OutlinedButton.icon(
          onPressed: () => _insertStep(idx),
          icon: const Icon(Icons.add),
          label: Text(tail ? 'STEP 추가' : '여기에 STEP 삽입'),
        ),
      );

  Widget _textField(TextEditingController c, String label, IconData ic,
          {int lines = 1}) =>
      TextField(
        controller: c,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(ic),
          filled: true,
          fillColor: Colors.white,
        ),
      );

  Widget _imageWidget(File? local, String? net,
      {double? height, double? width}) {
    if (local != null) {
      return Image.file(local, fit: BoxFit.cover, height: height, width: width);
    }
    if (net != null && net.isNotEmpty) {
      return Image.network(net,
          fit: BoxFit.cover,
          height: height,
          width: width,
          errorBuilder: (_, __, ___) => _noImg(height, width));
    }
    return _noImg(height, width);
  }

  Widget _noImg(double? h, double? w) => Container(
        height: h,
        width: w,
        color: Colors.grey[100],
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );

  //──────────────────────────── reorder / insert
  void _reorder(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final item = _steps.removeAt(oldIdx);
      _steps.insert(newIdx, item);
    });
  }

  void _insertStep(int idx) {
    if (_steps.length >= _maxSteps) return;
    setState(() => _steps.insert(idx, _StepData(text: '')));
  }

  //──────────────────────────── image pick helper
  Future<void> _pickMainImage() async {
    final f = await _pickFromGallery();
    if (f != null)
      setState(() {
        _mainLocal = f;
        _mainNetUrl = null;
      });
  }

  Future<void> _pickStepImage(int idx) async {
    final f = await _pickFromGallery();
    if (f != null)
      setState(() {
        _steps[idx].localFile = f;
        _steps[idx].networkUrl = null;
      });
  }

  Future<File?> _pickFromGallery() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return null;
    File f = File(x.path);

    final ext = f.path.split('.').last.toLowerCase();
    if (ext == 'heic' || ext == 'heif') {
      final jpg = await HeifConverter.convert(f.path);
      if (jpg != null) f = File(jpg);
    }

    final decoded = img.decodeImage(await f.readAsBytes());
    if (decoded == null) return f;

    final bytes = img.encodeJpg(decoded, quality: 95);
    final tmp = await getTemporaryDirectory();
    return File('${tmp.path}/${DateTime.now().millisecondsSinceEpoch}.jpg')
      ..writeAsBytesSync(bytes);
  }

  //──────────────────────────── SAVE
  Future<void> _saveRecipe() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final up = Map<String, dynamic>.from(widget.originalRecipe)
        ..['RCP_NM'] = _nameCtrl.text.trim()
        ..['RCP_PARTS_DTLS'] = _ingCtrl.text.trim()
        ..['RCP_NA_TIP'] = _tipCtrl.text.trim();

      if (_mainLocal != null) {
        up['ATT_FILE_NO_MAIN'] = await _upload(_mainLocal!, 'main');
      }

      for (int i = 0; i < _maxSteps; i++) {
        final idx = (i + 1).toString().padLeft(2, '0');
        if (i < _steps.length) {
          final s = _steps[i];
          up['MANUAL$idx'] = s.text.trim();
          up['MANUAL_IMG$idx'] = s.localFile != null
              ? await _upload(s.localFile!, 'step_$idx')
              : (s.networkUrl ?? '');
        } else {
          up['MANUAL$idx'] = '';
          up['MANUAL_IMG$idx'] = '';
        }
      }

      await _updateSaved(up);

      if (mounted) Navigator.pop(context, up);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _upload(File f, String tag) async {
    final ref = storage.FirebaseStorage.instance
        .ref('recipes/${widget.userId}/${tag}_${DateTime.now()}.jpg');
    await ref.putFile(f);
    return await ref.getDownloadURL();
  }

  Future<void> _updateSaved(Map<String, dynamic> up) async {
    final doc =
        FirebaseFirestore.instance.collection('user').doc(widget.userId);
    final snap = await doc.get();
    List<dynamic> list = List.from(snap.data()?['savedRecipes'] ?? []);
    final seq = up['RCP_SEQ'].toString();

    bool found = false;
    for (int i = 0; i < list.length; i++) {
      if (list[i]['RCP_SEQ'].toString() == seq) {
        list[i] = up;
        found = true;
        break;
      }
    }
    if (!found) list.add(up);

    await doc.update({'savedRecipes': list});
  }
}

//──────────────────────────── 작은 extension
extension _WithKey on Widget {
  Widget withKey(Key k) => SizedBox(key: k, child: this);
}
