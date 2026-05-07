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

  static const _titles = ['게시판', '지도', '프로필', '일정'];

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
    final notice = await _board.latestNotice();
    if (!mounted || notice == null) return;

    SessionService.noticePopupShown = true;
    final data = notice.data();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: AppTheme.crimson),
            SizedBox(width: 8),
            Text('Latest Notice'),
          ],
        ),
        content: Text(data['title'] ?? 'A notice is available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
          const _MapTab(),
          const _ProfileTab(),
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
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.crimson,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WritePage()),
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('글쓰기'),
            )
          : _index == 3 && SessionService.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.crimson,
              foregroundColor: Colors.white,
              onPressed: () => _showScheduleSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('일정'),
            )
          : null,
    );
  }

  Future<void> _showScheduleSheet(BuildContext context) async {
    final time = TextEditingController();
    final title = TextEditingController();
    final location = TextEditingController();
    final description = TextEditingController();

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
              Text(
                '일정 추가하기',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextField(controller: time, decoration: const InputDecoration(labelText: '시간')),
              const SizedBox(height: 10),
              TextField(controller: title, decoration: const InputDecoration(labelText: '제목')),
              const SizedBox(height: 10),
              TextField(controller: location, decoration: const InputDecoration(labelText: '위치')),
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
            title: 'Failed to load posts',
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
            title: '게시글 없음',
            message: '글쓰기 버튼을 눌러 첫 게시글을 작성해보세요!',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final isNotice = data['isNotice'] == true;
            return Card(
              color: isNotice ? const Color(0xFFFFF5F5) : Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isNotice ? AppTheme.crimson : const Color(0xFFF1F1F1),
                  foregroundColor: isNotice ? Colors.white : AppTheme.ink,
                  child: Icon(isNotice ? Icons.campaign : Icons.chat_bubble_outline),
                ),
                title: Text(
                  data['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    data['content'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetailPage(postId: doc.id)),
                ),
              ),
            );
          },
        );
      },
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
              color: Colors.white,
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
      ..color = const Color(0xFFE7E5E4)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .16)
      ..quadraticBezierTo(size.width * .68, size.height * .24, size.width * .76, size.height * .48)
      ..quadraticBezierTo(size.width * .62, size.height * .72, size.width * .22, size.height * .82);
    canvas.drawPath(path, road);

    final spots = [
      (Offset(size.width * .26, size.height * .22), 'Gate'),
      (Offset(size.width * .68, size.height * .34), 'Stage'),
      (Offset(size.width * .72, size.height * .56), 'Food'),
      (Offset(size.width * .40, size.height * .76), 'Booths'),
    ];

    final markerPaint = Paint()..color = AppTheme.crimson;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final spot in spots) {
      canvas.drawCircle(spot.$1, 15, markerPaint);
      textPainter.text = TextSpan(
        text: spot.$2,
        style: TextStyle(
          color: AppTheme.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, spot.$1 + const Offset(-18, 22));
    }

    final title = TextPainter(
      text: TextSpan(
        text: 'Festival Map',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded, size: 58, color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            Text(
              userId,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              SessionService.isAdmin ? 'Admin account' : 'Student account',
              style: TextStyle(color: AppTheme.muted),
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
              label: const Text('Logout'),
            ),
          ],
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
            title: 'Failed to load schedules',
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
            title: '아직 추가된 일정이 없습니다.',
            message: '관리자는 이 탭에서 일정을 추가할 수 있습니다.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6E9E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data['time'] ?? '',
                    style: TextStyle(
                      color: AppTheme.crimson,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  data['title'] ?? '',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(data['location'] ?? ''),
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
