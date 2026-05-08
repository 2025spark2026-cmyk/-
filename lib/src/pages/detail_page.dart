import 'package:central_festival_app/src/services/board_service.dart';
import 'package:central_festival_app/src/services/session_service.dart';
import 'package:central_festival_app/src/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _board = BoardService();
  final _commentController = TextEditingController();
  bool _commenting = false;
  bool _liking = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _comment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _commenting) return;

    setState(() => _commenting = true);
    try {
      await _board.addComment(
        postId: widget.postId,
        author: SessionService.currentUserId ?? 'Guest',
        text: text,
      );
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _commenting = false);
    }
  }

  Future<void> _toggleLike({required bool liked}) async {
    final userId = SessionService.currentUserId;
    if (userId == null || _liking) return;

    setState(() => _liking = true);
    try {
      await _board.toggleLike(
        postId: widget.postId,
        userId: userId,
        currentlyLiked: liked,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('좋아요를 반영하지 못했습니다: $e')));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('게시글')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _board.watchPost(widget.postId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('게시글을 불러오지 못했습니다: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('게시글이 더 이상 존재하지 않습니다.'));
          }

          final data = snapshot.data!.data() ?? {};
          final comments = _readComments(data['comments']);
          final likedBy = List<String>.from(data['likedBy'] ?? []);
          final userId = SessionService.currentUserId;
          final liked = userId != null && likedBy.contains(userId);
          final likes = (data['likes'] as num?)?.toInt() ?? likedBy.length;
          final isNotice = data['isNotice'] == true;
          final isPopular =
              !isNotice && likes >= BoardService.popularLikeThreshold;
          final timestamp = data['timestamp'];

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isNotice)
                          _Badge(
                            icon: Icons.campaign_rounded,
                            label: '공지',
                            color: AppTheme.crimson,
                          ),
                        if (isPopular)
                          const _Badge(
                            icon: Icons.local_fire_department_rounded,
                            label: '인기게시물',
                            color: AppTheme.teal,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (data['title'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${data['authorName'] ?? 'Guest'} · ${_formatTime(timestamp)}",
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 22),
                    if ((data['imageUrl'] ?? '').toString().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          data['imageUrl'].toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const EmptyImageState(),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    Text(
                      (data['content'] ?? '').toString(),
                      style: const TextStyle(fontSize: 17, height: 1.65),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: userId == null || _liking
                              ? null
                              : () => _toggleLike(liked: liked),
                          icon: Icon(
                            liked
                                ? Icons.favorite
                                : Icons.favorite_border_rounded,
                            color: liked ? Colors.red : null,
                          ),
                          label: Text('$likes'),
                        ),
                      ],
                    ),
                    const Divider(height: 38),
                    Text(
                      '댓글 ${comments.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final comment in comments)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFFF1F1F1),
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (comment['author'] ?? 'Guest').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.crimson,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text((comment['text'] ?? '').toString()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  decoration: const BoxDecoration(
                    color: AppTheme.panel,
                    border: Border(top: BorderSide(color: AppTheme.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '댓글 달기',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _commenting ? null : _comment,
                        color: AppTheme.crimson,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _readComments(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((comment) => Map<String, dynamic>.from(comment))
        .toList();
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';
    return DateFormat('M/d HH:mm').format(value.toDate());
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class EmptyImageState extends StatelessWidget {
  const EmptyImageState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      color: const Color(0xFFF4ECE2),
      alignment: Alignment.center,
      child: const Text(
        '이미지를 불러오지 못했습니다.',
        style: TextStyle(color: AppTheme.muted),
      ),
    );
  }
}
