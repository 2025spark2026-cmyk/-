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
          title: const Row(
            children: [
              Icon(Icons.campaign_rounded, color: AppTheme.crimson),
              SizedBox(width: 8),
              Text('최근 공지'),
            ],
          ),
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEBD6), AppTheme.surface],
          ),
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: (value) => setState(() => _index = value),
          children: [
            _BoardTab(board: _board),
            _PopularTab(board: _board),
            const _MapTab(),
            const _ProfileTab(),
            _ScheduleTab(schedule: _schedule),
          ],
        ),
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
            icon: Icon(Icons.local_fire_department_outlined),
            activeIcon: Icon(Icons.local_fire_department_rounded),
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
          backgroundColor: AppTheme.crimson,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WritePage()),
          ),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('글쓰기'),
        ),
        4 when SessionService.isAdmin => FloatingActionButton.extended(
          backgroundColor: AppTheme.crimson,
          foregroundColor: Colors.white,
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
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '일정 추가하기',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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

class _BoardTab extends StatelessWidget {
  const _BoardTab({required this.board});

  final BoardService board;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: board.watchPosts(),
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

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.forum_outlined,
            title: '게시글이 없습니다',
            message: '글쓰기 버튼을 눌러 첫 게시글을 작성해 보세요.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: docs.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _SectionHeader(
                icon: Icons.campaign_rounded,
                title: '공지 우선 게시판',
                message: '학생회 공지가 항상 일반 게시글보다 먼저 보입니다.',
                color: AppTheme.crimson,
              );
            }
            final doc = docs[index - 1];
            return _PostCard(doc: doc);
          },
        );
      },
    );
  }
}

class _PopularTab extends StatelessWidget {
  const _PopularTab({required this.board});

  final BoardService board;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: board.watchAllPosts(),
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
          final likes = (data['likes'] as num?)?.toInt() ?? 0;
          return data['isNotice'] != true &&
              likes >= BoardService.popularLikeThreshold;
        }).toList()..sort(_comparePopularPosts);

        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.local_fire_department_outlined,
            title: '인기게시물이 없습니다',
            message: '좋아요 10개 이상인 일반 게시글이 여기에 표시됩니다.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: docs.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _SectionHeader(
                icon: Icons.local_fire_department_rounded,
                title: '인기게시물',
                message: '공지와 분리해서 좋아요 10개 이상 게시글만 모았습니다.',
                color: AppTheme.teal,
              );
            }
            return _PostCard(doc: docs[index - 1], forcePopularBadge: true);
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

    final aTime = aData['timestamp'];
    final bTime = bData['timestamp'];
    final aMillis = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
    final bMillis = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
    return bMillis.compareTo(aMillis);
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.doc, this.forcePopularBadge = false});

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

    return Card(
      color: isNotice ? const Color(0xFFFFF2EC) : AppTheme.panel,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isNotice
              ? AppTheme.crimson
              : const Color(0xFFFFE8BC),
          foregroundColor: isNotice ? Colors.white : AppTheme.ink,
          child: Icon(isNotice ? Icons.campaign : Icons.chat_bubble_outline),
        ),
        title: Row(
          children: [
            if (isNotice)
              const _MiniBadge(label: '공지', color: AppTheme.crimson)
            else if (isPopular)
              const _MiniBadge(label: '인기', color: AppTheme.teal),
            if (isNotice || isPopular) const SizedBox(width: 6),
            Expanded(
              child: Text(
                (data['title'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            (data['content'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_rounded, size: 18, color: Colors.red),
            Text('$likes', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailPage(postId: doc.id)),
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
      ..color = const Color(0xFFE7D2B8)
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

    final markerPaint = Paint()..color = AppTheme.crimson;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final spot in spots) {
      canvas.drawCircle(spot.$1, 15, markerPaint);
      textPainter.text = TextSpan(
        text: spot.$2,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
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
          fontSize: 26,
          fontWeight: FontWeight.w900,
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
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final userId = SessionService.currentUserId ?? 'Guest';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 48,
                backgroundColor: Color(0xFFFFE8BC),
                child: Icon(
                  Icons.person_rounded,
                  size: 58,
                  color: AppTheme.crimson,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userId,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                SessionService.isAdmin ? '관리자 계정' : '학생 계정',
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 28),
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
            ],
          ),
        ),
      ),
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
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: docs.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _SectionHeader(
                icon: Icons.calendar_month_rounded,
                title: '축제 일정',
                message: '공연, 부스, 이벤트 시간을 한눈에 확인하세요.',
                color: AppTheme.gold,
              );
            }
            final doc = docs[index - 1];
            final data = doc.data();
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8BC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (data['time'] ?? '').toString(),
                    style: const TextStyle(
                      color: AppTheme.crimson,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  (data['title'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text((data['location'] ?? '').toString()),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScheduleDetailPage(scheduleId: doc.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            foregroundColor: Colors.white,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color == AppTheme.gold ? AppTheme.ink : color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: AppTheme.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
