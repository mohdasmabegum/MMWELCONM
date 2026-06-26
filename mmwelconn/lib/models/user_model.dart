import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String mmId;
  final String name;
  final String email;
  final String profilePicture;
  final String status;
  final String? currentMoodId;
  final bool notificationsEnabled;
  final bool autoUpdate;
  final DateTime createdAt;
  final DateTime lastActive;

  const UserModel({
    required this.uid,
    required this.mmId,
    required this.name,
    required this.email,
    this.profilePicture = '',
    this.status = 'online',
    this.currentMoodId,
    this.notificationsEnabled = true,
    this.autoUpdate = true,
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      mmId: d['mmId'] ?? '',
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      profilePicture: d['profilePicture'] ?? '',
      status: d['status'] ?? 'offline',
      currentMoodId: d['currentMoodId'],
      notificationsEnabled: d['notificationsEnabled'] ?? true,
      autoUpdate: d['autoUpdate'] ?? true,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastActive: d['lastActive'] != null
          ? (d['lastActive'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'mmId': mmId,
        'name': name,
        'email': email,
        'profilePicture': profilePicture,
        'status': status,
        'currentMoodId': currentMoodId,
        'notificationsEnabled': notificationsEnabled,
        'autoUpdate': autoUpdate,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastActive': Timestamp.fromDate(lastActive),
      };
}
