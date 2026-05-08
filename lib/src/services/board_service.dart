import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BoardService {
  BoardService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  static const popularLikeThreshold = 10;

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

  // 인기게시물은 공지와 섞지 않기 위해 화면에서 별도 탭으로 분리한다.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllPosts() {
    return _posts.snapshots();
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
    String? imageExtension,
    String? imageContentType,
  }) async {
    var imageUrl = '';
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final extension = _safeExtension(imageExtension);
      final path = 'posts/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = _storage.ref(path);

      // 웹과 모바일 모두 readAsBytes 결과를 Storage에 업로드한다.
      await ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: imageContentType ?? _contentTypeFor(extension),
        ),
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
    required bool currentlyLiked,
  }) {
    // 현재 화면 상태를 기준으로 원자적 업데이트를 적용해 숫자가 즉시 바뀌게 한다.
    return _posts.doc(postId).update({
      'likedBy': currentlyLiked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
      'likes': FieldValue.increment(currentlyLiked ? -1 : 1),
    });
  }

  String _safeExtension(String? value) {
    final extension = (value ?? 'jpg').toLowerCase().replaceAll('.', '');
    if (extension == 'png' || extension == 'webp' || extension == 'gif') {
      return extension;
    }
    return 'jpg';
  }

  String _contentTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}
