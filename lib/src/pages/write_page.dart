import 'dart:typed_data';

import 'package:central_festival_app/src/pages/detail_page.dart';
import 'package:central_festival_app/src/services/board_service.dart';
import 'package:central_festival_app/src/services/session_service.dart';
import 'package:central_festival_app/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class WritePage extends StatefulWidget {
  const WritePage({super.key});

  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  static const _maxImageBytes = BoardService.maxInlineImageBytes;

  final _board = BoardService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageExtension;
  String? _imageContentType;
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
      imageQuality: 35,
      maxWidth: 720,
      maxHeight: 720,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxImageBytes) {
      _message('사진 용량이 너무 큽니다. 더 작은 사진을 선택해 주세요.');
      return;
    }

    setState(() {
      _imageBytes = bytes;
      _imageExtension = _extensionFromName(picked.name);
      _imageContentType = picked.mimeType;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final authorId = SessionService.currentUserId;
    if (title.isEmpty || content.isEmpty || authorId == null) {
      _message('제목과 내용을 입력해 주세요.');
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
        imageBytes: _imageBytes,
        imageExtension: _imageExtension,
        imageContentType: _imageContentType,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DetailPage(postId: postId)),
      );
    } catch (e) {
      if (!mounted) return;
      _message(_submitErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _extensionFromName(String name) {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last : 'jpg';
  }

  String _submitErrorMessage(Object error) {
    if (error is ImageTooLargeException) {
      return error.toString();
    }
    return '게시글을 등록하지 못했습니다: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: const Text(
              '게시',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
              hintText: '글을 입력해 주세요.',
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
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line),
              ),
              child: _imageBytes == null
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
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton.filled(
                            onPressed: () => setState(() {
                              _imageBytes = null;
                              _imageExtension = null;
                              _imageContentType = null;
                            }),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: '사진 제거',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (SessionService.isAdmin)
            SwitchListTile.adaptive(
              value: _notice,
              activeThumbColor: AppTheme.crimson,
              title: const Text('공지로 올리기'),
              subtitle: const Text('공지 글은 일반 게시글과 인기게시물보다 먼저 표시됩니다.'),
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
