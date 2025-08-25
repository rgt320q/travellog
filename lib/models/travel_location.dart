
import 'package:cloud_firestore/cloud_firestore.dart';

class TravelLocation {
  final int? id; // Local DB id
  final String? firestoreId; // Firestore document id
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String? groupId;
  final String? notes;
  final List<String>? needsList;
  final int? estimatedDuration; // Duration in minutes
  final DateTime? createdAt;

  TravelLocation({
    this.id,
    this.firestoreId,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.groupId,
    this.notes,
    this.needsList,
    this.estimatedDuration,
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      "name": name,
      "description": description,
      "latitude": latitude,
      "longitude": longitude,
      if (groupId != null) "groupId": groupId,
      if (notes != null) "notes": notes,
      if (needsList != null) "needsList": needsList,
      if (estimatedDuration != null) "estimatedDuration": estimatedDuration,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory TravelLocation.fromFirestore(String id, Map<String, dynamic> firestoreMap) {
    return TravelLocation(
      firestoreId: id,
      name: firestoreMap['name'] as String,
      description: firestoreMap['description'] as String,
      latitude: firestoreMap['latitude'] as double,
      longitude: firestoreMap['longitude'] as double,
      groupId: firestoreMap['groupId'] as String?,
      notes: firestoreMap['notes'] as String?,
      needsList: firestoreMap['needsList'] != null
          ? List<String>.from(firestoreMap['needsList'])
          : null,
      estimatedDuration: firestoreMap['estimatedDuration'] as int?,
      createdAt: (firestoreMap['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TravelLocation &&
        (firestoreId != null && other.firestoreId != null
            ? firestoreId == other.firestoreId
            : name == other.name &&
              latitude == other.latitude &&
              longitude == other.longitude);
  }

  @override
  int get hashCode {
    return firestoreId != null
        ? firestoreId.hashCode
        : Object.hash(name, latitude, longitude);
  }
}
