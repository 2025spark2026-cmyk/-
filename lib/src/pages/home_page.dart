import 'package:central_festival_app/src/pages/detail_page.dart';
import 'package:central_festival_app/src/pages/login_page.dart' as auth;
import 'package:central_festival_app/src/pages/schedule_detail_page.dart';
import 'package:central_festival_app/src/pages/write_page.dart';
import 'package:central_festival_app/src/services/board_service.dart';
import 'package:central_festival_app/src/services/schedule_service.dart';
import 'package:central_festival_app/src/services/session_service.dart';
import 'package:central_festival_app/src/theme/app_theme.dart';
import 'package:central_festival_app/src/widgets/empty_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController();
  final _board = BoardService();
  final _schedule = ScheduleService();
  int _index = 0;

  static const _titles = ['게시판', '인기', '지도', '프로필', '일정'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showNotice() async {
    if (SessionService.noticePopupShown) return;

    try {
      final notice = await _board.latestNotice();
      if (!mounted || notice == null) return;

      SessionService.noticePopupShown = true;
      final data = notice.data();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('최근 공지'),
          content: Text((data['title'] ?? '새 공지가 있습니다.').toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (_) {
      // 공지 팝업 실패가 홈 화면 진입을 막지 않도록 둔다.
    }
  }

  void _go(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: PageView(
        controller: _pageController,
        onPageChanged: (value) => setState(() => _index = value),
        children: [
          _BoardTab(board: _board),
          _PopularTab(board: _board),
          const _MapTab(),
          _ProfileTab(board: _board),
          _ScheduleTab(schedule: _schedule),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _go,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum_rounded),
            label: '게시판',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_rounded),
            activeIcon: Icon(Icons.trending_up_rounded),
            label: '인기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: '프로필',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today_rounded),
            label: '일정',
          ),
        ],
      ),
      floatingActionButton: switch (_index) {
        0 => FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WritePage()),
          ),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('글쓰기'),
        ),
        4 when SessionService.isAdmin => FloatingActionButton.extended(
          onPressed: () => _showScheduleSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('일정 추가'),
        ),
        _ => null,
      },
    );
  }

  Future<void> _showScheduleSheet(BuildContext context) async {
    final time = TextEditingController();
    final title = TextEditingController();
    final location = TextEditingController();
    final description = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '일정 추가',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: time,
                  decoration: const InputDecoration(labelText: '시간'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(labelText: '위치'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () async {
                    if (title.text.trim().isEmpty || time.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('시간과 제목을 입력해 주세요.')),
                        );
                      return;
                    }

                    await _schedule.add(
                      time: time.text.trim(),
                      title: title.text.trim(),
                      location: location.text.trim(),
                      description: description.text.trim(),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('저장하기'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      time.dispose();
      title.dispose();
      location.dispose();
      description.dispose();
    }
  }
}

class _BoardTab extends StatefulWidget {
  const _BoardTab({required this.board});

  final BoardService board;

  @override
  State<_BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<_BoardTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.board.watchPosts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            title: '게시글을 불러오지 못했습니다',
            message: snapshot.error.toString(),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs =
            snapshot.data!.docs
                .where(
                  (doc) => !SessionService.isBlocked(
                      (doc.data()['authorId'] ?? '').toString(),
                    ) && !BoardService.isDeleted(doc.data()),
                )
                .toList()
              ..sort(BoardService.comparePosts);
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.forum_outlined,
            title: '게시글이 없습니다',
            message: '글쓰기 버튼으로 첫 게시글을 작성해 보세요.',
          );
        }

        final filteredDocs = docs
            .where((doc) => _matchesSearch(doc.data(), _query))
            .toList();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: filteredDocs.isEmpty ? 2 : filteredDocs.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: '게시글 검색',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '검색어 지우기',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              );
            }

            if (filteredDocs.isEmpty) {
              return const EmptyState(
                icon: Icons.search_off_rounded,
                title: '검색 결과가 없습니다',
                message: '다른 검색어로 다시 찾아보세요.',
              );
            }

            return _PostCard(doc: filteredDocs[index - 1]);
          },
        );
      },
    );
  }

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;
    final target = [
      data['title'],
      data['content'],
      data['authorName'],
      data['authorId'],
    ].join(' ').toLowerCase();
    return target.contains(query.toLowerCase());
  }
}

