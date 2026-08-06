import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'library_screen.dart';

class ConversationStore extends ChangeNotifier {
  static final ConversationStore instance = ConversationStore._internal();
  ConversationStore._internal();

  CollectionReference get _collection => FirebaseFirestore.instance.collection('conversations');
  List<LectureItem> _cache = [];

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> save(LectureItem item) async {
    final uid = _userId;
    if (uid == null) return;

    await _collection.add({
      'userId': uid,
      'title': item.title,
      'summary': item.summary,
      'summaryRequestCount': item.summaryRequestCount,
      'messages': item.messages,
      'duration': item.duration,
      'savedAt': item.savedAt.toIso8601String(),
    });
    await refresh();
  }

  Future<void> refresh() async {
    final uid = _userId;
    if (uid == null) {
      _cache = [];
      notifyListeners();
      return;
    }

    final snapshot = await _collection
        .where('userId', isEqualTo: uid)
        .orderBy('savedAt', descending: true)
        .get();

    _cache = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return LectureItem(
        title: data['title'],
        summary: data['summary'],
        summaryRequestCount: data['summaryRequestCount'] ?? 0,
        messages: List<Map<String, dynamic>>.from(data['messages']),
        duration: data['duration'],
        savedAt: DateTime.parse(data['savedAt']),
        tagColor: const Color(0xFF7C6FE8),
      );
    }).toList();
    notifyListeners();
  }

  List<LectureItem> get all => List.unmodifiable(_cache);
  List<LectureItem> get recent => _cache.take(2).toList();
}