import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LibraryHelper {
  static const String _key = 'user_library_songs';

  // Save a song map to local storage
  static Future<void> addToLibrary(Map<String, dynamic> song) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedStrings = prefs.getStringList(_key) ?? [];
    
    // Create a unique ID (songUrl is usually unique)
    String songId = song['songUrl'] ?? song['songName'];
    
    // Check if already exists to avoid duplicates
    bool exists = savedStrings.any((item) {
      Map<String, dynamic> decoded = jsonDecode(item);
      return (decoded['songUrl'] ?? decoded['songName']) == songId;
    });

    if (!exists) {
      // We encode the Map to a JSON string to save it
      savedStrings.add(jsonEncode(song));
      await prefs.setStringList(_key, savedStrings);
    }
  }

  static Future<void> removeFromLibrary(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedStrings = prefs.getStringList(_key) ?? [];
    
    savedStrings.removeWhere((item) {
      Map<String, dynamic> decoded = jsonDecode(item);
      return (decoded['songUrl'] ?? decoded['songName']) == songId;
    });
    
    await prefs.setStringList(_key, savedStrings);
  }

  static Future<List<Map<String, dynamic>>> getLibrarySongs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedStrings = prefs.getStringList(_key) ?? [];
    
    return savedStrings.map((item) {
      return jsonDecode(item) as Map<String, dynamic>;
    }).toList();
  }

  static Future<bool> isSongInLibrary(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedStrings = prefs.getStringList(_key) ?? [];
    
    return savedStrings.any((item) {
      Map<String, dynamic> decoded = jsonDecode(item);
      return (decoded['songUrl'] ?? decoded['songName']) == songId;
    });
  }
}