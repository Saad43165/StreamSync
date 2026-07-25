import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing Consumet API...');
  try {
    final searchUrl = 'https://api.consumet.org/movies/flixhq/Inception';
    final searchRes = await http.get(Uri.parse(searchUrl));
    print('Consumet Search: ${searchRes.statusCode}');
    if (searchRes.statusCode == 200) {
      print(searchRes.body.substring(0, 200));
    }
  } catch (e) {
    print('Consumet error: $e');
  }
}
