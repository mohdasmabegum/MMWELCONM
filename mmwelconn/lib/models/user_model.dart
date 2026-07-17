import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String mmId;
  final String name;
  final String email;
  final String profilePicture;
  final String status;
  final String? currentMoodId;
  final DateTime? currentMoodSetAt;
  final bool notificationsEnabled;
  final bool autoUpdate;
  final bool showOnline;
  final bool publicProfileVisible;
  final DateTime createdAt;
  final DateTime lastActive;
  final String? fcmToken;
  final String chatLockPin;
  final String chatLockPattern;

  const UserModel({
    required this.uid,
    required this.mmId,
    required this.name,
    required this.email,
    this.profilePicture = '',
    this.status = 'online',
    this.currentMoodId,
    this.currentMoodSetAt,
    this.notificationsEnabled = true,
    this.autoUpdate = true,
    this.showOnline = true,
    this.publicProfileVisible = true,
    required this.createdAt,
    required this.lastActive,
    this.fcmToken,
    this.chatLockPin = '1234',
    this.chatLockPattern = '',
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
      currentMoodSetAt: d['currentMoodSetAt'] != null
          ? (d['currentMoodSetAt'] as Timestamp).toDate()
          : null,
      notificationsEnabled: d['notificationsEnabled'] ?? true,
      autoUpdate: d['autoUpdate'] ?? true,
      showOnline: d['showOnline'] ?? true,
      publicProfileVisible: d['publicProfileVisible'] ?? true,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastActive: d['lastActive'] != null
          ? (d['lastActive'] as Timestamp).toDate()
          : DateTime.now(),
      fcmToken: d['fcmToken'],
      chatLockPin: d['chatLockPin'] ?? '1234',
      chatLockPattern: d['chatLockPattern'] ?? '',
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
        'currentMoodSetAt': currentMoodSetAt != null ? Timestamp.fromDate(currentMoodSetAt!) : null,
        'notificationsEnabled': notificationsEnabled,
        'autoUpdate': autoUpdate,
        'showOnline': showOnline,
        'publicProfileVisible': publicProfileVisible,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastActive': Timestamp.fromDate(lastActive),
        'fcmToken': fcmToken,
        'chatLockPin': chatLockPin,
        'chatLockPattern': chatLockPattern,
      };

  String get profileImageUrl => profilePicture;

  bool get hasActiveMood {
    if (currentMoodId == null || currentMoodSetAt == null) return false;
    return DateTime.now().difference(currentMoodSetAt!).inHours < 24;
  }

  DateTime? get currentMoodExpiresAt => currentMoodSetAt?.add(const Duration(hours: 24));
}
