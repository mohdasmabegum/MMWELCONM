import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/mood_model.dart';
import 'package:mmwelconn/models/chat_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Users ────────────────────────────────────────────────────────────────

  Future<void> createUser(UserModel user) =>
      _db.collection('users').doc(user.uid).set(user.toMap());

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromDoc(doc) : null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).update(data);

  Future<void> setUserStatus(String uid, String status) =>
      _db.collection('users').doc(uid).update({
        'status': status,
        'lastActive': FieldValue.serverTimestamp(),
      });

  Stream<UserModel?> watchUser(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? UserModel.fromDoc(d) : null);

  Future<List<UserModel>> searchUsers(String query) async {
    final nameSnap = await _db
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();
    final mmIdSnap = await _db
        .collection('users')
        .where('mmId', isEqualTo: query.toUpperCase())
        .limit(5)
        .get();
    final seen = <String>{};
    final combined = [...nameSnap.docs, ...mmIdSnap.docs]
        .where((d) => seen.add(d.id))
        .toList();
    return combined.map(UserModel.fromDoc).toList();
  }

  // ── Contacts ─────────────────────────────────────────────────────────────

  Future<void> sendContactRequest({
    required String senderUid,
    required String senderName,
    required String senderMmId,
    required String senderPhotoUrl,
    required String recipientUid,
    required String recipientName,
    required String recipientMmId,
    required String recipientPhotoUrl,
    required RelationshipType relationship,
  }) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    batch.set(
      _db.collection('users').doc(senderUid).collection('contacts').doc(recipientUid),
      {
        'ownerUid': senderUid,
        'contactUid': recipientUid,
        'contactMmId': recipientMmId,
        'contactName': recipientName,
        'contactPhotoUrl': recipientPhotoUrl,
        'status': ContactStatus.pending.name,
        'direction': ContactDirection.outgoing.name,
        'relationshipType': relationship.name,
        'addedAt': now,
      },
    );

    batch.set(
      _db.collection('users').doc(recipientUid).collection('contacts').doc(senderUid),
      {
        'ownerUid': recipientUid,
        'contactUid': senderUid,
        'contactMmId': senderMmId,
        'contactName': senderName,
        'contactPhotoUrl': senderPhotoUrl,
        'status': ContactStatus.pending.name,
        'direction': ContactDirection.incoming.name,
        'relationshipType': relationship.name,
        'addedAt': now,
      },
    );

    await batch.commit();
  }

  Future<String> acceptContact(String ownerUid, String contactUid) async {
    final ownerDoc = await _db.collection('users').doc(ownerUid).get();
    final contactDoc = await _db.collection('users').doc(contactUid).get();
    final ownerName = (ownerDoc.data() ?? {})['name'] ?? '';
    final contactName = (contactDoc.data() ?? {})['name'] ?? '';

    final ids = [ownerUid, contactUid]..sort();
    final chatId = ids.join('_');
    final chatRef = _db.collection('chats').doc(chatId);

    final ownerContactRef = _db
        .collection('users').doc(ownerUid).collection('contacts').doc(contactUid);
    final contactOwnerRef = _db
        .collection('users').doc(contactUid).collection('contacts').doc(ownerUid);

    await ownerContactRef.update({'status': ContactStatus.accepted.name});
    await contactOwnerRef.update({'status': ContactStatus.accepted.name});

    // Create empty chat doc — no auto message
    await chatRef.set({
      'chatType': ChatType.direct.name,
      'participantIds': [ownerUid, contactUid],
      'participantNames': {ownerUid: ownerName, contactUid: contactName},
      'unreadCount': {ownerUid: 0, contactUid: 0},
    }, SetOptions(merge: true));

    return chatId;
  }

  Future<void> declineContact(String ownerUid, String contactUid) {
    final batch = _db.batch();
    batch.delete(
      _db.collection('users').doc(ownerUid).collection('contacts').doc(contactUid),
    );
    batch.delete(
      _db.collection('users').doc(contactUid).collection('contacts').doc(ownerUid),
    );
    return batch.commit();
  }

  Future<void> updateContactStatus(
          String ownerUid, String contactUid, ContactStatus status) =>
      _db
          .collection('users')
          .doc(ownerUid)
          .collection('contacts')
          .doc(contactUid)
          .update({'status': status.name});

  Future<void> updateContactRelationship(
          String ownerUid, String contactUid, RelationshipType type) =>
      _db
          .collection('users')
          .doc(ownerUid)
          .collection('contacts')
          .doc(contactUid)
          .update({'relationshipType': type.name});

  Future<void> removeContact(String ownerUid, String contactUid) => _db
      .collection('users')
      .doc(ownerUid)
      .collection('contacts')
      .doc(contactUid)
      .delete();

  Stream<List<ContactModel>> watchContacts(String uid,
      {ContactStatus? status, ContactDirection? direction}) {
    Query q = _db.collection('users').doc(uid).collection('contacts');
    if (status != null) q = q.where('status', isEqualTo: status.name);
    if (direction != null) q = q.where('direction', isEqualTo: direction.name);
    return q.snapshots().map((s) {
      final list = s.docs.map(ContactModel.fromDoc).toList();
      list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return list;
    });
  }

  Future<ContactModel?> getContact(String ownerUid, String contactUid) async {
    final doc = await _db
        .collection('users')
        .doc(ownerUid)
        .collection('contacts')
        .doc(contactUid)
        .get();
    return doc.exists ? ContactModel.fromDoc(doc) : null;
  }

  // ── Chats ─────────────────────────────────────────────────────────────────

  Future<String> getOrCreateDirectChat(
      String myUid, String myName, String otherUid, String otherName) async {
    final ids = [myUid, otherUid]..sort();
    final chatId = ids.join('_');
    final ref = _db.collection('chats').doc(chatId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set(ChatModel(
        id: chatId,
        chatType: ChatType.direct,
        participantIds: [myUid, otherUid],
        participantNames: {myUid: myName, otherUid: otherName},
        unreadCount: {myUid: 0, otherUid: 0},
      ).toMap());
    }
    return chatId;
  }

  Future<ChatModel?> getChat(String chatId) async {
    final doc = await _db.collection('chats').doc(chatId).get();
    return doc.exists ? ChatModel.fromDoc(doc) : null;
  }

  Stream<List<ChatModel>> watchMyChats(String uid) => _db
      .collection('chats')
      .where('participantIds', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .handleError((_) {})
      .map((s) {
        final chats = s.docs.map(ChatModel.fromDoc).toList();
        chats.sort((a, b) {
          if (a.lastMessageAt == null) return 1;
          if (b.lastMessageAt == null) return -1;
          return b.lastMessageAt!.compareTo(a.lastMessageAt!);
        });
        return chats;
      });

  Future<void> sendMessage(String chatId, MessageModel msg,
      List<String> allParticipantIds) async {
    final batch = _db.batch();
    final msgRef =
        _db.collection('chats').doc(chatId).collection('messages').doc();
    batch.set(msgRef, msg.toMap());
    final unreadIncrements = {
      for (final uid in allParticipantIds.where((id) => id != msg.senderId))
        'unreadCount.$uid': FieldValue.increment(1)
    };
    final lastMessage = msg.imageUrl != null && msg.text.isEmpty
        ? '📷 Photo'
        : msg.text;
    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': lastMessage,
      'lastSenderId': msg.senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      ...unreadIncrements,
    });
    await batch.commit();
  }

  Future<void> clearUnread(String chatId, String uid) =>
      _db.collection('chats').doc(chatId).update({'unreadCount.$uid': 0});

  Stream<List<MessageModel>> watchMessages(String chatId, {int limit = 30}) =>
      _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(MessageModel.fromDoc).toList());

  // ── Moods ─────────────────────────────────────────────────────────────────

  Future<String> postMood(MoodModel mood) async {
    final ref = await _db.collection('moods').add(mood.toMap());
    return ref.id;
  }

  Stream<MoodModel?> watchMoodById(String moodId) => _db
      .collection('moods')
      .doc(moodId)
      .snapshots()
      .map((d) => d.exists ? MoodModel.fromDoc(d) : null);

  Future<void> deleteMood(String moodId) =>
      _db.collection('moods').doc(moodId).delete();

  Future<void> clearCurrentMood(String uid) =>
      _db.collection('users').doc(uid).update({'currentMoodId': null});

  Stream<List<MoodModel>> watchPublicMoods({int limit = 20}) => _db
      .collection('moods')
      .where('isPublic', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(MoodModel.fromDoc).toList());

  Stream<List<MoodModel>> watchUserMoods(String userId, {int limit = 20}) =>
      _db
          .collection('moods')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(MoodModel.fromDoc).toList());

  // ── App Version ───────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> watchAppVersion() => _db
      .collection('app_config')
      .doc('version')
      .snapshots()
      .map((d) => d.exists ? (d.data() as Map<String, dynamic>) : {});

  Future<void> updateAutoUpdate(String uid, bool enabled) =>
      _db.collection('users').doc(uid).update({'autoUpdate': enabled});
}
