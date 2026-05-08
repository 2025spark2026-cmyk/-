import 'package:central_festival_app/src/services/schedule_service.dart';
import 'package:central_festival_app/src/services/session_service.dart';
import 'package:central_festival_app/src/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScheduleDetailPage extends StatelessWidget {
  ScheduleDetailPage({super.key, required this.scheduleId});

  final String scheduleId;
  final ScheduleService _schedule = ScheduleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일정 상세')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _schedule.watchSchedule(scheduleId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('일정을 불러오지 못했습니다: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('일정이 더 이상 존재하지 않습니다.'));
          }
          final data = snapshot.data!.data() ?? {};
          final description = (data['description'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (data['time'] ?? '').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                (data['title'] ?? '').toString(),
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppTheme.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (data['location'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 46),
              const Text(
                '설명',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                description.isEmpty ? '등록된 설명이 없습니다.' : description,
                style: const TextStyle(fontSize: 16, height: 1.65),
              ),
              if (SessionService.isAdmin) ...[
                const SizedBox(height: 38),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () async {
                    await _schedule.delete(scheduleId);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('일정 삭제하기'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
