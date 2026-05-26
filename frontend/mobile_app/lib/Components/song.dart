import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String? id; // Added: A unique ID for the song
  final String songName;
  final String songUrl;
  final String artist;
  final Timestamp? createdAt; // Changed to Timestamp directly for Firestore compatibility
  final String? localFilePath; // Added: Path to the locally downloaded file

  Song({
    this.id, // Made optional for cases where you might create a song locally before it has a Firestore ID
    required this.songName,
    required this.songUrl,
    required this.artist,
    this.createdAt,
    this.localFilePath, // Made optional
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] as String?, // Retrieve the ID
      songName: map['songName'] ?? '',
      songUrl: map['songUrl'] ?? '',
      artist: map['artist'] ?? '',
      createdAt: map['createdAt'] is Timestamp // Check if it's already a Timestamp
          ? map['createdAt'] as Timestamp
          : (map['createdAt'] != null // Handle if it's a String (e.g., from SharedPreferences)
              ? Timestamp.fromDate(DateTime.parse(map['createdAt']))
              : null),
      localFilePath: map['localFilePath'] as String?, // Retrieve the local file path
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Include the ID in the map
      'songName': songName,
      'songUrl': songUrl,
      'artist': artist,
      // For Firestore, directly use Timestamp. For SharedPreferences, you might convert to ISO string.
      // The `fromMap` handles both scenarios.
      'createdAt': createdAt,
      'localFilePath': localFilePath, // Include the local file path in the map
    };
  }

  // Optional: Add a copyWith method for immutability and easy updates
  Song copyWith({
    String? id,
    String? songName,
    String? songUrl,
    String? artist,
    Timestamp? createdAt,
    String? localFilePath,
  }) {
    return Song(
      id: id ?? this.id,
      songName: songName ?? this.songName,
      songUrl: songUrl ?? this.songUrl,
      artist: artist ?? this.artist,
      createdAt: createdAt ?? this.createdAt,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}