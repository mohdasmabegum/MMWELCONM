import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/mood_model.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/connection_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Users /users/{uid} ───────────────────────────────────────────────────

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
        'lastActive': Timestamp.fromDate(DateTime.now()),
      });

  Stream<UserModel?> watchUser(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? UserModel.fromDoc(d) : null);

  Future<List<UserModel>> searchUsers(String query) async {
    final snap = await _db
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();
    return snap.docs.map(UserModel.fromDoc).toList();
  }

  // ── Contacts /users/{uid}/contacts/{contactId} ───────────────────────────

  Future<void> addContact(ContactModel contact) => _db
      .collection('users')
      .doc(contact.ownerUid)
      .collection('contacts')
      .doc(contact.contactUid)
      .set(contact.toMap());

  Future<void> updateContactStatus(
          String ownerUid, String contactUid, ContactStatus status) =>
      _db
          .collection('users')
          .doc(ownerUid)
          .collection('contacts')
          .doc(contactUid)
          .update({'status': status.name});

  Future<void> removeContact(String ownerUid, String contactUid) => _db
      .collection('users')
      .doc(ownerUid)
      .collection('contacts')
      .doc(contactUid)
      .delete();

  Stream<List<ContactModel>> watchContacts(String uid,
          {ContactStatus? status}) {
    Query q = _db.collection('users').doc(uid).collection('contacts');
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return q
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ContactModel.fromDoc).toList());
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

  // ── Chats /chats/{chatId} ────────────────────────────────────────────────

  Future<String> getOrCreateDirectChat(
      String myUid, String myName, String otherUid, String otherName) async {
    final existing = await _db
        .collection('chats')
        .where('chatType', isEqualTo: 'direct')
        .where('participantIds', arrayContains: myUid)
        .get();

    for (final doc in existing.docs) {
      final ids = List<String>.from(doc['participantIds']);
      if (ids.contains(otherUid)) return doc.id;
    }

    final ref = _db.collection('chats').doc();
    await ref.set(ChatModel(
      id: ref.id,
      chatType: ChatType.direct,
      participantIds: [myUid, otherUid],
      participantNames: {myUid: myName, otherUid: otherName},
      unreadCount: {myUid: 0, otherUid: 0},
    ).toMap());
    return ref.id;
  }

  Future<String> createGroupChat(
      String groupName, Map<String, String> participants) async {
    final ref = _db.collection('chats').doc();
    final unread = {for (final uid in participants.keys) uid: 0};
    await ref.set(ChatModel(
      id: ref.id,
      chatType: ChatType.group,
      participantIds: participants.keys.toList(),
      participantNames: participants,
      groupName: groupName,
      unreadCount: unread,
    ).toMap());
    return ref.id;
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
      .map((s) => s.docs.map(ChatModel.fromDoc).toList());

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

    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': msg.text,
      'lastSenderId': msg.senderId,
      'lastMessageAt': Timestamp.fromDate(msg.createdAt),
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

  // ── Moods /moods/{moodId} ────────────────────────────────────────────────

  Future<void> postMood(MoodModel mood) =>
      _db.collection('moods').add(mood.toMap());

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

  // ── Connections /connections/{connectionId} ──────────────────────────────

  Future<void> sendConnectionRequest(ConnectionModel connection) =>
      _db.collection('connections').add(connection.toMap());

  Future<void> updateConnectionStatus(
          String connectionId, ConnectionStatus status) =>
      _db
          .collection('connections')
          .doc(connectionId)
          .update({'status': status.name});

  Stream<List<ConnectionModel>> watchPendingRequests(String uid) => _db
      .collection('connections')
      .where('toUserId', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(ConnectionModel.fromDoc).toList());

  Stream<List<ConnectionModel>> watchMyConnections(String uid) => _db
      .collection('connections')
      .where('fromUserId', isEqualTo: uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots()
      .map((s) => s.docs.map(ConnectionModel.fromDoc).toList());
}