class _PopularTab extends StatelessWidget {
  const _PopularTab({required this.board});

  final BoardService board;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: board.watchPopularPosts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            title: '인기게시물을 불러오지 못했습니다',
            message: snapshot.error.toString(),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          if (SessionService.isBlocked((data['authorId'] ?? '').toString())) {
            return false;
          }
          if (BoardService.isDeleted(data)) {
            return false;
          }
          final likes = (data['likes'] as num?)?.toInt() ?? 0;
          return data['isNotice'] != true &&
              likes >= BoardService.popularLikeThreshold;
        }).toList()..sort(_comparePopularPosts);

        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.trending_up_rounded,
            title: '인기게시물이 없습니다',
            message: '좋아요 10개 이상인 일반 게시글만 표시됩니다.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _PostCard(doc: docs[index], forcePopularBadge: true);
          },
        );
      },
    );
  }

  static int _comparePopularPosts(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aData = a.data();
    final bData = b.data();
    final aLikes = (aData['likes'] as num?)?.toInt() ?? 0;
    final bLikes = (bData['likes'] as num?)?.toInt() ?? 0;
    final byLikes = bLikes.compareTo(aLikes);
    if (byLikes != 0) return byLikes;
    return BoardService.compareByTime(aData, bData);
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.doc, this.forcePopularBadge = false});

  static const _noticeBackground = Color(0xFFFFF1F3);
  static const _noticeBorder = Color(0xFFE04663);
  static const _popularBackground = Color(0xFFEFFFF8);
  static const _popularBorder = Color(0xFF1FAE74);

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool forcePopularBadge;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final isNotice = data['isNotice'] == true;
    final likes = (data['likes'] as num?)?.toInt() ?? 0;
    final isPopular =
        forcePopularBadge ||
        (!isNotice && likes >= BoardService.popularLikeThreshold);

    final highlightColor = isNotice
        ? AppTheme.primary
        : (isPopular ? AppTheme.teal : AppTheme.line);

    return Card(
      color: isNotice
          ? _noticeBackground
          : (isPopular ? _popularBackground : AppTheme.panel),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isNotice
              ? _noticeBorder
              : (isPopular ? _popularBorder : AppTheme.line),
          width: (isNotice || isPopular) ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailPage(postId: doc.id)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isNotice || isPopular)
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isNotice)
                            const _MiniBadge(
                              label: '공지',
                              color: AppTheme.primary,
                              icon: Icons.campaign_rounded,
                              filled: true,
                            )
                          else if (isPopular)
                            const _MiniBadge(
                              label: '인기',
                              color: AppTheme.teal,
                              icon: Icons.local_fire_department_rounded,
                              filled: true,
                            ),
                          if (isNotice || isPopular) const Spacer(),
                          const Icon(
                            Icons.favorite_border_rounded,
                            size: 17,
                            color: AppTheme.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likes',
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        (data['title'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isNotice
                              ? AppTheme.primary
                              : (isPopular ? AppTheme.teal : AppTheme.ink),
                          fontSize: 16,
                          fontWeight: (isNotice || isPopular)
                              ? FontWeight.w900
                              : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        (data['content'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 5,
      minScale: 0.7,
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.75,
          child: Container(
            margin: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.line),
            ),
            child: CustomPaint(painter: _FestivalMapPainter()),
          ),
        ),
      ),
    );
  }
}

