import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType { direct, group }

class ChatModel {
  final String id;
  final ChatType chatType;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final String? groupName;
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCount;

  const ChatModel({
    required this.id,
    this.chatType = ChatType.direct,
    required this.participantIds,
    required this.participantNames,
    this.groupName,
    this.lastMessage,
    this.lastSenderId,
    this.lastMessageAt,
    this.unreadCount = const {},
  });

  factory ChatModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      chatType: ChatType.values.firstWhere(
          (t) => t.name == (d['chatType'] ?? 'direct'),
          orElse: () => ChatType.direct),
      participantIds: List<String>.from(d['participantIds'] ?? []),
      participantNames: Map<String, String>.from(d['participantNames'] ?? {}),
      groupName: d['groupName'],
      lastMessage: d['lastMessage'],
      lastSenderId: d['lastSenderId'],
      lastMessageAt: d['lastMessageAt'] != null
          ? (d['lastMessageAt'] as Timestamp).toDate()
          : null,
      unreadCount: Map<String, int>.from(d['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'chatType': chatType.name,
        'participantIds': participantIds,
        'participantNames': participantNames,
        'groupName': groupName,
        'lastMessage': lastMessage,
        'lastSenderId': lastSenderId,
        'lastMessageAt':
            lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'unreadCount': unreadCount,
      };
}

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      senderName: d['senderName'] ?? '',
      text: d['text'] ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
