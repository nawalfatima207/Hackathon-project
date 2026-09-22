import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'library_screen.dart';

class ConversationStore extends ChangeNotifier {
static final ConversationStore instance =
ConversationStore._internal();

ConversationStore._internal();

CollectionReference get _collection =>
FirebaseFirestore.instance.collection('conversations');

List<LectureItem> _cache = [];

String? get _userId =>
FirebaseAuth.instance.currentUser?.uid;


// --------------------------------------------------
// SAVE OR UPDATE CONVERSATION
// --------------------------------------------------

Future<String?> save(
LectureItem item, {
String? documentId,
}) async {
final uid = _userId;

if (uid == null) {
print('SAVE FAILED: No logged-in Firebase user.');
return null;
}

final data = {
'userId': uid,
'title': item.title,
'summary': item.summary,
'summaryRequestCount': item.summaryRequestCount,
'messages': item.messages,
'duration': item.duration,
'savedAt': item.savedAt.toIso8601String(),
};

try {
// -----------------------------------------------
// FIRST SAVE
// -----------------------------------------------

if (documentId == null) {
final doc = await _collection.add(data);

print(
'CONVERSATION CREATED: ${doc.id}',
);

// Refresh the Library, but don't allow a
// refresh problem to make the save fail.
try {
await refresh();
} catch (e) {
print('Library refresh failed after save: $e');
}

return doc.id;
}


// -----------------------------------------------
// UPDATE EXISTING CONVERSATION
// -----------------------------------------------

await _collection.doc(documentId).set(
data,
SetOptions(merge: true),
);

print(
'CONVERSATION UPDATED: $documentId',
);

try {
await refresh();
} catch (e) {
print('Library refresh failed after update: $e');
}

return documentId;

} catch (e) {
print('FIRESTORE SAVE ERROR: $e');
return null;
}
}


// --------------------------------------------------
// DELETE CONVERSATION
// --------------------------------------------------

Future<void> delete(String documentId) async {
final uid = _userId;

if (uid == null) return;

try {
await _collection.doc(documentId).delete();

_cache.removeWhere(
(item) => item.documentId == documentId,
);

notifyListeners();

print(
'CONVERSATION DELETED: $documentId',
);

} catch (e) {
print(
'FIRESTORE DELETE ERROR: $e',
);
}
}


// --------------------------------------------------
// LOAD CONVERSATIONS
// --------------------------------------------------

Future<void> refresh() async {
final uid = _userId;

if (uid == null) {
_cache = [];
notifyListeners();
return;
}

try {
// IMPORTANT:
// No orderBy here.
//
// This avoids needing a Firestore composite index
// for userId + savedAt.

final snapshot = await _collection
    .where(
'userId',
isEqualTo: uid,
)
    .get();

_cache = snapshot.docs.map((doc) {
final data =
doc.data() as Map<String, dynamic>;

return LectureItem(
documentId: doc.id,

title: data['title'] ?? 'Untitled Lecture',

summary: data['summary'],

summaryRequestCount:
data['summaryRequestCount'] ?? 0,

messages:
List<Map<String, dynamic>>.from(
data['messages'] ?? [],
),

duration:
data['duration'] ?? '0:00',

savedAt:
DateTime.tryParse(
data['savedAt'] ?? '',
) ??
DateTime.now(),

tagColor:
const Color(0xFF7C6FE8),
);
}).toList();


// Sort newest conversations first.
_cache.sort(
(a, b) => b.savedAt.compareTo(a.savedAt),
);

notifyListeners();

print(
'LIBRARY LOADED: ${_cache.length} conversations',
);

} catch (e) {
print(
'FIRESTORE REFRESH ERROR: $e',
);
}
}


List<LectureItem> get all =>
List.unmodifiable(_cache);


List<LectureItem> get recent =>
_cache.take(2).toList();
}