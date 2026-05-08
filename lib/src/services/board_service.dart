import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BoardService {
  BoardService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPosts() {
    return _posts
        .orderBy('isNotice', descending: true)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPost(String id) {
    return _posts.doc(id).snapshots();
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> latestNotice() async {
    final result = await _posts
        .where('isNotice', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    return result.docs.isEmpty ? null : result.docs.first;
  }

  Future<String> createPost({
    required String title,
    required String content,
    required String authorId,
    required bool anonymous,
    required bool notice,
    Uint8List? imageBytes,
  }) async {
    var imageUrl = '';
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final path = 'posts/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref(path);
      await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      imageUrl = await ref.getDownloadURL();
    }

    final doc = await _posts.add({
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'authorName': notice ? '학생회' : (anonymous ? '익명' : authorId),
      'authorId': authorId,
      'isNotice': notice,
      'likes': 0,
      'likedBy': <String>[],
      'comments': <Map<String, dynamic>>[],
      'timestamp': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> addComment({
    required String postId,
    required String author,
    required String text,
  }) {
    return _posts.doc(postId).update({
      'comments': FieldValue.arrayUnion([
        {'author': author, 'text': text, 'createdAt': Timestamp.now()},
      ]),
    });
  }

  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final ref = _posts.doc(postId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final liked = likedBy.contains(userId);
      final likes = (data['likes'] as num?)?.toInt() ?? likedBy.length;

      if (liked) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      transaction.update(ref, {
        'likedBy': likedBy,
        'likes': liked ? (likes - 1).clamp(0, 1 << 31) : likes + 1,
      });
    });
  }
}
