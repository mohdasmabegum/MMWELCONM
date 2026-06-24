import 'package:cloud_firestore/cloud_firestore.dart';

enum ContactStatus { none, pending, accepted, declined, blocked }

enum RelationshipType { friend, family, partner, other }

class ContactModel {
  final String id;
  final String ownerUid;
  final String contactUid;
  final String contactMmId;
  final String contactName;
  final String contactPhotoUrl;
  final ContactStatus status;
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
      status: ContactStatus.values.byName(d['status'] ?? 'pending'),
      relationshipType: RelationshipType.values.byName(d['relationshipType'] ?? 'friend'),
      addedAt: (d['addedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'contactUid': contactUid,
        'contactMmId': contactMmId,
        'contactName': contactName,
        'contactPhotoUrl': contactPhotoUrl,
        'status': status.name,
        'relationshipType': relationshipType.name,
        'addedAt': Timestamp.fromDate(addedAt),
      };
}
