import 'package:cloud_firestore/cloud_firestore.dart';

enum ContactStatus { none, pending, accepted, blocked }

class ContactModel {
  final String id;
  final String ownerUid;
  final String contactUid;
  final String contactName;
  final String contactPhotoUrl;
  final ContactStatus status;
  final DateTime addedAt;

  const ContactModel({
    required this.id,
    required this.ownerUid,
    required this.contactUid,
    required this.contactName,
    this.contactPhotoUrl = '',
    this.status = ContactStatus.pending,
    required this.addedAt,
  });

  factory ContactModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ContactModel(
      id: doc.id,
      ownerUid: d['ownerUid'] ?? '',
      contactUid: d['contactUid'] ?? '',
      contactName: d['contactName'] ?? '',
      contactPhotoUrl: d['contactPhotoUrl'] ?? '',
      status: ContactStatus.values.byName(d['status'] ?? 'pending'),
      addedAt: (d['addedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'contactUid': contactUid,
        'contactName': contactName,
        'contactPhotoUrl': contactPhotoUrl,
        'status': status.name,
        'addedAt': Timestamp.fromDate(addedAt),
      };
}
