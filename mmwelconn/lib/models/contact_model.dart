import 'package:cloud_firestore/cloud_firestore.dart';

enum ContactStatus { none, pending, accepted, declined, blocked }

enum ContactDirection { incoming, outgoing }

enum RelationshipType { friend, family, partner, other }

class ContactModel {
  final String id;
  final String ownerUid;
  final String contactUid;
  final String contactMmId;
  final String contactName;
  final String contactPhotoUrl;
  final ContactStatus status;
  final ContactDirection direction;
  final RelationshipType relationshipType;
  final DateTime addedAt;

  const ContactModel({
    required this.id,
    required this.ownerUid,
    required this.contactUid,
    this.contactMmId = '',
    required this.contactName,
    this.contactPhotoUrl = '',
    this.status = ContactStatus.pending,
    this.direction = ContactDirection.incoming,
    this.relationshipType = RelationshipType.friend,
    required this.addedAt,
  });

  factory ContactModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ContactModel(
      id: doc.id,
      ownerUid: d['ownerUid'] ?? '',
      contactUid: d['contactUid'] ?? '',
      contactMmId: d['contactMmId'] ?? '',
      contactName: d['contactName'] ?? '',
      contactPhotoUrl: d['contactPhotoUrl'] ?? '',
      status: ContactStatus.values.firstWhere(
          (s) => s.name == (d['status'] ?? 'pending'),
          orElse: () => ContactStatus.pending),
      direction: ContactDirection.values.firstWhere(
          (dir) => dir.name == (d['direction'] ?? 'incoming'),
          orElse: () => ContactDirection.incoming),
      relationshipType: RelationshipType.values.firstWhere(
          (r) => r.name == (d['relationshipType'] ?? 'friend'),
          orElse: () => RelationshipType.friend),
      addedAt: d['addedAt'] != null
          ? (d['addedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'contactUid': contactUid,
        'contactMmId': contactMmId,
        'contactName': contactName,
        'contactPhotoUrl': contactPhotoUrl,
        'status': status.name,
        'direction': direction.name,
        'relationshipType': relationshipType.name,
        'addedAt': Timestamp.fromDate(addedAt),
      };
}