class _FestivalMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .16)
      ..quadraticBezierTo(
        size.width * .68,
        size.height * .24,
        size.width * .76,
        size.height * .48,
      )
      ..quadraticBezierTo(
        size.width * .62,
        size.height * .72,
        size.width * .22,
        size.height * .82,
      );
    canvas.drawPath(path, road);

    final spots = [
      (Offset(size.width * .26, size.height * .22), '입구'),
      (Offset(size.width * .68, size.height * .34), '무대'),
      (Offset(size.width * .72, size.height * .56), '푸드존'),
      (Offset(size.width * .40, size.height * .76), '부스'),
    ];

    final markerPaint = Paint()..color = AppTheme.primary;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final spot in spots) {
      canvas.drawCircle(spot.$1, 13, markerPaint);
      textPainter.text = TextSpan(
        text: spot.$2,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, spot.$1 + const Offset(-18, 22));
    }

    final title = TextPainter(
      text: const TextSpan(
        text: '축제 지도',
        style: TextStyle(
          color: AppTheme.ink,
          fontSize: 25,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, const Offset(24, 24));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.board});

  final BoardService board;

  @override
  Widget build(BuildContext context) {
    final userId = SessionService.currentUserId ?? 'Guest';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: board.watchUserPosts(userId),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final myPosts = docs
            .where((doc) => !BoardService.isDeleted(doc.data()))
            .toList()
          ..sort((a, b) => BoardService.compareByTime(a.data(), b.data()));
        final likeCount = myPosts.fold<int>(
          0,
          (total, doc) => total + ((doc.data()['likes'] as num?)?.toInt() ?? 0),
        );
        final commentCount = myPosts.fold<int>(
          0,
          (total, doc) =>
              total + ((doc.data()['comments'] as List?)?.length ?? 0),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFE5E7EB),
                          child: Text(
                            userId.isEmpty ? '?' : userId[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userId,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                SessionService.isAdmin ? '관리자 계정' : '학생 계정',
                                style: const TextStyle(color: AppTheme.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _ProfileStat(label: '게시글', value: '${myPosts.length}'),
                        _ProfileStat(label: '좋아요', value: '$likeCount'),
                        _ProfileStat(label: '댓글', value: '$commentCount'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _ProfileRow(
                    icon: Icons.badge_outlined,
                    label: '아이디',
                    value: userId,
                  ),
                  const Divider(height: 1, indent: 56),
                  _ProfileRow(
                    icon: Icons.verified_user_outlined,
                    label: '권한',
                    value: SessionService.isAdmin ? '관리자' : '학생',
                  ),
                  const Divider(height: 1, indent: 56),
                  _ProfileRow(
                    icon: Icons.notifications_none_rounded,
                    label: '공지 알림',
                    value: '앱 실행 시 표시',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (SessionService.isAdmin) ...[
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ReportInboxPage(board: board),
                  ),
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('신고함 확인'),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                await SessionService.clear();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const auth.LoginPage()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('로그아웃'),
            ),
            const SizedBox(height: 24),
            const Text(
              '내가 쓴 글',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (myPosts.isEmpty)
              const EmptyState(
                icon: Icons.article_outlined,
                title: '작성한 글이 없습니다',
                message: '게시판에서 첫 글을 남겨보세요.',
              )
            else
              ...myPosts
                  .take(5)
                  .map(
                    (doc) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PostCard(doc: doc),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.schedule});

  final ScheduleService schedule;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: schedule.watchSchedules(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            title: '일정을 불러오지 못했습니다',
            message: snapshot.error.toString(),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.calendar_today_outlined,
            title: '아직 추가된 일정이 없습니다',
            message: '관리자 계정에서 일정을 추가할 수 있습니다.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _ScheduleNoticeHeader();
            }

            final doc = docs[index - 1];
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ScheduleAlertCard(doc: doc),
            );
          },
        );
      },
    );
  }
}

