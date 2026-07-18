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
  final String ageGroup;
  final String customTheme;
  final double fontSizeScale;
  final bool highContrastEnabled;
  final DateTime? deletionScheduledAt;
  final int streakCount;
  final String lastActiveDate;
  final List<String> badges;
  final double kidsScreenTimeLimitHours;
  final int kidsBedtimeHour;
  final String kidsBgTheme;
  final String parentId;
  final bool kidsModeLocked;
  final DateTime? dateOfBirth;

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
    this.ageGroup = 'teen',
    this.customTheme = '',
    this.fontSizeScale = 1.0,
    this.highContrastEnabled = false,
    this.deletionScheduledAt,
    this.streakCount = 0,
    this.lastActiveDate = '',
    this.badges = const [],
    this.kidsScreenTimeLimitHours = 1.0,
    this.kidsBedtimeHour = 20,
    this.kidsBgTheme = 'space',
    this.parentId = '',
    this.kidsModeLocked = false,
    this.dateOfBirth,
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
      ageGroup: d['ageGroup'] ?? 'teen',
      customTheme: d['customTheme'] ?? '',
      fontSizeScale: (d['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
      highContrastEnabled: d['highContrastEnabled'] ?? false,
      deletionScheduledAt: d['deletionScheduledAt'] != null
          ? (d['deletionScheduledAt'] as Timestamp).toDate()
          : null,
      streakCount: d['streakCount'] ?? 0,
      lastActiveDate: d['lastActiveDate'] ?? '',
      badges: List<String>.from(d['badges'] ?? []),
      kidsScreenTimeLimitHours: (d['kidsScreenTimeLimitHours'] as num?)?.toDouble() ?? 1.0,
      kidsBedtimeHour: d['kidsBedtimeHour'] ?? 20,
      kidsBgTheme: d['kidsBgTheme'] ?? 'space',
      parentId: d['parentId'] ?? '',
      kidsModeLocked: d['kidsModeLocked'] ?? false,
      dateOfBirth: d['dateOfBirth'] != null ? (d['dateOfBirth'] as Timestamp).toDate() : null,
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
        'ageGroup': ageGroup,
        'customTheme': customTheme,
        'fontSizeScale': fontSizeScale,
        'highContrastEnabled': highContrastEnabled,
        'deletionScheduledAt': deletionScheduledAt != null ? Timestamp.fromDate(deletionScheduledAt!) : null,
        'streakCount': streakCount,
        'lastActiveDate': lastActiveDate,
        'badges': badges,
        'kidsScreenTimeLimitHours': kidsScreenTimeLimitHours,
        'kidsBedtimeHour': kidsBedtimeHour,
        'kidsBgTheme': kidsBgTheme,
        'parentId': parentId,
        'kidsModeLocked': kidsModeLocked,
        'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      };

  String get profileImageUrl => profilePicture;

  bool get hasActiveMood {
    if (currentMoodId == null || currentMoodSetAt == null) return false;
    return DateTime.now().difference(currentMoodSetAt!).inHours < 24;
  }

  DateTime? get currentMoodExpiresAt => currentMoodSetAt?.add(const Duration(hours: 24));
}
