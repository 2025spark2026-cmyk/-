import 'dart:io';
import 'dart:typed_data';

import 'package:central_festival_app/src/pages/detail_page.dart';
import 'package:central_festival_app/src/services/board_service.dart';
import 'package:central_festival_app/src/services/session_service.dart';
import 'package:central_festival_app/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class WritePage extends StatefulWidget {
  const WritePage({super.key});

  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  final _board = BoardService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  File? _image;
  Uint8List? _webImage;
  bool _anonymous = true;
  bool _notice = false;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1800,
    );

    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _webImage = bytes;
      });
    } else {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final authorId = SessionService.currentUserId;
    if (title.isEmpty || content.isEmpty || authorId == null) {
      _message('Please enter a title and content.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final postId = await _board.createPost(
        title: title,
        content: content,
        authorId: authorId,
        anonymous: _anonymous,
        notice: _notice,
        image: _image,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DetailPage(postId: postId)),
      );
    } catch (e) {
      _message('게시를 실패했습니다.: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('작성하기'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text('게시글', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _titleController,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              hintText: '제목',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const Divider(height: 24),
          TextField(
            controller: _contentController,
            minLines: 8,
            maxLines: 18,
            decoration: const InputDecoration(
              hintText: '글을 입력하세요.',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 172,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line),
              ),
              child: (_image == null && _webImage == null)
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 42,
                          color: AppTheme.muted,
                        ),
                        SizedBox(height: 8),
                        Text('사진 추가'),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: kIsWeb
                          ? Image.memory(_webImage!, fit: BoxFit.cover)
                          : Image.file(_image!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (SessionService.isAdmin)
            SwitchListTile.adaptive(
              value: _notice,
              activeThumbColor: AppTheme.crimson,
              title: const Text('공지로 올리기'),
              onChanged: (value) => setState(() {
                _notice = value;
                if (value) _anonymous = false;
              }),
            ),
          if (!_notice)
            SwitchListTile.adaptive(
              value: _anonymous,
              activeThumbColor: AppTheme.crimson,
              title: const Text('익명으로 올리기'),
              onChanged: (value) => setState(() => _anonymous = value),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('게시하기'),
          ),
        ],
      ),
    );
  }
}
