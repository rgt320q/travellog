import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:travellog/models/location_group.dart';
import 'package:travellog/models/travel_location.dart';
import 'package:travellog/screens/groups_screen.dart';
import 'package:travellog/screens/location_detail_screen.dart';
import 'package:travellog/screens/location_selection_screen.dart';
import 'package:travellog/screens/manage_locations_screen.dart';
import 'package:travellog/services/database_service.dart';
import 'package:travellog/services/directions_service.dart';
import 'package:travellog/services/firestore_service.dart';
import 'package:travellog/services/notification_service.dart';
import 'package:travellog/services/wikipedia_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travellog/utils/marker_utils.dart' as marker_utils;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // State for data
  List<TravelLocation> _allLocations = [];
  List<LocationGroup> _allGroups = [];

  // State for route tracking and notifications
  List<TravelLocation>? _activeRouteLocations;
  final Set<String> _triggeredWikipediaNotifications = {};
  final Map<String, Timer> _waypointTimers = {};

  // Services
  final FirestoreService _firestoreService = FirestoreService();
  final DirectionsService _directionsService = DirectionsService();
  final WikipediaService _wikipediaService = WikipediaService();
  final NotificationService _notificationService = NotificationService();

  // Subscriptions
  StreamSubscription? _locationsSubscription;
  StreamSubscription? _groupsSubscription;
  StreamSubscription? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _setupDataSync();
  }

  @override
  void dispose() {
    _locationsSubscription?.cancel();
    _groupsSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _waypointTimers.forEach((_, timer) => timer.cancel());
    super.dispose();
  }

  //-------------------------------------------------------------------
  // Route & Geofencing Logic
  //-------------------------------------------------------------------

  void _clearRoute() {
    setState(() {
      _polylines.clear();
      _activeRouteLocations = null;
    });
    _positionStreamSubscription?.cancel();
    // Cancel all active timers and clear state
    _waypointTimers.forEach((key, timer) => timer.cancel());
    _waypointTimers.clear();
    _triggeredWikipediaNotifications.clear();
  }

  void _startRouteTracking(List<TravelLocation> locations) {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
    }
    setState(() {
      _activeRouteLocations = locations;
    });

    _positionStreamSubscription = Geolocator.getPositionStream().listen((Position position) {
      _checkAllWaypointsProximity(position);
    });
  }

  void _checkAllWaypointsProximity(Position userPosition) {
    if (_activeRouteLocations == null) return;

    for (final location in _activeRouteLocations!) {
      final distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        location.latitude,
        location.longitude,
      );

      final locationId = location.firestoreId!;

      // User is inside the location radius
      if (distance < 500) {
        // Trigger Wikipedia notification only once
        if (!_triggeredWikipediaNotifications.contains(locationId)) {
          _triggeredWikipediaNotifications.add(locationId);
          _wikipediaService.getSummary(location.name).then((summary) {
            final title = 'Yakınlardasınız: ${location.name}';
            final body = summary ?? '''Bu konum için Wikipedia'da özet bilgi bulunamadı.''';
            _notificationService.showNotification(title, body);
          });
        }

        // Start timer only once if duration is set
        if (!_waypointTimers.containsKey(locationId) && (location.estimatedDuration ?? 0) > 0) {
          print('Starting timer for ${location.name}');
          final timer = Timer(Duration(minutes: location.estimatedDuration!), () {
            _notificationService.showNotification(
              'Süreniz Doldu!',
              '${location.name} konumunda planladığınız süre doldu.'
            );
            _waypointTimers.remove(locationId);
          });
          _waypointTimers[locationId] = timer;
        }
      } 
      // User is outside the location radius
      else {
        // If a timer was running, cancel it as the user left the area
        if (_waypointTimers.containsKey(locationId)) {
          print('User left ${location.name}, cancelling timer.');
          _waypointTimers[locationId]!.cancel();
          _waypointTimers.remove(locationId);
        }
      }
    }
  }

  //-------------------------------------------------------------------
  // Data Sync & Initial Setup
  //-------------------------------------------------------------------

  void _setupDataSync() {
    if (FirebaseAuth.instance.currentUser == null) {
      _loadMarkersFromLocalDb(); // Keep local DB logic for logged-out state
      return;
    }

    // Cancel existing subscriptions
    _locationsSubscription?.cancel();
    _groupsSubscription?.cancel();

    // Listen to locations stream
    _locationsSubscription = _firestoreService.getLocations().listen((locations) {
      setState(() {
        _allLocations = locations;
      });
      _updateMarkers();
    }, onError: (error) {
      print("Error listening to Firestore locations: $error");
      _loadMarkersFromLocalDb();
    });

    // Listen to groups stream
    _groupsSubscription = _firestoreService.getGroups().listen((groups) {
      setState(() {
        _allGroups = groups;
      });
      _updateMarkers();
    }, onError: (error) {
      print("Error listening to Firestore groups: $error");
    });
  }

  Future<void> _updateMarkers() async {
    final groupsMap = { for (var group in _allGroups) group.firestoreId!: group };
    final Set<Marker> newMarkers = {};

    // Add marker for current position
    if (_currentPosition != null) {
      final BitmapDescriptor currentLocMarkerIcon = await marker_utils.getCustomMarkerIcon(Colors.blueAccent);
      newMarkers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Mevcut Konum'),
          icon: currentLocMarkerIcon,
        ),
      );
    }

    // Add markers for all locations
    for (final loc in _allLocations) {
      BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed); // Default color

      if (loc.groupId != null && groupsMap.containsKey(loc.groupId)) {
        final group = groupsMap[loc.groupId];
        if (group?.color != null) {
          markerIcon = await marker_utils.getCustomMarkerIcon(Color(group!.color!));
        }
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId(loc.firestoreId ?? loc.hashCode.toString()),
          position: LatLng(loc.latitude, loc.longitude),
          infoWindow: InfoWindow(title: loc.name, snippet: loc.description),
          icon: markerIcon,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LocationDetailScreen(location: loc),
              ),
            );
          },
        ),
      );
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  Future<void> _loadMarkersFromLocalDb() async {
    final locations = await DatabaseService.instance.readAllLocations();
    setState(() {
       for (final loc in locations) {
        _markers.add(
          Marker(
            markerId: MarkerId(loc.id.toString()),
            position: LatLng(loc.latitude, loc.longitude),
            infoWindow: InfoWindow(title: loc.name, snippet: loc.description),
             onTap: () {},
          ),
        );
      }
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
    } 

    _currentPosition = await Geolocator.getCurrentPosition();
    _goToCurrentLocation();
  }

  void _goToCurrentLocation() {
    if (_currentPosition == null || _mapController == null) return;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 15,
        ),
      ),
    );
    _addCurrentLocationMarker();
  }

  Future<void> _addCurrentLocationMarker() async { // Made async
     if (_currentPosition == null) return;
            final BitmapDescriptor currentLocMarkerIcon = await marker_utils.getCustomMarkerIcon(Colors.blueAccent); // Use a distinct color for current location
      setState(() {
        _markers.add(
          Marker(
                      markerId: const MarkerId('currentLocation'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Current Location'),
            icon: currentLocMarkerIcon, // Use the custom icon
          ),
        );
      });
  }

  //-------------------------------------------------------------------
  // UI Methods (Dialogs & Bottom Sheets)
  //-------------------------------------------------------------------

  Future<void> _drawRoute(List<TravelLocation> locations) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mevcut konumunuz alınamadı. Lütfen konum servislerini kontrol edin.')),
      );
      return;
    }

    final userLocation = TravelLocation(
      name: 'Mevcut Konumunuz',
      description: 'Rota başlangıcı',
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
    );

    final routeLocations = [userLocation, ...locations];

    final directionsInfo = await _directionsService.getDirections(routeLocations);

    if (directionsInfo != null) {
      setState(() {
        _polylines.clear();
        final polyline = Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: directionsInfo.polylinePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
        );
        _polylines.add(polyline);
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(directionsInfo.bounds, 50),
      );

      _showRouteSummary(directionsInfo, locations);
      _startRouteTracking(locations);
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rota çizilemedi. API anahtarınızı kontrol edin veya daha sonra tekrar deneyin.')),
       );
    }
  }

  void _showRouteSummary(DirectionsInfo info, List<TravelLocation> locations) {
    final consolidatedNeeds = locations
        .where((loc) => loc.needsList != null)
        .expand((loc) => loc.needsList!)
        .toSet()
        .toList();

    final privateNotes = locations
        .where((loc) => loc.notes != null && loc.notes!.isNotEmpty)
        .map((loc) => '${loc.name}: ${loc.notes}')
        .toList();

    final totalStopDuration = locations.fold<int>(
      0,
      (sum, loc) => sum + (loc.estimatedDuration ?? 0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow bottom sheet to take more height
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rota Özeti', style: Theme.of(context).textTheme.headlineSmall),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close the bottom sheet
                    _launchGoogleMaps(locations);
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Başlat'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 14)
                  ),
                ),
              ],
            ),
            const Divider(),
            // Make the rest of the content scrollable in case it overflows
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(title: Text('Toplam Yol Süresi: ${info.totalDuration}')),
                  ListTile(title: Text('Toplam Mesafe: ${info.totalDistance}')),
                  ListTile(title: Text('Konumlardaki Süre: $totalStopDuration dakika')),
                  const Divider(),
                  if (consolidatedNeeds.isNotEmpty)
                    ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text('Bu gezi için ihtiyaçlarınız:', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      ...consolidatedNeeds.map((need) => ListTile(leading: const Icon(Icons.check_box_outline_blank), title: Text(need))),
                      const Divider(),
                    ],
                  if (privateNotes.isNotEmpty)
                    ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text('Bu gezi için aldığınız özel notlar:', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      ...privateNotes.map((note) => ListTile(leading: const Icon(Icons.note), title: Text(note))),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchGoogleMaps(List<TravelLocation> locations) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mevcut konum alınamadı. Rota başlatılamıyor.')),
      );
      return;
    }
    if (locations.isEmpty) return;

    final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final destination = '${locations.last.latitude},${locations.last.longitude}';
    String waypoints = '';

    // All locations in the list, except the last one, are waypoints.
    if (locations.length > 1) {
      waypoints = locations
          .sublist(0, locations.length - 1)
          .map((loc) => '${loc.latitude},${loc.longitude}')
          .join('|');
    }

    String url = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=$waypoints';
    }
    url += '&travelmode=driving';

    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Haritalar uygulaması başlatılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Log'),
        actions: [
          if (_activeRouteLocations == null)
            IconButton(
              icon: const Icon(Icons.directions),
              tooltip: 'Rota Oluştur',
              onPressed: _showRouteCreationDialog,
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Rotayı Temizle',
              onPressed: _clearRoute,
            ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Konumları Yönet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageLocationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_copy_outlined),
            tooltip: 'Grupları Yönet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GroupsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
        backgroundColor: Colors.blue[700],
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
        initialCameraPosition: const CameraPosition(
          target: LatLng(38.9637, 35.2433), // Turkey
          zoom: 5,
        ),
        markers: _markers,
        polylines: _polylines,
        onLongPress: _showAddLocationDialog,
      ),
    );
  }

  void _showRouteCreationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Route'),
        content: const Text('How would you like to create your route?'),
        actions: [
          TextButton(
            child: const Text('Select from Group'),
            onPressed: () async {
              // First, close the dialog
              Navigator.of(dialogContext).pop();

              // Then, push the new screen to select a group
              final result = await Navigator.push<Map<String, String>>(
                context,
                MaterialPageRoute(builder: (context) => const GroupsScreen(isForSelection: true)),
              );

              if (!mounted || result == null) return;

              final selectedGroupId = result['id'];

              if (selectedGroupId != null) {
                final locations = await _firestoreService.getLocationsForGroup(selectedGroupId);
                if (locations.length >= 2) {
                  _drawRoute(locations);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bir rota oluşturmak için en az 2 konum gereklidir.')),
                  );
                }
              }
            },
          ),
          TextButton(
            child: const Text('Manual Selection'),
            onPressed: () async {
              // First, close the dialog
              Navigator.of(dialogContext).pop();

              // Then, push the new screen for manual selection
              final List<TravelLocation>? selectedLocations = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LocationSelectionScreen()),
              );

              if (!mounted || selectedLocations == null) return;

              if (selectedLocations.length >= 2) {
                _drawRoute(selectedLocations);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bir rota oluşturmak için en az 2 konum seçmelisiniz.')),
                );
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }

  void _showAddLocationDialog(LatLng pos) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final notesController = TextEditingController();
    final needsController = TextEditingController();
    final durationController = TextEditingController();
    String? selectedGroupId;
    String? selectedGroupName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Yeni Konum Ekle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Konum Adı', icon: Icon(Icons.location_on)),
                      autofocus: true,
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Açıklama', icon: Icon(Icons.description)),
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Özel Notlar', icon: Icon(Icons.note)),
                    ),
                    TextField(
                      controller: durationController,
                      decoration: const InputDecoration(labelText: 'Tahmini Süre (dakika)', icon: Icon(Icons.timer)),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: needsController,
                      decoration: const InputDecoration(labelText: 'İhtiyaçlar (virgülle ayırın)', icon: Icon(Icons.list)),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.group),
                      title: Text(selectedGroupName ?? 'Grup Seç (İsteğe Bağlı)'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GroupsScreen(isForSelection: true),
                          ),
                        );
                        if (result != null && result is Map<String, String>) {
                          setState(() {
                            selectedGroupId = result['id'];
                            selectedGroupName = result['name'];
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final needsList = needsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      final duration = int.tryParse(durationController.text);

                      final newLocation = TravelLocation(
                        name: nameController.text,
                        description: descriptionController.text,
                        latitude: pos.latitude,
                        longitude: pos.longitude,
                        groupId: selectedGroupId,
                        notes: notesController.text,
                        needsList: needsList,
                        estimatedDuration: duration,
                      );

                      await _firestoreService.addLocation(newLocation);

                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}