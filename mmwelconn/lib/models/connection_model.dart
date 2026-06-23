import 'package:cloud_firestore/cloud_firestore.dart';

enum ConnectionStatus { pending, accepted, declined }

class ConnectionModel {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final ConnectionStatus status;
  final DateTime createdAt;

  const ConnectionModel({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.status,
    required this.createdAt,
  });

  factory ConnectionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ConnectionModel(
      id: doc.id,
      fromUserId: d['fromUserId'] ?? '',
      fromUserName: d['fromUserName'] ?? '',
      toUserId: d['toUserId'] ?? '',
      toUserName: d['toUserName'] ?? '',
      status: ConnectionStatus.values.byName(d['status'] ?? 'pending'),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'toUserId': toUserId,
        'toUserName': toUserName,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
