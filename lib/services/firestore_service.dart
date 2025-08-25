
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travellog/models/travel_location.dart';
import 'package:travellog/models/location_group.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  // Prevent public instantiation
  FirestoreService();

  // Get user-specific locations collection
  CollectionReference<TravelLocation> get _locationsCollection {
    if (_currentUser == null) {
      throw Exception('User not logged in');
    }
    return _db
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('locations')
        .withConverter<TravelLocation>(
          fromFirestore: (snapshots, _) => TravelLocation.fromFirestore(snapshots.id, snapshots.data()!),
          toFirestore: (location, _) => location.toFirestore(),
        );
  }

  Future<void> addLocation(TravelLocation location) async {
    await _locationsCollection.add(location);
  }

  Stream<List<TravelLocation>> getLocations() {
    return _locationsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> updateLocation(String id, TravelLocation location) async {
    await _locationsCollection.doc(id).update(location.toFirestore());
  }

  Future<void> deleteLocation(String id) async {
    await _locationsCollection.doc(id).delete();
  }

  // GROUPS

  CollectionReference<LocationGroup> get _groupsCollection {
    if (_currentUser == null) {
      throw Exception('User not logged in');
    }
    return _db
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('groups')
        .withConverter<LocationGroup>(
          fromFirestore: (snapshot, _) => LocationGroup.fromFirestore(snapshot.id, snapshot.data()!),
          toFirestore: (group, _) => group.toFirestore(),
        );
  }

  Stream<List<LocationGroup>> getGroups() {
    return _groupsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<List<LocationGroup>> getGroupsOnce() async {
    final snapshot = await _groupsCollection.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> addGroup(LocationGroup group) async {
    await _groupsCollection.add(group);
  }

  Future<List<TravelLocation>> getLocationsForGroup(String groupId) async {
    final snapshot = await _locationsCollection.where('groupId', isEqualTo: groupId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> updateGroup(String id, LocationGroup group) async {
    await _groupsCollection.doc(id).update(group.toFirestore());
  }

  Future<void> deleteGroup(String id) async {
    // Delete all locations associated with this group
    final locationsToDelete = await _locationsCollection.where('groupId', isEqualTo: id).get();
    for (final doc in locationsToDelete.docs) {
      await doc.reference.delete();
    }
    // Then delete the group itself
    await _groupsCollection.doc(id).delete();
  }
}

// We need to add fromFirestore and toFirestore methods to our TravelLocation model.
