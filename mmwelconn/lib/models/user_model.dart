import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profilePicture;
  final String status;
  final String? currentMoodId;
  final String? phoneNumber;
  final bool mfaEnabled;
  final DateTime createdAt;
  final DateTime lastActive;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profilePicture = '',
    this.status = 'online',
    this.currentMoodId,
    this.phoneNumber,
    this.mfaEnabled = false,
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      profilePicture: d['profilePicture'] ?? '',
      status: d['status'] ?? 'offline',
      currentMoodId: d['currentMoodId'],
      phoneNumber: d['phoneNumber'],
      mfaEnabled: d['mfaEnabled'] ?? false,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      lastActive: (d['lastActive'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'profilePicture': profilePicture,
        'status': status,
        'currentMoodId': currentMoodId,
        'phoneNumber': phoneNumber,
        'mfaEnabled': mfaEnabled,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastActive': Timestamp.fromDate(lastActive),
      };
}
