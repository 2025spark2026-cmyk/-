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
    // 복합 인덱스 없이 동작하도록 서버 정렬은 피하고 화면에서 정렬한다.
    return _posts.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllPosts() {
    return _posts.snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPost(String id) {
    return _posts.doc(id).snapshots();
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> latestNotice() async {
    final result = await _posts
        .where('isNotice', isEqualTo: true)
        .limit(20)
        .get();
    final docs = result.docs..sort(comparePosts);
    return docs.isEmpty ? null : docs.first;
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
    return _posts.doc(postId).update({
      'likedBy': currentlyLiked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
      'likes': FieldValue.increment(currentlyLiked ? -1 : 1),
    });
  }

  static int comparePosts(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aData = a.data();
    final bData = b.data();
    final aNotice = aData['isNotice'] == true;
    final bNotice = bData['isNotice'] == true;
    if (aNotice != bNotice) return aNotice ? -1 : 1;
    return compareByTime(aData, bData);
  }

  static int compareByTime(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aTime = a['timestamp'];
    final bTime = b['timestamp'];
    final aMillis = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
    final bMillis = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
    return bMillis.compareTo(aMillis);
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
