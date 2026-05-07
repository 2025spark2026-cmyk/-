import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleService {
  ScheduleService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection('schedules');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSchedules() {
    return _schedules.orderBy('time').snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSchedule(String id) {
    return _schedules.doc(id).snapshots();
  }

  Future<void> add({
    required String time,
    required String title,
    required String location,
    required String description,
  }) {
    return _schedules.add({
      'time': time,
      'title': title,
      'location': location,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) => _schedules.doc(id).delete();
}