class _ScheduleNoticeHeader extends StatelessWidget {
  const _ScheduleNoticeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7FB3E8)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF0F6CBD),
            child: Icon(Icons.campaign_rounded, color: Colors.white),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학교 주요 알림',
                  style: TextStyle(
                    color: Color(0xFF0B3D66),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '행사 시간, 장소, 변경사항을 먼저 확인하세요.',
                  style: TextStyle(color: Color(0xFF4B6478), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleAlertCard extends StatelessWidget {
  const _ScheduleAlertCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final time = (data['time'] ?? '').toString();
    final title = (data['title'] ?? '').toString();
    final location = (data['location'] ?? '').toString();
    final description = (data['description'] ?? '').toString();

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD8E7F3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScheduleDetailPage(scheduleId: doc.id),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: const Color(0xFF0F6CBD)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F6CBD),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              time,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 17,
                              color: Color(0xFF0F6CBD),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportInboxPage extends StatelessWidget {
  const _ReportInboxPage({required this.board});

  final BoardService board;

  @override
  Widget build(BuildContext context) {
    if (!SessionService.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('관리자만 확인할 수 있습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('신고함')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: board.watchReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.lock_outline_rounded,
              title: '신고함을 불러오지 못했습니다',
              message:
                  'Firestore reports 읽기 권한을 확인해 주세요.\n${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!.docs.toList()
            ..sort(BoardService.compareReports);
          if (reports.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: '접수된 신고가 없습니다',
              message: '게시글 또는 댓글 신고가 들어오면 이곳에 표시됩니다.',
            );
          }

          final pendingCount = reports
              .where((doc) => (doc.data()['status'] ?? 'pending') != 'resolved')
              .length;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: reports.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ReportInboxHeader(
                  totalCount: reports.length,
                  pendingCount: pendingCount,
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ReportCard(board: board, doc: reports[index - 1]),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportInboxHeader extends StatelessWidget {
  const _ReportInboxHeader({
    required this.totalCount,
    required this.pendingCount,
  });

  final int totalCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F6),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD3DD)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
            ),
            child: const Icon(Icons.flag_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '신고함',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '대기 $pendingCount건 · 전체 $totalCount건',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.board, required this.doc});

  final BoardService board;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final status = (data['status'] ?? 'pending').toString();
    final targetType = (data['targetType'] ?? '').toString();
    final targetId = (data['targetId'] ?? '').toString();
    final postId = targetId.split(':').first;
    final canOpenTarget = targetType == 'post' || targetType == 'comment';

    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Color(0xFFF0F0F2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MiniBadge(
                  label: status == 'resolved' ? '처리됨' : '대기',
                  color: status == 'resolved' ? AppTheme.teal : AppTheme.primary,
                  icon: status == 'resolved'
                      ? Icons.check_rounded
                      : Icons.flag_outlined,
                  filled: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _targetTypeLabel(targetType),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              (data['targetTitle'] ?? '제목 없음').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '신고자: ${(data['reporterId'] ?? '').toString()}',
              style: const TextStyle(color: AppTheme.muted),
            ),
            Text(
              '사유: ${_reasonLabel((data['reason'] ?? '').toString())}',
              style: const TextStyle(color: AppTheme.muted),
            ),
            finalDetail(data),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canOpenTarget && postId.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailPage(postId: postId),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('대상 열기'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: status == 'resolved'
                      ? null
                      : () => _markResolved(context),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('처리 완료'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget finalDetail(Map<String, dynamic> data) {
    final detail = (data['detail'] ?? '').toString();
    if (detail.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        detail,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(height: 1.45),
      ),
    );
  }

  Future<void> _markResolved(BuildContext context) async {
    try {
      await board.updateReportStatus(reportId: doc.id, status: 'resolved');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('신고 상태를 바꾸지 못했습니다: $e')));
    }
  }

  String _targetTypeLabel(String value) {
    return switch (value) {
      'post' => '게시글 신고',
      'comment' => '댓글 신고',
      'user' => '작성자 신고',
      _ => '신고',
    };
  }

  String _reasonLabel(String value) {
    return switch (value) {
      'harassment' => '욕설/비방/괴롭힘',
      'privacy' => '개인정보 노출',
      'sexual' => '음란/선정적 내용',
      'violence' => '폭력/위협/자해 조장',
      'spam' => '스팸/광고/도배',
      'impersonation' => '사칭/허위정보',
      'other' => '기타',
      _ => value.isEmpty ? '미지정' : value,
    };
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.muted)),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.muted),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(value, style: const TextStyle(color: AppTheme.muted)),
        ],
      ),
    );
  }
}
