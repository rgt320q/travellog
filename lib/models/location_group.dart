
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationGroup {
  final String? firestoreId;
  final String name;
  final int? color; // Added color field
  final DateTime? createdAt;

  LocationGroup({this.firestoreId, required this.name, this.color, this.createdAt}); // Updated constructor

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'color': color, // Added color to Firestore map
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory LocationGroup.fromFirestore(String id, Map<String, dynamic> firestoreMap) {
    return LocationGroup(
      firestoreId: id,
      name: firestoreMap['name'] as String,
      color: firestoreMap['color'] as int?,
      createdAt: (firestoreMap['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
