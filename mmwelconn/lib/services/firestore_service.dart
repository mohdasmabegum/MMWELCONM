import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/models/contact_model.dart';
import 'package:mmwelconm/models/mood_model.dart';
import 'package:mmwelconm/models/chat_model.dart';
import 'package:mmwelconm/models/reminder_model.dart';
import 'package:mmwelconm/services/storage_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storage = StorageService();

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

  Future<void> setShowOnline(String uid, bool showOnline) =>
      _db.collection('users').doc(uid).update({
        'showOnline': showOnline,
        'status': showOnline ? 'online' : 'offline',
        'lastActive': FieldValue.serverTimestamp(),
      });

  Stream<UserModel?> watchUser(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .handleError((_) {})
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
    final senderDoc = await getUser(senderUid);
    final isKid = senderDoc?.ageGroup == 'kid';
    final hasParent = senderDoc?.parentId != null && senderDoc!.parentId.isNotEmpty;
    final statusVal = (isKid && hasParent) ? 'pending_parent' : ContactStatus.pending.name;

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
        'status': statusVal,
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
        'status': statusVal,
        'direction': ContactDirection.incoming.name,
        'relationshipType': relationship.name,
        'addedAt': now,
      },
    );

    await batch.commit();
  }

  Future<String> acceptContact(String ownerUid, String contactUid) async {
    final ownerDoc = await getUser(ownerUid);
    final contactDoc = await getUser(contactUid);
    final ownerName = ownerDoc?.name ?? '';
    final contactName = contactDoc?.name ?? '';
    final ownerPhoto = ownerDoc?.profileImageUrl ?? '';
    final contactPhoto = contactDoc?.profileImageUrl ?? '';

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
      'participantProfileImageUrls': {ownerUid: ownerPhoto, contactUid: contactPhoto},
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

  Future<void> approveChildOutgoingRequest(String childUid, String contactUid) async {
    final batch = _db.batch();
    batch.update(
      _db.collection('users').doc(childUid).collection('contacts').doc(contactUid),
      {'status': ContactStatus.pending.name},
    );
    batch.update(
      _db.collection('users').doc(contactUid).collection('contacts').doc(childUid),
      {'status': ContactStatus.pending.name},
    );
    await batch.commit();
  }

  Future<void> cancelContactRequest(String ownerUid, String contactUid) {
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
    return q.snapshots().handleError((_) {}).map((s) {
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

  Stream<ContactModel?> watchContact(String ownerUid, String contactUid) => _db
      .collection('users')
      .doc(ownerUid)
      .collection('contacts')
      .doc(contactUid)
      .snapshots()
      .handleError((_) {})
      .map((d) => d.exists ? ContactModel.fromDoc(d) : null);

  // ── Chats ─────────────────────────────────────────────────────────────────

  Future<String> getOrCreateDirectChat(
      String myUid, String otherUid) async {
    final ids = [myUid, otherUid]..sort();
    final chatId = ids.join('_');
    final ref = _db.collection('chats').doc(chatId);
    final doc = await ref.get();
    if (!doc.exists) {
      final myUser = await getUser(myUid);
      final otherUser = await getUser(otherUid);
      await ref.set(ChatModel(
        id: chatId,
        chatType: ChatType.direct,
        participantIds: [myUid, otherUid],
        participantNames: {myUid: myUser?.name ?? '', otherUid: otherUser?.name ?? ''},
        participantProfileImageUrls: {myUid: myUser?.profileImageUrl ?? '', otherUid: otherUser?.profileImageUrl ?? ''},
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

  /// sendMessage supports two call styles for backward compatibility:
  /// 1) sendMessage(chatId, MessageModel message, List<String> participantIds)
  /// 2) sendMessage(chatId, senderId, senderName, List<String> participantIds, {text, image})
  Future<void> sendMessage(String chatId, dynamic arg2, [dynamic arg3, dynamic arg4, dynamic arg5, dynamic arg6]) async {
    // Supports both:
    // - sendMessage(chatId, MessageModel msg, List<String> participantIds)
    // - sendMessage(chatId, senderId, senderName, List<String> participantIds, [text], [image])
    MessageModel msg;
    List<String> allParticipantIds = [];
    String senderId = '';

    if (arg2 is MessageModel) {
      msg = arg2;
      allParticipantIds = (arg3 as List<String>?) ?? [];
      senderId = msg.senderId;
    } else {
      senderId = arg2 as String;
      final senderName = arg3 as String;
      allParticipantIds = (arg4 as List<String>?) ?? [];
      final String? legacyText = arg5 as String?;
      final XFile? legacyImage = arg6 as XFile?;

      String? imageUrl;
      if (legacyImage != null) {
        imageUrl = await _storage.uploadChatImage(chatId, File(legacyImage.path));
      }

      msg = MessageModel(
        id: '',
        senderId: senderId,
        senderName: senderName,
        text: legacyText ?? '',
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );
    }

    final batch = _db.batch();
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc();
    final msgToStore = MessageModel(
      id: msgRef.id,
      senderId: msg.senderId,
      senderName: msg.senderName,
      text: msg.text,
      imageUrl: msg.imageUrl,
      createdAt: DateTime.now(),
    );

    batch.set(msgRef, msgToStore.toMap());
    final unreadIncrements = {
      for (final uid in allParticipantIds.where((id) => id != senderId))
        'unreadCount.$uid': FieldValue.increment(1)
    };
    final lastMessage = (msg.imageUrl != null && (msg.text.isEmpty)) ? '📷 Photo' : msg.text;
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
          .handleError((_) {})
          .map((s) => s.docs.map(MessageModel.fromDoc).toList());

  // ── Moods ─────────────────────────────────────────────────────────────────

  /// Uploads a mood photo to Firebase Storage and returns the URL.
  Future<String> uploadMoodPhoto(String uid, File file) async {
    final ref = _storage.ref('mood-photos/$uid/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<String> postMood(MoodModel mood) async {
    final ref = await _db.collection('moods').add(mood.toMap());
    return ref.id;
  }

  Stream<MoodModel?> watchMoodById(String moodId) => _db
      .collection('moods')
      .doc(moodId)
      .snapshots()
      .handleError((_) {})
      .map((d) => d.exists ? MoodModel.fromDoc(d) : null);

  Future<void> deleteMood(String moodId) =>
      _db.collection('moods').doc(moodId).delete();

  Future<void> clearCurrentMood(String uid) =>
      _db.collection('users').doc(uid).update({'currentMoodId': null});

  Future<void> setCurrentMood(String uid, String moodLabel) =>
      _db.collection('users').doc(uid).update({
        'currentMoodId': moodLabel,
        'currentMoodSetAt': FieldValue.serverTimestamp(),
      });

  Stream<List<MoodModel>> watchPublicMoods({int limit = 20}) => _db
      .collection('moods')
      .where('isPublic', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .handleError((_) {})
      .map((s) => s.docs.map(MoodModel.fromDoc).toList());

  Stream<List<MoodModel>> watchUserMoods(String userId, {int limit = 20}) =>
      _db
          .collection('moods')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .handleError((_) {})
          .map((s) => s.docs.map(MoodModel.fromDoc).toList());

  /// Streams only mood posts that have a photo attached, for the mood widget section.
  Stream<List<MoodModel>> watchUserMoodPhotos(String userId, {int limit = 12}) =>
      _db
          .collection('moods')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .handleError((_) {})
          .map((s) => s.docs
              .map(MoodModel.fromDoc)
              .where((m) => m.moodPhotoUrl != null && m.moodPhotoUrl!.isNotEmpty)
              .toList());

  // ── App Version ───────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>> watchAppVersion() => _db
      .collection('app_config')
      .doc('version')
      .snapshots()
      .handleError((_) {})
      .map((d) => d.exists ? (d.data() as Map<String, dynamic>) : {});

  Future<void> updateAutoUpdate(String uid, bool enabled) =>
      _db.collection('users').doc(uid).update({'autoUpdate': enabled});

  Future<void> markMessagesAsDelivered(String chatId, String currentUid) async {
    final snap = await _db.collection('chats').doc(chatId).collection('messages')
        .where('senderId', isNotEqualTo: currentUid)
        .where('status', isEqualTo: 'sent')
        .get();
    if (snap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'status': 'delivered'});
      }
      await batch.commit();
    }
  }

  Future<void> markMessagesAsSeen(String chatId, String currentUid) async {
    final snap = await _db.collection('chats').doc(chatId).collection('messages')
        .where('senderId', isNotEqualTo: currentUid)
        .where('status', isNotEqualTo: 'seen')
        .get();
    if (snap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'status': 'seen'});
      }
      await batch.commit();
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    await msgRef.delete();
    
    // Get the new latest message to update parent chat metadata
    final latestMsgs = await _db.collection('chats').doc(chatId).collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
        
    if (latestMsgs.docs.isNotEmpty) {
      final latest = latestMsgs.docs.first.data();
      final String text = latest['text'] ?? '';
      final String? imageUrl = latest['imageUrl'];
      final String lastMessage = (imageUrl != null && imageUrl.isNotEmpty && text.isEmpty) ? '📷 Photo' : text;
      
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': lastMessage,
        'lastSenderId': latest['senderId'],
        'lastMessageAt': latest['createdAt'],
      });
    } else {
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': null,
        'lastSenderId': null,
        'lastMessageAt': null,
      });
    }
  }

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    await msgRef.update({
      'text': newText,
      'isEdited': true,
    });
    
    // Also update parent chat metadata if it was the last message
    final latestMsgs = await _db.collection('chats').doc(chatId).collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
        
    if (latestMsgs.docs.isNotEmpty && latestMsgs.docs.first.id == messageId) {
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': newText,
      });
    }
  }

  Future<void> deleteChat(String chatId) async {
    // Delete all messages subcollection documents
    final msgs = await _db.collection('chats').doc(chatId).collection('messages').get();
    final batch = _db.batch();
    for (var doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    // Delete the chat document
    batch.delete(_db.collection('chats').doc(chatId));
    await batch.commit();
  }

  // ── Reminders ─────────────────────────────────────────────────────────────

  Future<void> createReminder(ReminderModel reminder) {
    final docRef = reminder.id.isEmpty 
        ? _db.collection('reminders').doc() 
        : _db.collection('reminders').doc(reminder.id);
    final toSave = ReminderModel(
      id: docRef.id,
      userId: reminder.userId,
      title: reminder.title,
      description: reminder.description,
      remindAt: reminder.remindAt,
      createdAt: reminder.createdAt,
      isCompleted: reminder.isCompleted,
    );
    return docRef.set(toSave.toMap());
  }

  Future<void> updateReminder(String id, Map<String, dynamic> data) =>
      _db.collection('reminders').doc(id).update(data);

  Future<void> deleteReminder(String id) =>
      _db.collection('reminders').doc(id).delete();

  Stream<List<ReminderModel>> watchMyReminders(String uid) => _db
      .collection('reminders')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .handleError((_) {})
      .map((s) {
        final list = s.docs.map(ReminderModel.fromDoc).toList();
        list.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return a.remindAt.compareTo(b.remindAt);
        });
        return list;
      });

  Stream<List<ReminderModel>> watchUpcomingReminders(String uid) => _db
      .collection('reminders')
      .where('userId', isEqualTo: uid)
      .where('isCompleted', isEqualTo: false)
      .snapshots()
      .handleError((_) {})
      .map((s) {
        final list = s.docs.map(ReminderModel.fromDoc).toList();
        list.sort((a, b) => a.remindAt.compareTo(b.remindAt));
        return list;
      });

  Stream<ChatModel?> watchChat(String chatId) => _db
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .handleError((_) {})
      .map((doc) => doc.exists ? ChatModel.fromDoc(doc) : null);

  Future<void> updateOnlineDisclosure(String chatId, String uid, bool disclose) =>
      _db.collection('chats').doc(chatId).update({
        'discloseOnlineStatus.$uid': disclose,
      });

  Future<void> toggleChatLock(String chatId, String uid, bool isLocked) =>
      _db.collection('chats').doc(chatId).update({
        'lockedBy.$uid': isLocked,
      });

  Future<void> setTypingStatus(String chatId, String uid, bool isTyping) =>
      _db.collection('chats').doc(chatId).update({
        'typingStatus.$uid': isTyping,
      });

  Future<String> createGroupChat({
    required String creatorUid,
    required String groupName,
    required List<String> participantIds,
    String groupDescription = '',
    String groupCategory = 'Friends',
  }) async {
    final docRef = _db.collection('chats').doc();
    final myUser = await getUser(creatorUid);

    final Map<String, String> names = {
      creatorUid: myUser?.name ?? '',
    };
    final Map<String, String> photos = {
      creatorUid: myUser?.profilePicture ?? '',
    };

    for (final uid in participantIds) {
      final u = await getUser(uid);
      names[uid] = u?.name ?? '';
      photos[uid] = u?.profilePicture ?? '';
    }

    final allIds = [creatorUid, ...participantIds];

    await docRef.set({
      'chatType': ChatType.group.name,
      'participantIds': allIds,
      'participantNames': names,
      'participantProfileImageUrls': photos,
      'groupName': groupName,
      'groupDescription': groupDescription,
      'groupCreatedAt': FieldValue.serverTimestamp(),
      'groupCategory': groupCategory,
      'groupCreatedBy': creatorUid,
      'lastMessage': 'Group created by ${myUser?.name ?? 'someone'}',
      'lastSenderId': creatorUid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': {for (final uid in allIds) uid: 0},
      'discloseOnlineStatus': {for (final uid in allIds) uid: true},
      'lockedBy': {for (final uid in allIds) uid: false},
      'typingStatus': {for (final uid in allIds) uid: false},
    });
    return docRef.id;
  }

  Future<void> updateGroupDetails(
    String chatId, {
    String? name,
    String? description,
    String? category,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['groupName'] = name;
    if (description != null) updates['groupDescription'] = description;
    if (category != null) updates['groupCategory'] = category;
    if (updates.isNotEmpty) {
      await _db.collection('chats').doc(chatId).update(updates);
    }
  }

  Future<void> toggleChatHide(String chatId, String uid, bool hide) =>
      _db.collection('chats').doc(chatId).update({'hiddenBy.$uid': hide});

  // --- TODO SECTION ---
  Stream<List<Map<String, dynamic>>> watchTodos(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('todos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> addTodo(String uid, String title, String priority) async {
    await _db.collection('users').doc(uid).collection('todos').add({
      'title': title,
      'priority': priority,
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleTodo(String uid, String todoId, bool isCompleted) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('todos')
        .doc(todoId)
        .update({'isCompleted': isCompleted});
  }

  Future<void> deleteTodo(String uid, String todoId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('todos')
        .doc(todoId)
        .delete();
  }
}
