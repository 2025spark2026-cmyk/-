import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  AuthService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  String _hash(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<void> signIn({required String id, required String password}) async {
    final doc = await _users.doc(id).get();
    if (!doc.exists) {
      throw AuthException('가입되지 않은 아이디입니다.');
    }

    final data = doc.data() ?? {};
    final passwordHash = data['passwordHash'] as String?;
    final legacyPassword = data['pw'] as String?;
    final isValidPassword =
        passwordHash == _hash(password) || legacyPassword == password;

    if (!isValidPassword) {
      throw AuthException('아이디 또는 비밀번호를 확인해 주세요.');
    }

    if (passwordHash == null) {
      await _users.doc(id).set({
        'passwordHash': _hash(password),
        'pw': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> signUp({required String id, required String password}) async {
    final doc = await _users.doc(id).get();
    if (doc.exists) {
      throw AuthException('이미 사용 중인 아이디입니다.');
    }

    await _users.doc(id).set({
      'passwordHash': _hash(password),
      'role': id == 'admin' ? 'admin' : 'student',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
