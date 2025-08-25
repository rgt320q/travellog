
import 'package:flutter/material.dart';
import 'package:travellog/models/travel_location.dart';
import 'package:travellog/services/firestore_service.dart';
import 'package:travellog/screens/location_detail_screen.dart';

class ManageLocationsScreen extends StatefulWidget {
  const ManageLocationsScreen({super.key});

  @override
  State<ManageLocationsScreen> createState() => _ManageLocationsScreenState();
}

enum SortBy { nameAsc, nameDesc, dateNewest, dateOldest }

class _ManageLocationsScreenState extends State<ManageLocationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  SortBy _currentSortBy = SortBy.dateNewest;

  void _sortLocations(List<TravelLocation> locations) {
    switch (_currentSortBy) {
      case SortBy.nameAsc:
        locations.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortBy.nameDesc:
        locations.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortBy.dateNewest:
        // Assuming TravelLocation has a 'createdAt' timestamp.
        // If not, this needs to be added to the model and Firestore documents.
        locations.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        break;
      case SortBy.dateOldest:
        locations.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konumları Yönet'),
        actions: [
          PopupMenuButton<SortBy>(
            icon: const Icon(Icons.sort),
            onSelected: (SortBy result) {
              setState(() {
                _currentSortBy = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortBy>>[
              const PopupMenuItem<SortBy>(
                value: SortBy.nameAsc,
                child: Text('Ada Göre (A-Z)'),
              ),
              const PopupMenuItem<SortBy>(
                value: SortBy.nameDesc,
                child: Text('Ada Göre (Z-A)'),
              ),
              const PopupMenuItem<SortBy>(
                value: SortBy.dateNewest,
                child: Text('Tarihe Göre (Yeni)'),
              ),
              const PopupMenuItem<SortBy>(
                value: SortBy.dateOldest,
                child: Text('Tarihe Göre (Eski)'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<TravelLocation>>(
        stream: _firestoreService.getLocations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Kaydedilmiş konum bulunamadı.'));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }

          final locations = snapshot.data!;
          _sortLocations(locations);

          return ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              return ListTile(
                title: Text(location.name),
                subtitle: Text(location.description ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final bool? confirmDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Konumu Sil'),
                        content: Text('${location.name} konumunu silmek istediğinizden emin misiniz?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('İptal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                    if (confirmDelete == true && location.firestoreId != null) {
                      await _firestoreService.deleteLocation(location.firestoreId!);
                    }
                  },
                ),
                onTap: () {
                  // Navigate to LocationDetailScreen to edit
                   Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationDetailScreen(location: location),
                      ),
                    );
                },
              );
            },
          );
        },
      ),
    );
  }
}
