import 'package:cloud_firestore/cloud_firestore.dart';

class MoodModel {
  final String id;
  final String userId;
  final String userDisplayName;
  final String userPhotoUrl;
  final String emoji;
  final String label;
  final String? note;
  final bool isPublic;
  final DateTime createdAt;

  const MoodModel({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    this.userPhotoUrl = '',
    required this.emoji,
    required this.label,
    this.note,
    this.isPublic = true,
    required this.createdAt,
  });

  factory MoodModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MoodModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      userDisplayName: d['userDisplayName'] ?? '',
      userPhotoUrl: d['userPhotoUrl'] ?? '',
      emoji: d['emoji'] ?? '',
      label: d['label'] ?? '',
      note: d['note'],
      isPublic: d['isPublic'] ?? true,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userDisplayName': userDisplayName,
        'userPhotoUrl': userPhotoUrl,
        'emoji': emoji,
        'label': label,
        'note': note,
        'isPublic': isPublic,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
