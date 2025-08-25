
import 'package:flutter/material.dart';
import 'package:travellog/models/travel_location.dart';
import 'package:travellog/services/firestore_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: StreamBuilder<List<TravelLocation>>(
        stream: _firestoreService.getLocationsForGroup(widget.groupId).asStream(), // Convert Future to Stream
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Bu grupta henüz konum bulunmamaktadır.'));
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
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(location.name),
                        subtitle: Text(location.description),
                        // TODO: Add onTap to navigate to location detail screen
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
