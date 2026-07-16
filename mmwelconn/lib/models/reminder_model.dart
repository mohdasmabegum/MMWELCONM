import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime remindAt;
  final DateTime createdAt;
  final bool isCompleted;

  const ReminderModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.remindAt,
    required this.createdAt,
    this.isCompleted = false,
  });

  factory ReminderModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReminderModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      remindAt: d['remindAt'] != null
          ? (d['remindAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isCompleted: d['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'description': description,
        'remindAt': Timestamp.fromDate(remindAt),
        'createdAt': Timestamp.fromDate(createdAt),
        'isCompleted': isCompleted,
      };
}
