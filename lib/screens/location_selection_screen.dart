
import 'package:flutter/material.dart';
import 'package:travellog/models/travel_location.dart';
import 'package:travellog/services/firestore_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final List<TravelLocation> _selectedLocations = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Seç'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.of(context).pop(_selectedLocations);
            },
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
            return const Center(child: Text('Henüz konum bulunmamaktadır.'));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }

          final locations = snapshot.data!;
          return AnimationLimiter(
            child: ListView.builder(
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                final isSelected = _selectedLocations.contains(location);
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        ),
                        title: Text(location.name),
                        subtitle: Text(location.description),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedLocations.remove(location);
                            } else {
                              _selectedLocations.add(location);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
