// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print, unused_local_variable

// --- PLATFORM SAFETY IMPORTS ---
import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'dart:io' as io show File;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart'; // REQUIRED to open and view the contract
import 'package:ttact/Components/API.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 600.0;

class AddMusic extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;

  const AddMusic({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<AddMusic> createState() => _AddMusicState();
}

class _AddMusicState extends State<AddMusic> {
  // --- TABS STATE ---
  int _selectedTab = 0; // 0 for Upload, 1 for Manage

  // --- UPLOAD MUSIC STATE ---
  TextEditingController songNameController = TextEditingController();
  TextEditingController artistController = TextEditingController();
  DateTime? _releasedDate;
  dynamic _selectedFile;
  PlatformFile? _webFile;
  String? _audioUrl;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final bool _isWeb = kIsWeb;

  List categories = [
    'Spiritual songs',
    'Apostle choir',
    'Contemporary gospel',
    'Instrumental songs',
    'Evangelical Brothers Songs',
  ];
  String category = '';

  // --- ARTIST CONTRACT STATE ---
  bool _isLoadingArtists = false;
  Map<String, String> _artistDisplayNames = {}; // normalized -> display
  Map<String, bool> _artistContractSigned = {}; // normalized -> true/false
  Map<String, String?> _artistContractUrls = {}; // normalized -> signature url
  Map<String, List<String>> _artistSongIds = {}; // normalized -> [id1, id2]

  @override
  void initState() {
    super.initState();
    _fetchArtistsAndSongs();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    songNameController.dispose();
    artistController.dispose();
    super.dispose();
  }

  // --- ARTIST FETCHING LOGIC ---

  Future<void> _fetchArtistsAndSongs() async {
    setState(() => _isLoadingArtists = true);
    try {
      String token = '';
      if (FirebaseAuth.instance.currentUser != null) {
        token = await FirebaseAuth.instance.currentUser!.getIdToken() ?? '';
      }

      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/songs/');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> songs = json.decode(response.body);
        Map<String, String> displayNames = {};
        Map<String, bool> contractSigned = {};
        Map<String, String?> contractUrls = {};
        Map<String, List<String>> songIds = {};

        for (var song in songs) {
          String rawArtist = song['artist'] ?? 'Unknown';
          String normalized = rawArtist.trim().toUpperCase();
          String songId = song['id'].toString();
          bool isSigned = song['contract_signed'] == true;
          String? signatureUrl = song['signature'];

          displayNames.putIfAbsent(normalized, () => rawArtist.trim());

          if (!songIds.containsKey(normalized)) {
            songIds[normalized] = [];
          }
          songIds[normalized]!.add(songId);

          if (!contractSigned.containsKey(normalized)) {
            contractSigned[normalized] = isSigned;
          } else {
            if (isSigned) contractSigned[normalized] = true;
          }

          if (isSigned && signatureUrl != null && signatureUrl.isNotEmpty) {
            contractUrls[normalized] = signatureUrl;
          }
        }

        setState(() {
          _artistDisplayNames = displayNames;
          _artistContractSigned = contractSigned;
          _artistContractUrls = contractUrls;
          _artistSongIds = songIds;
        });
      }
    } catch (e) {
      print("Error fetching songs/artists: $e");
    } finally {
      setState(() => _isLoadingArtists = false);
    }
  }

  // --- CONTRACT ACTIONS ---

  Future<void> _viewContract(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Api().showMessage(
        context,
        'Could not open the contract document.',
        'Error',
        Colors.red,
      );
    }
  }

  Future<void> pickAndUploadContract(String normalizedArtist) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: _isWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;

      Api().isIOSPlatform
          ? Api().showIosLoading(context)
          : Api().showLoading(context);

      try {
        Uint8List finalBytes;

        if (_isWeb && file.bytes != null) {
          finalBytes = file.bytes!;
        } else if (!_isWeb && file.path != null) {
          finalBytes = await io.File(file.path!).readAsBytes();
        } else {
          throw Exception("Could not read contract file data.");
        }

        final cleanName = normalizedArtist
            .replaceAll(RegExp(r'[^\w\s]+'), '')
            .trim();
        final fileName =
            '${cleanName}_contract_${DateTime.now().millisecondsSinceEpoch}.${file.extension ?? 'pdf'}';
        final ref = FirebaseStorage.instance
            .ref()
            .child('contracts')
            .child(fileName);

        final uploadTask = ref.putData(
          finalBytes,
          SettableMetadata(
            contentType: file.extension == 'pdf'
                ? 'application/pdf'
                : 'image/${file.extension}',
          ),
        );

        final snapshot = await uploadTask;
        final finalContractUrl = await snapshot.ref.getDownloadURL();

        // Update all songs for this artist on Django Backend
        String token = '';
        if (FirebaseAuth.instance.currentUser != null) {
          token = await FirebaseAuth.instance.currentUser!.getIdToken() ?? '';
        }

        List<String> ids = _artistSongIds[normalizedArtist] ?? [];
        for (String id in ids) {
          final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/songs/$id/');
          await http.patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
            body: json.encode({
              "signature": finalContractUrl,
              "contract_signed": true,
            }),
          );
        }

        setState(() {
          _artistContractSigned[normalizedArtist] = true;
          _artistContractUrls[normalizedArtist] = finalContractUrl;
        });

        Api().showMessage(
          context,
          'Contract Uploaded Successfully for ${_artistDisplayNames[normalizedArtist]}!',
          'Success',
          Colors.green,
        );
      } catch (e) {
        Api().showMessage(
          context,
          'Error: ${e.toString()}',
          'Upload Failed',
          Colors.red,
        );
      } finally {
        Navigator.pop(context); // Dismiss loading
      }
    }
  }

  // --- MUSIC UPLOAD LOGIC ---

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
      withData: _isWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;

      setState(() {
        if (_isWeb) {
          _selectedFile = file;
          _webFile = file;
        } else {
          _selectedFile = io.File(file.path!);
        }
        _audioUrl = null;

        if (songNameController.text.isEmpty) {
          songNameController.text = file.name.split('.').first;
        }
      });

      Api().showMessage(
        context,
        'File selected: ${file.name}',
        'Success',
        Theme.of(context).primaryColor,
      );
    } else {
      Api().showMessage(
        context,
        'File selection cancelled.',
        'Info',
        Theme.of(context).hintColor,
      );
    }
  }

  Future<String> _uploadBytesToFirebase(
    Uint8List audioBytes,
    String songName,
  ) async {
    final cleanName = songName.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
    final fileName =
        '${cleanName}_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final ref = FirebaseStorage.instance.ref().child('songs').child(fileName);

    final uploadTask = ref.putData(
      audioBytes,
      SettableMetadata(contentType: 'audio/mpeg'),
    );

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> uploadSong() async {
    if (_selectedFile == null ||
        category.isEmpty ||
        songNameController.text.isEmpty ||
        artistController.text.isEmpty) {
      Api().showMessage(
        context,
        'Please select a file, enter details, and choose a category.',
        'Validation Error',
        Theme.of(context).primaryColorDark,
      );
      return;
    }

    Api().isIOSPlatform
        ? Api().showIosLoading(context)
        : Api().showLoading(context);

    try {
      Uint8List finalAudioBytes;

      if (_isWeb && _webFile?.bytes != null) {
        finalAudioBytes = _webFile!.bytes!;
      } else if (!_isWeb && _selectedFile is io.File) {
        finalAudioBytes = await (_selectedFile as io.File).readAsBytes();
      } else {
        throw Exception("Could not read audio file data.");
      }

      final finalAudioUrl = await _uploadBytesToFirebase(
        finalAudioBytes,
        songNameController.text,
      );

      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/songs/');

      final Map<String, dynamic> requestBody = {
        "song_name": songNameController.text.trim(),
        "artist": artistController.text.trim(),
        "song_url": finalAudioUrl,
        "category": category,
        "contract_signed": false,
      };

      if (_releasedDate != null) {
        requestBody["released"] = _releasedDate!.toIso8601String().split(
          'T',
        )[0];
      }

      String token = '';
      if (FirebaseAuth.instance.currentUser != null) {
        token = await FirebaseAuth.instance.currentUser!.getIdToken() ?? '';
      }

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(
          'Server returned ${response.statusCode}: ${response.body}',
        );
      }

      setState(() {
        _audioUrl = finalAudioUrl;
        _selectedFile = null;
        songNameController.clear();
        artistController.clear();
        _releasedDate = null;
        category = '';
      });

      // Refresh artist list to include new song's artist
      _fetchArtistsAndSongs();

      Api().showMessage(
        context,
        'Song Uploaded Successfully!',
        'Success',
        Colors.green,
      );
    } catch (e) {
      Api().showMessage(
        context,
        'Error: ${e.toString()}',
        'Upload Failed',
        Colors.red,
      );
    } finally {
      Navigator.pop(context);
    }
  }

  Future<void> playAudio() async {
    if (_audioUrl != null) {
      await _audioPlayer.play(
        UrlSource(_audioUrl!),
        mode: PlayerMode.mediaPlayer,
      );
    }
  }

  // --- WIDGET BUILDERS ---

  Widget _buildTabBar(ThemeData color, Color bgColor, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: NeoContainer(
                color: _selectedTab == 0 ? primary : bgColor,
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Upload Song',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: _selectedTab == 0
                          ? bgColor
                          : color.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: NeoContainer(
                color: _selectedTab == 1 ? primary : bgColor,
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Manage Artists',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: _selectedTab == 1
                          ? bgColor
                          : color.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTab(ThemeData color, Color bgColor, Color primary) {
    String? selectedFileName;
    if (_isWeb && _webFile != null) {
      selectedFileName = _webFile!.name;
    } else if (!_isWeb && _selectedFile != null) {
      selectedFileName = (_selectedFile as io.File).path.split('/').last;
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Neumorphic File Picker
        Center(
          child: GestureDetector(
            onTap: pickFile,
            child: NeoContainer(
              color: bgColor,
              height: 220,
              width: 220,
              borderRadius: 110,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedFile == null
                        ? Ionicons.cloud_upload_outline
                        : Ionicons.musical_notes,
                    size: 55,
                    color: primary,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _selectedFile == null ? 'Select Audio' : 'Audio Ready',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primary,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (selectedFileName != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 8.0,
                        left: 20,
                        right: 20,
                      ),
                      child: Text(
                        selectedFileName,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Poppins',
                          color: color.hintColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 40),

        // 2. Input Fields
        NeoContainer(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: CupertinoTextField(
            controller: songNameController,
            placeholder: 'Song Title',
            keyboardType: TextInputType.text,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: color.textTheme.bodyLarge?.color,
            ),
            placeholderStyle: TextStyle(
              fontFamily: 'Poppins',
              color: color.hintColor,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.transparent),
          ),
        ),
        SizedBox(height: 20),

        NeoContainer(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: CupertinoTextField(
            controller: artistController,
            placeholder: 'Artist Name',
            keyboardType: TextInputType.name,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: color.textTheme.bodyLarge?.color,
            ),
            placeholderStyle: TextStyle(
              fontFamily: 'Poppins',
              color: color.hintColor,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.transparent),
          ),
        ),
        SizedBox(height: 20),

        // 3. Category Selection
        NeoContainer(
          color: bgColor,
          child: ExpansionTile(
            collapsedIconColor: primary,
            iconColor: primary,
            shape: const Border(),
            title: Text(
              category.isEmpty ? 'Select Category' : category,
              style: TextStyle(
                color: primary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            children: [
              ...categories.map(
                (cat) => RadioListTile<String>(
                  value: cat,
                  groupValue: category,
                  onChanged: (val) {
                    setState(() => category = val as String);
                  },
                  title: Text(cat, style: TextStyle(fontFamily: 'Poppins')),
                  activeColor: primary,
                  controlAffinity: ListTileControlAffinity.trailing,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        SizedBox(height: 20),

        // 4. Date Picker
        GestureDetector(
          onTap: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: _releasedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: color.copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primary,
                      onPrimary: bgColor,
                      onSurface:
                          color.textTheme.bodyLarge?.color ?? Colors.black,
                    ),
                    textTheme: TextTheme(
                      bodyLarge: TextStyle(fontFamily: 'Poppins'),
                      bodyMedium: TextStyle(fontFamily: 'Poppins'),
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (pickedDate != null) {
              setState(() {
                _releasedDate = pickedDate;
              });
            }
          },
          child: NeoContainer(
            color: bgColor,
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _releasedDate != null
                      ? 'Released: ${_releasedDate!.toLocal().toString().split(' ')[0]}'
                      : 'Select Release Date',
                  style: TextStyle(
                    color: _releasedDate != null
                        ? color.textTheme.bodyLarge?.color
                        : color.hintColor,
                    fontFamily: 'Poppins',
                    fontSize: 15,
                  ),
                ),
                Icon(Ionicons.calendar_outline, color: primary),
              ],
            ),
          ),
        ),
        SizedBox(height: 35),

        // 5. Play Preview Button
        if (_audioUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 25.0),
            child: GestureDetector(
              onTap: playAudio,
              child: NeoContainer(
                color: bgColor,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                borderRadius: 30,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Ionicons.play_circle, color: primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Play Uploaded Audio',
                      style: TextStyle(
                        color: primary,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 6. Upload Button
        GestureDetector(
          onTap: uploadSong,
          child: NeoContainer(
            color: primary,
            padding: EdgeInsets.symmetric(vertical: 18),
            borderRadius: 15,
            child: Center(
              child: Text(
                'Upload Song',
                style: TextStyle(
                  color: bgColor,
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 40),
      ],
    );
  }

  Widget _buildManageTab(ThemeData color, Color bgColor, Color primary) {
    if (_isLoadingArtists) {
      return Center(child: CircularProgressIndicator(color: primary));
    }

    if (_artistDisplayNames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Ionicons.folder_open_outline,
              size: 60,
              color: color.hintColor,
            ),
            SizedBox(height: 16),
            Text(
              'No artists found.\nUpload songs to manage contracts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: color.hintColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _artistDisplayNames.length,
      itemBuilder: (context, index) {
        final normalizedArtist = _artistDisplayNames.keys.elementAt(index);
        final displayName = _artistDisplayNames[normalizedArtist]!;
        final hasContract = _artistContractSigned[normalizedArtist] ?? false;
        final contractUrl = _artistContractUrls[normalizedArtist];
        final totalSongs = _artistSongIds[normalizedArtist]?.length ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: NeoContainer(
            color: bgColor,
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: color.textTheme.bodyLarge?.color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Total Songs: $totalSongs',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: color.hintColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        hasContract ? 'Contract Signed' : 'Pending Contract',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: hasContract ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View / Download Button
                    if (hasContract && contractUrl != null) ...[
                      GestureDetector(
                        onTap: () => _viewContract(contractUrl),
                        child: NeoContainer(
                          color: bgColor,
                          borderRadius: 12,
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Ionicons.eye_outline,
                            color: primary,
                            size: 22,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                    // Upload / Re-Upload Button
                    GestureDetector(
                      onTap: () => pickAndUploadContract(normalizedArtist),
                      child: NeoContainer(
                        color: bgColor,
                        borderRadius: 12,
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          hasContract
                              ? Ionicons.sync_outline
                              : Ionicons.cloud_upload_outline,
                          color: hasContract ? Colors.green : primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final bgColor = color.scaffoldBackgroundColor;
    final primary = color.primaryColor;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildTabBar(color, bgColor, primary),
              Expanded(
                child: _selectedTab == 0
                    ? _buildUploadTab(color, bgColor, primary)
                    : _buildManageTab(color, bgColor, primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NEUMORPHIC HELPER COMPONENT ---

class NeoContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color color;

  const NeoContainer({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 15.0,
    this.padding,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isDark =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    Color lightShadow = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    Color darkShadow = isDark
        ? Colors.black.withOpacity(0.3)
        : Colors.blueGrey.shade100.withOpacity(0.6);

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: darkShadow,
            offset: Offset(6, 6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: lightShadow,
            offset: Offset(-6, -6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}
