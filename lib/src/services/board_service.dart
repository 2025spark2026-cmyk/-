import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class BoardService {
  BoardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const popularLikeThreshold = 10;
  static const maxInlineImageBytes = 450 * 1024;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPosts() {
    return _posts.orderBy('timestamp', descending: true).limit(200).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllPosts() {
    return _posts.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPopularPosts() {
    return _posts.orderBy('likes', descending: true).limit(100).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserPosts(String userId) {
    return _posts.where('authorId', isEqualTo: userId).limit(50).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReports() {
    return _reports.limit(100).snapshots();
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
    final visibleDocs = docs.where((doc) => !isDeleted(doc.data())).toList();
    return visibleDocs.isEmpty ? null : visibleDocs.first;
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
    var imageData = '';
    final contentType = imageContentType ?? _contentTypeFor(
      _safeExtension(imageExtension),
    );
    if (imageBytes != null && imageBytes.isNotEmpty) {
      if (imageBytes.length > maxInlineImageBytes) {
        throw const ImageTooLargeException();
      }
      imageData = base64Encode(imageBytes);
    }

    final doc = await _posts.add({
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'imageData': imageData,
      'imageContentType': imageData.isEmpty ? '' : contentType,
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

  Future<void> deletePost(String postId) {
    return _posts.doc(postId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'title': '삭제된 게시글',
      'content': '',
      'imageUrl': '',
      'imageData': '',
      'imageContentType': '',
      'comments': <Map<String, dynamic>>[],
      'likedBy': <String>[],
      'likes': 0,
    });
  }

  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reporterId,
    required String reason,
    required String detail,
    String? targetOwnerId,
    String? targetTitle,
  }) {
    return _reports.add({
      'targetType': targetType,
      'targetId': targetId,
      'targetOwnerId': targetOwnerId ?? '',
      'targetTitle': targetTitle ?? '',
      'reporterId': reporterId,
      'reason': reason,
      'detail': detail,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
  }) {
    return _reports.doc(reportId).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
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

  static bool isDeleted(Map<String, dynamic> data) {
    return data['isDeleted'] == true;
  }

  static int compareByTime(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aTime = a['timestamp'];
    final bTime = b['timestamp'];
    final aMillis = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
    final bMillis = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
    return bMillis.compareTo(aMillis);
  }

  static int compareReports(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aData = a.data();
    final bData = b.data();
    final aPending = (aData['status'] ?? 'pending') != 'resolved';
    final bPending = (bData['status'] ?? 'pending') != 'resolved';
    if (aPending != bPending) return aPending ? -1 : 1;

    final aTime = aData['createdAt'];
    final bTime = bData['createdAt'];
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

class ImageTooLargeException implements Exception {
  const ImageTooLargeException();

  @override
  String toString() => '사진 용량이 너무 큽니다. 더 작은 사진을 선택해 주세요.';
}
