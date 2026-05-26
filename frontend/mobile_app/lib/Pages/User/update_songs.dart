// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Custom_Buttons.dart';

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class SongsUpdate extends StatefulWidget {
  const SongsUpdate({super.key});

  @override
  State<SongsUpdate> createState() => _SongsUpdateState();
}

class _SongsUpdateState extends State<SongsUpdate> {
  final TextEditingController _songNameController = TextEditingController();

  // State for songs list
  List<dynamic> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  @override
  void dispose() {
    _songNameController.dispose();
    super.dispose();
  }

  // --- 1. FETCH SONGS (DJANGO) ---
  Future<void> _fetchSongs() async {
    try {
      // URL: /api/tact_music/ (List all songs)
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/tact_music/');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _songs = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        print("Failed to load songs: ${response.statusCode}");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Network Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. UPDATE SONG NAME (DJANGO PATCH) ---
  Future<void> _updateSongName(int songId, String newName) async {
    if (newName.trim().isEmpty) return;

    Api().showLoading(context);

    try {
      // URL: /api/tact_music/ID/
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/tact_music/$songId/',
      );

      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'song_name': newName.trim(), // Django field name (snake_case)
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close Loading

      if (response.statusCode == 200) {
        Navigator.of(context).pop(); // Close Bottom Sheet
        Api().showMessage(
          context,
          'Song updated successfully',
          "Success",
          Theme.of(context).primaryColor,
        );
        _fetchSongs(); // Refresh List
      } else {
        Api().showMessage(
          context,
          'Update failed: ${response.statusCode}',
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      Api().showMessage(
        context,
        'Error updating song: $e',
        "Error",
        Colors.red,
      );
    }
  }

  // --- UI: Edit Sheet ---
  void _showEditSheet(BuildContext context, Map<String, dynamic> songData) {
    final color = Theme.of(context);

    // Map Django keys
    final currentName = songData['song_name'] ?? songData['songName'] ?? '';
    final songId = songData['id']; // Needed for update

    _songNameController.text = currentName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Edit Song Name",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _songNameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Song Name',
                prefixIcon: const Icon(Icons.music_note_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 20),
            Custom_Button(
              onPressed: () =>
                  _updateSongName(songId, _songNameController.text),
              text: 'Save Changes',
              backgroundColor: color.primaryColor,
              foregroundColor: Colors.white,
              minWidth: double.infinity,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: isIOSPlatform
          ? CupertinoNavigationBar(
              backgroundColor: color.primaryColor,
              middle: const Text(
                'Manage Songs',
                style: TextStyle(color: Colors.white),
              ),
            )
          : AppBar(
                  centerTitle: true,
                  title: const Text('Manage Songs'),
                  backgroundColor: color.primaryColor,
                  foregroundColor: Colors.white,
                )
                as PreferredSizeWidget,

      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _songs.isEmpty
          ? Center(child: Text("No songs found."))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index];
                // Map keys
                final songName =
                    song['song_name'] ?? song['songName'] ?? 'Unknown Title';
                final artistName = song['artist'] ?? 'Unknown Artist';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: color.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.music_note,
                        color: color.primaryColor,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      songName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      artistName,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.edit_rounded, size: 20),
                    onTap: () => _showEditSheet(context, song),
                  ),
                );
              },
            ),
    );
  }
}
