import 'package:central_festival_app/src/services/board_service.dart';
import 'package:central_festival_app/src/services/session_service.dart';
import 'package:central_festival_app/src/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _PostAction { reportPost, reportAuthor, blockAuthor }

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
  bool _reporting = false;

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

  Future<void> _showReportSheet({
    required String targetType,
    required String targetId,
    required String targetTitle,
    String? targetOwnerId,
  }) async {
    final reporterId = SessionService.currentUserId;
    if (reporterId == null) {
      _message('로그인 후 신고할 수 있습니다.');
      return;
    }

    final report = await showModalBottomSheet<_ReportInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ReportSheet(),
    );
    if (report == null) return;

    setState(() => _reporting = true);
    try {
      await _board.submitReport(
        targetType: targetType,
        targetId: targetId,
        targetOwnerId: targetOwnerId,
        targetTitle: targetTitle,
        reporterId: reporterId,
        reason: report.reason,
        detail: report.detail,
      );
      if (mounted) _message('신고가 접수되었습니다. 운영자가 검토합니다.');
    } catch (e) {
      if (mounted) _message('신고를 접수하지 못했습니다. $e');
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _blockAuthor(String authorId) async {
    final currentUserId = SessionService.currentUserId;
    if (authorId.isEmpty || authorId == currentUserId) return;

    await SessionService.blockUser(authorId);
    if (!mounted) return;
    setState(() {});
    _message('이 작성자의 게시글과 댓글을 숨겼습니다.');
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
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
          final authorId = (data['authorId'] ?? '').toString();
          final title = (data['title'] ?? '').toString();
          final visibleComments = comments.where((comment) {
            final author = (comment['author'] ?? '').toString();
            return author.isEmpty || !SessionService.isBlocked(author);
          }).toList();
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
                            color: AppTheme.primary,
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
                      title,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${data['authorName'] ?? 'Guest'} · ${_formatTime(timestamp)}",
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ),
                        PopupMenuButton<_PostAction>(
                          tooltip: '게시글 메뉴',
                          enabled: !_reporting,
                          onSelected: (action) {
                            switch (action) {
                              case _PostAction.reportPost:
                                _showReportSheet(
                                  targetType: 'post',
                                  targetId: widget.postId,
                                  targetTitle: title,
                                  targetOwnerId: authorId,
                                );
                                break;
                              case _PostAction.reportAuthor:
                                _showReportSheet(
                                  targetType: 'user',
                                  targetId: authorId,
                                  targetTitle: title,
                                  targetOwnerId: authorId,
                                );
                                break;
                              case _PostAction.blockAuthor:
                                _blockAuthor(authorId);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: _PostAction.reportPost,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.flag_outlined),
                                title: Text('게시글 신고'),
                              ),
                            ),
                            if (authorId.isNotEmpty && authorId != userId) ...[
                              const PopupMenuItem(
                                value: _PostAction.reportAuthor,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.report_gmailerrorred),
                                  title: Text('작성자 신고'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: _PostAction.blockAuthor,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.visibility_off_outlined),
                                  title: Text('작성자 차단'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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
                      '댓글 ${visibleComments.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < visibleComments.length; i++)
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
                                    (visibleComments[i]['author'] ?? 'Guest')
                                        .toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (visibleComments[i]['text'] ?? '')
                                        .toString(),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<_PostAction>(
                              tooltip: '댓글 메뉴',
                              onSelected: (action) {
                                final commentAuthor =
                                    (visibleComments[i]['author'] ?? '')
                                        .toString();
                                switch (action) {
                                  case _PostAction.reportPost:
                                    _showReportSheet(
                                      targetType: 'comment',
                                      targetId: '${widget.postId}:$i',
                                      targetTitle:
                                          (visibleComments[i]['text'] ?? '')
                                              .toString(),
                                      targetOwnerId: commentAuthor,
                                    );
                                    break;
                                  case _PostAction.reportAuthor:
                                    _showReportSheet(
                                      targetType: 'user',
                                      targetId: commentAuthor,
                                      targetTitle:
                                          (visibleComments[i]['text'] ?? '')
                                              .toString(),
                                      targetOwnerId: commentAuthor,
                                    );
                                    break;
                                  case _PostAction.blockAuthor:
                                    _blockAuthor(commentAuthor);
                                    break;
                                }
                              },
                              itemBuilder: (context) {
                                final commentAuthor =
                                    (visibleComments[i]['author'] ?? '')
                                        .toString();
                                return [
                                  const PopupMenuItem(
                                    value: _PostAction.reportPost,
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.flag_outlined),
                                      title: Text('댓글 신고'),
                                    ),
                                  ),
                                  if (commentAuthor.isNotEmpty &&
                                      commentAuthor != userId) ...[
                                    const PopupMenuItem(
                                      value: _PostAction.reportAuthor,
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.report_gmailerrorred,
                                        ),
                                        title: Text('작성자 신고'),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: _PostAction.blockAuthor,
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.visibility_off_outlined,
                                        ),
                                        title: Text('작성자 차단'),
                                      ),
                                    ),
                                  ],
                                ];
                              },
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
                        color: AppTheme.primary,
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

class _ReportInput {
  const _ReportInput({required this.reason, required this.detail});

  final String reason;
  final String detail;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = [
    ('harassment', '욕설/비방/괴롭힘'),
    ('privacy', '개인정보 노출'),
    ('sexual', '음란/선정적 내용'),
    ('violence', '폭력/위협/자해 조장'),
    ('spam', '스팸/광고/도배'),
    ('impersonation', '사칭/허위정보'),
    ('other', '기타'),
  ];

  final _detailController = TextEditingController();
  String _reason = _reasons.first.$1;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      _ReportInput(reason: _reason, detail: _detailController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '신고하기',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '장난이나 가벼운 표현까지 바로 제재하지는 않고, 운영자가 맥락을 보고 검토합니다.',
              style: TextStyle(color: AppTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: '신고 사유'),
              items: [
                for (final reason in _reasons)
                  DropdownMenuItem(value: reason.$1, child: Text(reason.$2)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _reason = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '상세 내용',
                hintText: '운영자가 확인할 수 있게 상황을 간단히 적어주세요.',
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('신고 접수'),
            ),
          ],
        ),
      ),
    );
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
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Text(
        '이미지를 불러오지 못했습니다.',
        style: TextStyle(color: AppTheme.muted),
      ),
    );
  }
}
