
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class WikipediaService {

  Future<String?> getSummary(String placeName) async {
    final authority = 'en.wikipedia.org';
    final path = '/api/rest_v1/page/summary/${Uri.encodeComponent(placeName)}';
    
    try {
      final response = await http.get(Uri.https(authority, path));

      if (response.statusCode == 200) {
        final jsonResponse = convert.jsonDecode(response.body);
        final summary = jsonResponse['extract'] as String?;
        if (summary != null && summary.isNotEmpty) {
          return summary;
        } else {
          return null; // Found the page, but no summary
        }
      } else {
        // Page not found or other error
        return null;
      }
    } catch (e) {
      print('Error connecting to Wikipedia API: $e');
      return null;
    }
  }
}
