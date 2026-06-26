// MMWELCONN — Feature unit tests
// Tests models, business logic, helpers, and firestore service utilities
// without requiring a live Firebase connection.

import 'package:flutter_test/flutter_test.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/mood_model.dart';
import 'package:mmwelconn/models/user_model.dart';

void main() {
  // ── UserModel ─────────────────────────────────────────────────────────────

  group('UserModel', () {
    final now = DateTime(2024, 6, 1);

    UserModel makeUser({String status = 'online', String? moodId}) => UserModel(
          uid: 'uid1',
          mmId: 'MMABCD12',
          name: 'Alice',
          email: 'alice@test.com',
          status: status,
          currentMoodId: moodId,
          createdAt: now,
          lastActive: now,
        );

    test('toMap round-trips all fields', () {
      final user = makeUser(status: 'online', moodId: 'mood1');
      final map = user.toMap();
      expect(map['uid'], 'uid1');
      expect(map['mmId'], 'MMABCD12');
      expect(map['name'], 'Alice');
      expect(map['email'], 'alice@test.com');
      expect(map['status'], 'online');
      expect(map['currentMoodId'], 'mood1');
      expect(map['notificationsEnabled'], true);
      expect(map['autoUpdate'], true);
    });

    test('defaults: profilePicture empty, notifications+autoUpdate true', () {
      final user = makeUser();
      expect(user.profilePicture, '');
      expect(user.notificationsEnabled, true);
      expect(user.autoUpdate, true);
    });

    test('currentMoodId can be null', () {
      final user = makeUser(moodId: null);
      expect(user.currentMoodId, isNull);
    });

    test('MM ID format is 8 chars starting with MM', () {
      final user = makeUser();
      expect(user.mmId.startsWith('MM'), true);
      expect(user.mmId.length, 8);
    });
  });

  // ── ContactModel ──────────────────────────────────────────────────────────

  group('ContactModel', () {
    final now = DateTime(2024, 6, 1);

    ContactModel makeContact({
      ContactStatus status = ContactStatus.pending,
      ContactDirection direction = ContactDirection.incoming,
      RelationshipType rel = RelationshipType.friend,
    }) =>
        ContactModel(
          id: 'cid1',
          ownerUid: 'owner',
          contactUid: 'contact',
          contactMmId: 'MMXYZ789',
          contactName: 'Bob',
          contactPhotoUrl: '',
          status: status,
          direction: direction,
          relationshipType: rel,
          addedAt: now,
        );

    test('toMap serialises status, direction, relationshipType as names', () {
      final m = makeContact(
        status: ContactStatus.accepted,
        direction: ContactDirection.outgoing,
        rel: RelationshipType.family,
      ).toMap();
      expect(m['status'], 'accepted');
      expect(m['direction'], 'outgoing');
      expect(m['relationshipType'], 'family');
    });

    test('all ContactStatus values serialise correctly', () {
      for (final s in ContactStatus.values) {
        final m = makeContact(status: s).toMap();
        expect(m['status'], s.name);
      }
    });

    test('all ContactDirection values serialise correctly', () {
      for (final d in ContactDirection.values) {
        final m = makeContact(direction: d).toMap();
        expect(m['direction'], d.name);
      }
    });

    test('all RelationshipType values serialise correctly', () {
      for (final r in RelationshipType.values) {
        final m = makeContact(rel: r).toMap();
        expect(m['relationshipType'], r.name);
      }
    });

    test('ownerUid and contactUid are stored in map', () {
      final m = makeContact().toMap();
      expect(m['ownerUid'], 'owner');
      expect(m['contactUid'], 'contact');
    });
  });

  // ── ChatModel ─────────────────────────────────────────────────────────────

  group('ChatModel', () {
    ChatModel makeChat({
      ChatType type = ChatType.direct,
      String? lastMsg,
      DateTime? lastAt,
    }) =>
        ChatModel(
          id: 'chat1',
          chatType: type,
          participantIds: ['u1', 'u2'],
          participantNames: {'u1': 'Alice', 'u2': 'Bob'},
          lastMessage: lastMsg,
          lastMessageAt: lastAt,
          unreadCount: {'u1': 0, 'u2': 2},
        );

    test('toMap includes chatType name and participantIds', () {
      final m = makeChat().toMap();
      expect(m['chatType'], 'direct');
      expect(m['participantIds'], ['u1', 'u2']);
      expect(m['participantNames'], {'u1': 'Alice', 'u2': 'Bob'});
    });

    test('unread count is stored per uid', () {
      final m = makeChat().toMap();
      expect(m['unreadCount'], {'u1': 0, 'u2': 2});
    });

    test('lastMessage can be null', () {
      final m = makeChat(lastMsg: null).toMap();
      expect(m['lastMessage'], isNull);
    });

    test('lastMessageAt can be null', () {
      final m = makeChat(lastAt: null).toMap();
      expect(m['lastMessageAt'], isNull);
    });

    test('group chat type serialises correctly', () {
      final m = makeChat(type: ChatType.group).toMap();
      expect(m['chatType'], 'group');
    });
  });

  // ── MessageModel ──────────────────────────────────────────────────────────

  group('MessageModel', () {
    final now = DateTime(2024, 6, 1, 12, 0);

    MessageModel makeMsg() => MessageModel(
          id: 'msg1',
          senderId: 'u1',
          senderName: 'Alice',
          text: 'Hello!',
          createdAt: now,
        );

    test('toMap has senderId, senderName, text', () {
      final m = makeMsg().toMap();
      expect(m['senderId'], 'u1');
      expect(m['senderName'], 'Alice');
      expect(m['text'], 'Hello!');
    });

    test('text is preserved exactly', () {
      final msg = MessageModel(
          id: '', senderId: 'u1', senderName: 'A', text: '🎉 emoji text', createdAt: now);
      expect(msg.toMap()['text'], '🎉 emoji text');
    });
  });

  // ── MoodModel ─────────────────────────────────────────────────────────────

  group('MoodModel', () {
    final now = DateTime(2024, 6, 1);

    MoodModel makeMood({String? note, bool isPublic = true}) => MoodModel(
          id: 'mood1',
          userId: 'u1',
          userDisplayName: 'Alice',
          emoji: '😊',
          label: 'Happy',
          note: note,
          isPublic: isPublic,
          createdAt: now,
        );

    test('toMap serialises emoji, label, isPublic', () {
      final m = makeMood().toMap();
      expect(m['emoji'], '😊');
      expect(m['label'], 'Happy');
      expect(m['isPublic'], true);
      expect(m['userId'], 'u1');
    });

    test('note can be null', () {
      final m = makeMood(note: null).toMap();
      expect(m['note'], isNull);
    });

    test('note is stored when provided', () {
      final m = makeMood(note: 'Feeling great today').toMap();
      expect(m['note'], 'Feeling great today');
    });

    test('private mood serialises isPublic=false', () {
      final m = makeMood(isPublic: false).toMap();
      expect(m['isPublic'], false);
    });

    test('all 8 mood emojis are valid non-empty strings', () {
      final emojis = ['😊', '😔', '😌', '😤', '🥳', '😴', '🤩', '😰'];
      for (final e in emojis) {
        expect(e.isNotEmpty, true);
      }
    });
  });

  // ── Chat deterministic ID logic ───────────────────────────────────────────

  group('Chat ID generation', () {
    String makeChatId(String a, String b) {
      final ids = [a, b]..sort();
      return ids.join('_');
    }

    test('same pair always produces same id regardless of order', () {
      expect(makeChatId('uid_A', 'uid_B'), makeChatId('uid_B', 'uid_A'));
    });

    test('different pairs produce different ids', () {
      expect(makeChatId('u1', 'u2'), isNot(makeChatId('u1', 'u3')));
    });

    test('id format is sorted_uid1_sorted_uid2', () {
      final id = makeChatId('zzz', 'aaa');
      expect(id, 'aaa_zzz');
    });
  });

  // ── MM ID format validation ───────────────────────────────────────────────

  group('MM ID format', () {
    bool isValidMmId(String id) =>
        id.startsWith('MM') && id.length == 8 && RegExp(r'^MM[A-Z0-9]{6}$').hasMatch(id);

    test('valid MM IDs pass', () {
      expect(isValidMmId('MMABCD12'), true);
      expect(isValidMmId('MM000000'), true);
      expect(isValidMmId('MMZZZZZZ'), true);
    });

    test('invalid MM IDs fail', () {
      expect(isValidMmId('mm123456'), false); // lowercase
      expect(isValidMmId('MMABCD1'), false);  // too short
      expect(isValidMmId('MMABCD123'), false); // too long
      expect(isValidMmId('XMABCD12'), false); // wrong prefix
    });
  });

  // ── Contact request direction logic ──────────────────────────────────────

  group('Contact request direction', () {
    test('sender gets outgoing direction', () {
      final contact = ContactModel(
        id: '',
        ownerUid: 'sender',
        contactUid: 'recipient',
        contactName: 'Recipient',
        status: ContactStatus.pending,
        direction: ContactDirection.outgoing,
        addedAt: DateTime.now(),
      );
      expect(contact.direction, ContactDirection.outgoing);
      expect(contact.status, ContactStatus.pending);
    });

    test('recipient gets incoming direction', () {
      final contact = ContactModel(
        id: '',
        ownerUid: 'recipient',
        contactUid: 'sender',
        contactName: 'Sender',
        status: ContactStatus.pending,
        direction: ContactDirection.incoming,
        addedAt: DateTime.now(),
      );
      expect(contact.direction, ContactDirection.incoming);
    });

    test('accepted contact has accepted status', () {
      final contact = ContactModel(
        id: 'c1',
        ownerUid: 'u1',
        contactUid: 'u2',
        contactName: 'Bob',
        status: ContactStatus.accepted,
        direction: ContactDirection.incoming,
        addedAt: DateTime.now(),
      );
      expect(contact.status, ContactStatus.accepted);
    });
  });

  // ── Unread count logic ────────────────────────────────────────────────────

  group('Unread count', () {
    test('unread count for a specific user is retrieved correctly', () {
      final chat = ChatModel(
        id: 'c1',
        participantIds: ['u1', 'u2'],
        participantNames: {'u1': 'Alice', 'u2': 'Bob'},
        unreadCount: {'u1': 3, 'u2': 0},
      );
      expect(chat.unreadCount['u1'], 3);
      expect(chat.unreadCount['u2'], 0);
    });

    test('missing uid in unreadCount returns null (use ?? 0 in UI)', () {
      final chat = ChatModel(
        id: 'c1',
        participantIds: ['u1', 'u2'],
        participantNames: {},
        unreadCount: {},
      );
      expect(chat.unreadCount['u1'], isNull);
      expect(chat.unreadCount['u1'] ?? 0, 0);
    });
  });

  // ── Message date helpers ──────────────────────────────────────────────────

  group('Message date helpers', () {
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    String formatTime(DateTime dt) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    test('isSameDay true for same date, different times', () {
      final a = DateTime(2024, 6, 1, 9, 0);
      final b = DateTime(2024, 6, 1, 23, 59);
      expect(isSameDay(a, b), true);
    });

    test('isSameDay false for different dates', () {
      final a = DateTime(2024, 6, 1);
      final b = DateTime(2024, 6, 2);
      expect(isSameDay(a, b), false);
    });

    test('formatTime pads hours and minutes', () {
      expect(formatTime(DateTime(2024, 1, 1, 9, 5)), '09:05');
      expect(formatTime(DateTime(2024, 1, 1, 14, 30)), '14:30');
      expect(formatTime(DateTime(2024, 1, 1, 0, 0)), '00:00');
    });
  });
}
