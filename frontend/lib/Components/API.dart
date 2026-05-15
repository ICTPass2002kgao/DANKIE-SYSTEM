import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/song.dart';
import 'CustomOutlinedButton.dart';

class Api {
  // --- PLATFORM UTILITIES ---
  bool get isMobileNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isIOSPlatform {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get isAndroidPlatform {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.fuchsia;
  }

  // String BACKEND_BASE_URL_DEBUG = "https://dankie.up.railway.app/api";
  // ---String BACKEND_BASE_URL_DEBUG =  CONFIGURATION ---
  // If you are on Android Emulator use 'http://10.0.2.2:8000/api'
  // If you are on Real Device use your PC IP 'http://192.168.x.x:8000/api'

  String BACKEND_BASE_URL_DEBUG = kIsWeb
      ? 'http://127.0.0.1:8000/api'
      : 'http://127.0.0.1:8000/api';

  String BACKEND_NODE_JS = 'https://api-7gbt42tr6q-uc.a.run.app';
  final _auth = FirebaseAuth.instance;
  String generateVerificationCode() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString();
  }

  Future<bool> sendEmail(
    String email,
    String subject,
    String message,
    BuildContext context,
  ) async {
    try {
      final url = Uri.parse('$BACKEND_NODE_JS/sendCustomEmail');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "to": email,
          "subject": subject,
          "body": message,
          "attachmentUrl": "",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        Navigator.pop(context);

        String errorMessage = "Unknown Server Error";
        try {
          final errorData = jsonDecode(response.body);
          if (errorData != null && errorData['error'] != null) {
            errorMessage = errorData['error'];
          } else {
            errorMessage = response.body;
          }
        } catch (_) {
          errorMessage = response.body;
        }

        print('Server Error: $errorMessage');
        showMessage(context, errorMessage, "Error", Colors.red);
        return false;
      }
    } catch (e) {
      Navigator.pop(context);
      print('Exception: $e');
      showMessage(context, "Connection Failed: $e", "Error", Colors.red);
      return false;
    }
  }

  Future<String?> createSellerSubaccount({
    required String uid,
    required String businessName,
    required String email,
    required String accountNumber,
    required String bankCode,
  }) async {
    try {
      final url = Uri.parse(
        '$BACKEND_BASE_URL_DEBUG/create_seller_subaccount/',
      );

      print("Creating Subaccount for UID: $uid"); // Debug log
      String? token = await _auth.currentUser?.getIdToken();
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "uid": uid, // Correctly sending UID
          "business_name": businessName,
          "bank_code": bankCode,
          "account_number": accountNumber,
          "contact_email": email,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['subaccount_code'];
      } else {
        print('Failed to create subaccount. Status: ${response.statusCode}');
        print('Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print("Network Error in createSellerSubaccount: $e");
      return null;
    }
  }

  // ⭐️ HYBRID SIGN UP: Firebase Auth + Django DB
  Future<Map<String, dynamic>?> signUp(
    String gender,
    String name,
    String surname,
    String email,
    String password,
    String txtAddress,
    String txtContactNumber,
    String selectedMemberUid,
    String role,
    String selectedProvince,
    String selectedDistrictElder,
    String selectedCommunityName,
    BuildContext context, {
    required String bankCode,
    required String accountNumber,
  }) async {
    User? firebaseUser;
    // Define uid outside try block for access in catch/rollback
    String? uid;

    try {
      final color = Theme.of(context);

      // --- 1. CREATE USER IN FIREBASE AUTHENTICATION ---
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      firebaseUser = userCredential.user;

      if (firebaseUser == null) throw Exception("Firebase Auth failed.");

      uid = firebaseUser.uid;
      // CRITICAL: Get the token immediately for authorized backend requests (DELETE/PATCH)
      String idToken = await firebaseUser.getIdToken() ?? "";

      // --- 2. PREPARE DATA FOR DJANGO ---
      // Ensure keys match your Django Serializer (snake_case)
      final url = Uri.parse('$BACKEND_BASE_URL_DEBUG/users/');

      final Map<String, dynamic> requestBody = {
        "uid": uid,
        "name": name,
        "surname": surname,
        "email": email,
        "password": password,
        "address": txtAddress,
        "phone": txtContactNumber,
        "role": role,
        "province": selectedProvince,
        "overseer_uid": selectedMemberUid,
        "district_elder_name": selectedDistrictElder,
        "community_name": selectedCommunityName,
        "gender": gender,
        "profile_url": "",
        "week1": "0.00",
        "week2": "0.00",
        "week3": "0.00",
        "week4": "0.00",
      };

      // Handle Seller Specifics
      if (role == 'Seller') {
        requestBody['seller_paystack_account'] = ''; // Placeholder
        requestBody['account_verified'] = false;
      }

      // --- 3. SEND TO DJANGO ---
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
          // // Uncomment if your POST /users/ requires auth
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        if (role == 'Seller') {
          String? subaccountCode = await createSellerSubaccount(
            uid: uid,
            businessName: '$name $surname\'s Shopping',
            email: email,
            accountNumber: accountNumber,
            bankCode: bankCode,
          );

          if (subaccountCode != null) {
            final updateUrl = Uri.parse('$BACKEND_BASE_URL_DEBUG/users/$uid/');

            await http.patch(
              updateUrl,
              headers: {
                "Content-Type": "application/json",
                "Authorization":
                    "Bearer $idToken", // Authorization required for PATCH
              },
              body: jsonEncode({"seller_paystack_account": subaccountCode}),
            );

            // C. Send Success Emails
            if (context.mounted) {
              sendEmail(
                email,
                "Seller Account Created – Pending Verification",
                """
              <p>Dear $name $surname,</p>
              <p>Welcome to <strong>Dankie Mobile (TACT)</strong>! Your seller account has been created successfully.</p>
              <p>Our team will now review and verify your account details.</p>
              """,
                context,
              );

              sendEmail(
                "kgaogelodeveloper@gmail.com",
                "New Seller Registration – Verification Required",
                """
              <p>Hello Admin,</p>
              <p>A new seller has registered: $name $surname ($email)</p>
              <p>Subaccount Code: $subaccountCode</p>
              """,
                context,
              );
            }
          } else {
            // --- FAILURE: ROLLBACK LOGIC ---
            print('Subaccount creation failed. Rolling back...');

            try {
              await http.delete(
                Uri.parse('$BACKEND_BASE_URL_DEBUG/users/$uid/'),
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer $idToken",
                },
              );
            } catch (djangoError) {
              print("Rollback Error (Django): $djangoError");
            }

            // 2. Delete Firebase User
            try {
              await firebaseUser.delete();
            } catch (fbError) {
              print("Rollback Error (Firebase): $fbError");
            }

            if (context.mounted) {
              Navigator.pop(context);
              Api().showMessage(
                context,
                'Could not verify bank details. Account creation cancelled. Please check your account number and branch code.',
                'Verification Failed',
                Colors.red,
              );
            }

            throw Exception(
              "Could not verify bank details. Rollback complete.",
            );
          }
        } else {
          // --- MEMBER LOGIC ---
          if (context.mounted) Navigator.pop(context);

          if (role.trim() == 'Member' && context.mounted) {
            sendEmail(email, "Account Created Successfully", """
            <p>Dear $name $surname,</p>
            <p>Welcome to <strong>Dankie Mobile(TACT)</strong>! Your account has been created successfully.</p>
            """, context);
          }
        }

        // --- SUCCESS UI ---
        // Only show ads or navigate if the widget is still on screen

        if (context.mounted) {
          AdManager().showRewardedInterstitialAd((ad, reward) {
            print('User earned reward: ${reward.amount} ${reward.type}');
          });

          showMessage(
            context,
            "Account created successfully! Please login.",
            'Proceed to login',
            color.splashColor,
          );

          Navigator.pushNamed(context, '/login');
        }

        return userData;
      } else {
        // --- DJANGO CREATION FAILED (Status 400/500) ---
        // We only need to delete the Firebase user, as Django user wasn't created.
        await firebaseUser.delete();

        String errorMsg = response.body;
        try {
          final errJson = jsonDecode(response.body);
          // Try to extract a specific error message if available
          if (errJson is Map && errJson.containsKey('error')) {
            errorMsg = errJson['error'].toString();
          } else {
            errorMsg = errJson.toString();
          }
        } catch (e) {
          // use raw body if json decode fails
        }

        throw Exception("Registration failed: $errorMsg");
      }
    } catch (e) {
      // --- CATASTROPHIC FAILURE HANDLER ---
      print("Sign Up Error: $e");

      // Attempt to clean up Firebase if it exists and wasn't cleaned up above
      if (firebaseUser != null) {
        try {
          // Refresh user to check if it still exists before deleting
          await firebaseUser.reload();
          await firebaseUser.delete();
        } catch (k) {
          // User might already be deleted or network is down
        }
      }

      if (context.mounted) {
        final color = Theme.of(context);
        showMessage(context, e.toString(), 'Error', color.primaryColorDark);
      }
      return null;
    }
  }

  void showMessage(
    BuildContext context,
    String message,
    String title,
    Color? box_color,
  ) {
    final color = Theme.of(context);

    toastification.dismissAll();

    toastification.show(
      context: context,
      type: ToastificationType.warning,
      autoCloseDuration: const Duration(seconds: 5),
      title: Text(title, style: TextStyle(color: Colors.white)),
      description: RichText(
        text: TextSpan(
          text: message,
          style: TextStyle(color: Colors.white),
        ),
      ),
      alignment: Alignment.bottomCenter,
      animationDuration: const Duration(milliseconds: 500),
      icon: const Icon(Icons.check),
      showIcon: true,
      primaryColor: color.scaffoldBackgroundColor,
      backgroundColor: box_color,
      borderRadius: BorderRadius.circular(30),
      showProgressBar: true,
      progressBarTheme: ProgressIndicatorThemeData(
        color: color.scaffoldBackgroundColor,
      ),
      closeButton: ToastCloseButton(
        showType: CloseButtonShowType.onHover,
        buttonBuilder: (context, onClose) {
          return OutlinedButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20, color: Colors.white),
            label: const Text('Close'),
          );
        },
      ),
      closeOnClick: true,
    );
  }

  void showLogoutMessage(
    BuildContext context,
    String title,
    String message,
    String btnCancel,
    String btnConfirm,
    Function() onPressed,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Center(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        content: Text(message),
        actions: [
          CustomOutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            text: btnCancel,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).primaryColor,
            width: 120,
          ),
          CustomOutlinedButton(
            onPressed: onPressed,
            text: btnConfirm,
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Theme.of(context).scaffoldBackgroundColor,
            width: 120,
          ),
        ],
      ),
    );
  }

  void showLoading(BuildContext context) {
    final color = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: color.primaryColor)),
    );
  }

  void showIosLoading(BuildContext context) {
    final color = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CupertinoActivityIndicator(color: color.primaryColor)),
    );
  }
}

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();

  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal();

  final AudioPlayer audioPlayer = AudioPlayer();

  bool isPlaying = false;

  Future<void> play(String url) async {
    await audioPlayer.play(UrlSource(url));

    isPlaying = true;
  }

  Future<void> pause() async {
    await audioPlayer.pause();

    isPlaying = false;
  }

  Future<void> resume() async {
    await audioPlayer.resume();

    isPlaying = true;
  }

  Future<void> stop() async {
    await audioPlayer.stop();

    isPlaying = false;
  }
}

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();

  factory LocalStorageService() => _instance;

  LocalStorageService._internal();

  static const String _playlistSongsKey = 'playlist_songs';

  // --- Core Methods for Downloaded Songs ---

  /// Downloads the audio file from `song.songUrl` and saves it locally.
  /// Updates the `song` object with the `localFilePath` and saves it to SharedPreferences.
  /// Returns the updated Song object or null if download fails.

  Future<Song?> downloadSong(Song songToDownload) async {
    if (songToDownload.songUrl == null || songToDownload.songUrl.isEmpty) {
      debugPrint('Song URL is null or empty. Cannot download.');

      return null;
    }

    if (songToDownload.id == null || songToDownload.id!.isEmpty) {
      debugPrint(
        'Song ID is null or empty. Cannot download without a unique ID.',
      );

      return null;
    }

    try {
      final response = await http.get(Uri.parse(songToDownload.songUrl));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${songToDownload.id}.mp3';
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        // Create a new Song object with the local file path
        final updatedSong = Song(
          id: songToDownload.id,
          songName: songToDownload.songName,
          artist: songToDownload.artist,
          songUrl: songToDownload.songUrl,
          createdAt: songToDownload.createdAt,
          localFilePath: filePath,
        );

        debugPrint('Song downloaded to: $filePath');
        return updatedSong;
      } else {
        debugPrint(
          'Failed to download song: HTTP Status ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading song: $e');
      return null;
    }
  }

  // --- Existing Methods for Playlist (Unchanged but using new keys) ---

  Future<void> saveToPlaylist(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    List<Song> currentPlaylistSongs = await getPlaylistSongs();

    // Prevent duplicates in playlist if a song is already there (optional)
    if (!currentPlaylistSongs.any((s) => s.id == song.id)) {
      currentPlaylistSongs.add(song);

      final List<String> playlistJsonList = currentPlaylistSongs
          .map((s) => jsonEncode(s.toMap()))
          .toList();

      await prefs.setStringList(_playlistSongsKey, playlistJsonList);

      debugPrint('Song added to playlist: ${song.songName}');
    } else {
      debugPrint('Song "${song.songName}" already exists in playlist.');
    }
  }

  Future<List<Song>> getPlaylistSongs() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String>? playlistJsonList = prefs.getStringList(
      _playlistSongsKey,
    );

    if (playlistJsonList == null) {
      return [];
    }

    return playlistJsonList.map((e) => Song.fromMap(jsonDecode(e))).toList();
  }

  /// Removes a song from the playlist by its ID.
  Future<void> removeFromPlaylist(String songId) async {
    final prefs = await SharedPreferences.getInstance();

    List<Song> currentPlaylistSongs = await getPlaylistSongs();

    final initialLength = currentPlaylistSongs.length;

    currentPlaylistSongs.removeWhere((s) => s.id == songId);

    if (currentPlaylistSongs.length < initialLength) {
      final List<String> updatedPlaylistJsonList = currentPlaylistSongs
          .map((s) => jsonEncode(s.toMap()))
          .toList();

      await prefs.setStringList(_playlistSongsKey, updatedPlaylistJsonList);

      debugPrint('Song with ID $songId removed from playlist.');
    } else {
      debugPrint('Song with ID $songId not found in playlist.');
    }
  }
}
