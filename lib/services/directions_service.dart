
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:travellog/models/travel_location.dart';

class DirectionsInfo {
  final LatLngBounds bounds;
  final List<PointLatLng> polylinePoints;
  final String totalDistance;
  final String totalDuration;

  const DirectionsInfo({
    required this.bounds,
    required this.polylinePoints,
    required this.totalDistance,
    required this.totalDuration,
  });
}

class DirectionsService {
  final String _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'YOUR_API_KEY_HERE';

  Future<DirectionsInfo?> getDirections(List<TravelLocation> locations) async {
    if (locations.length < 2) return null;

    final origin = locations.first;
    final destination = locations.last;
    final waypoints = locations.length > 2 
      ? locations.sublist(1, locations.length - 1)
          .map((loc) => '${loc.latitude},${loc.longitude}')
          .join('|')
      : '';

    final url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}'
        '${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}&'
        'key=$_apiKey';

    print('Directions API Request URL: $url');
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final json = convert.jsonDecode(response.body);

      if ((json["routes"] as List).isEmpty) return null;

      final route = json["routes"][0];
      final leg = route["legs"][0];

      final overviewPolyline = route["overview_polyline"]["points"];
      final points = PolylinePoints.decodePolyline(overviewPolyline);

      final bounds = LatLngBounds(
        southwest: LatLng(route["bounds"]["southwest"]['lat'], route["bounds"]["southwest"]['lng']),
        northeast: LatLng(route["bounds"]["northeast"]['lat'], route["bounds"]["northeast"]['lng']),
      );

      return DirectionsInfo(
        bounds: bounds,
        polylinePoints: points,
        totalDistance: leg["distance"]['text'],
        totalDuration: leg["duration"]['text'],
      );
    } else {
      print('Directions API failed with status: ${response.statusCode}');
      print('Directions API Response Body: ${response.body}');
      return null;
    }
  }
}
