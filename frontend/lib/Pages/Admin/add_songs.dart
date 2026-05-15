// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print, unused_local_variable

// --- PLATFORM SAFETY IMPORTS ---
import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'dart:io' as io show File;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // HTTP Package
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 600.0;

// Helper list for video formats
const List<String> videoExtensions = ['mp4', 'mov', 'avi', 'wmv'];

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
  TextEditingController songNameController = TextEditingController();
  TextEditingController artistController = TextEditingController();
  DateTime? _releasedDate;

  // Holds the selected file (either PlatformFile for web or io.File for mobile)
  dynamic _selectedFile;
  PlatformFile? _webFile; // Helper for Web bytes

  String? _audioUrl; // Final URL for playback if needed
  final AudioPlayer _audioPlayer = AudioPlayer();
  final bool _isWeb = kIsWeb;

  List categories = [
    'Slow Jam',
    'Apostle choir',
    'choreography',
    'Instrumental songs',
    'Evangelical Brothers Songs',
  ];
  String category = '';

  @override
  void dispose() {
    _audioPlayer.dispose();
    songNameController.dispose();
    artistController.dispose();
    super.dispose();
  }

  // --- FILE PICKER LOGIC ---
  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [...videoExtensions, 'mp3', 'wav', 'm4a'],
      withData: _isWeb, // Important: Load bytes for Web
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
        // Auto-fill name if empty
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

  // --- UPLOAD LOGIC (DJANGO API) ---
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

    Api().showLoading(context);

    try {
      // 1. Prepare Endpoint
      var uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/songs/');
      var request = http.MultipartRequest('POST', uri);

      // 2. Add Text Fields (Snake Case for Django)
      request.fields['title'] = songNameController.text.trim();
      request.fields['artist'] = artistController.text.trim();
      request.fields['category'] = category;

      if (_releasedDate != null) {
        // Format: YYYY-MM-DD
        request.fields['release_date'] = _releasedDate!.toIso8601String().split(
          'T',
        )[0];
      }

      // 3. Add File
      if (_isWeb) {
        if (_webFile?.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'audio_file', // Key expected by Django Serializer
              _webFile!.bytes!,
              filename: _webFile!.name,
            ),
          );
        } else {
          throw Exception("Web file data is missing/corrupted.");
        }
      } else {
        // Native Mobile
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio_file', // Key expected by Django Serializer
            (_selectedFile as io.File).path,
          ),
        );
      }

      // 4. Send Request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); // Dismiss loading

      // 5. Handle Response
      if (response.statusCode == 201 || response.statusCode == 200) {
        var responseData = json.decode(response.body);

        setState(() {
          // Assuming Django returns the full object with the new 'audio_file' URL
          _audioUrl = responseData['audio_file'];
          _selectedFile = null;
          songNameController.clear();
          artistController.clear();
          _releasedDate = null;
          category = '';
        });

        Api().showMessage(
          context,
          'Song Uploaded Successfully!',
          'Success',
          Colors.green,
        );
      } else {
        print("Server Error: ${response.body}");
        Api().showMessage(
          context,
          'Upload Failed: ${response.statusCode}\n${response.body}',
          'Server Error',
          Colors.red,
        );
      }
    } catch (e) {
      Navigator.pop(context); // Dismiss loading if error
      Api().showMessage(
        context,
        'Error: ${e.toString()}',
        'Connection Error',
        Colors.red,
      );
    }
  }

  // --- AUDIO PLAYBACK ---
  Future<void> playAudio() async {
    if (_audioUrl != null) {
      await _audioPlayer.play(
        UrlSource(_audioUrl!),
        mode: PlayerMode.mediaPlayer,
      );
    }
  }

  // --- WIDGET BUILDER ---
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    // Determine file name for display
    String? selectedFileName;
    if (_isWeb && _webFile != null) {
      selectedFileName = _webFile!.name;
    } else if (!_isWeb && _selectedFile != null) {
      selectedFileName = (_selectedFile as io.File).path.split('/').last;
    }

    final isVideoFile =
        selectedFileName != null &&
        videoExtensions.contains(
          selectedFileName.split('.').last.toLowerCase(),
        );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: ListView(
            children: [
              // 1. File Picker Card
              Center(
                child: Card(
                  elevation: 10,
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: pickFile,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: SweepGradient(
                          transform: const GradientRotation(5),
                          center: Alignment.center,
                          startAngle: 0.1,
                          endAngle: 10,
                          colors: [
                            color.primaryColor.withOpacity(0.9),
                            color.hintColor,
                            color.primaryColor,
                            color.primaryColorDark,
                          ],
                        ),
                      ),
                      height: 200,
                      width: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedFile == null
                                ? Ionicons.add_sharp
                                : isVideoFile
                                ? Ionicons.videocam_outline
                                : Ionicons.musical_notes_outline,
                            size: 50,
                            color: color.scaffoldBackgroundColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFile == null
                                ? 'Tap to Select Audio'
                                : (isVideoFile
                                      ? 'Video Selected'
                                      : 'Audio Selected'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color.scaffoldBackgroundColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (selectedFileName != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Text(
                                selectedFileName,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color.scaffoldBackgroundColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),

              // 2. Input Fields
              CupertinoTextField(
                controller: songNameController,
                placeholder: 'Song Title',
                keyboardType: TextInputType.text,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    width: 1,
                    color: color.primaryColor.withOpacity(0.5),
                  ),
                  color: color.scaffoldBackgroundColor,
                ),
              ),
              SizedBox(height: 10),
              CupertinoTextField(
                controller: artistController,
                placeholder: 'Artist Name',
                keyboardType: TextInputType.name,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    width: 1,
                    color: color.primaryColor.withOpacity(0.5),
                  ),
                  color: color.scaffoldBackgroundColor,
                ),
              ),
              SizedBox(height: 10),

              // 3. Category Selection
              ExpansionTile(
                title: Text(
                  category.isEmpty ? 'Select Category' : category,
                  style: TextStyle(
                    color: color.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: [
                  ...categories
                      .map(
                        (cat) => RadioListTile<String>(
                          value: cat,
                          groupValue: category,
                          onChanged: (val) {
                            setState(() => category = val as String);
                          },
                          title: Text(cat),
                          activeColor: color.primaryColor,
                        ),
                      )
                      .toList(),
                ],
              ),

              SizedBox(height: 10),

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
                            primary: color.primaryColor,
                            onPrimary: color.scaffoldBackgroundColor,
                            onSurface:
                                color.textTheme.bodyLarge?.color ??
                                Colors.black,
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
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      width: 1,
                      color: color.primaryColor.withOpacity(0.5),
                    ),
                    color: color.scaffoldBackgroundColor,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _releasedDate != null
                            ? 'Released: ${_releasedDate!.toLocal().toString().split(' ')[0]}'
                            : 'Select Release Date',
                        style: TextStyle(
                          color: color.primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      Icon(Icons.calendar_today, color: color.primaryColor),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // 5. Play Preview Button (Visible after successful upload)
              if (_audioUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: playAudio,
                      icon: const Icon(Ionicons.play_circle_outline),
                      label: Text('Play Uploaded Audio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.splashColor,
                        foregroundColor: color.scaffoldBackgroundColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),

              // 6. Upload Button
              CustomOutlinedButton(
                onPressed: uploadSong,
                text: 'Upload Song',
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                width: double.infinity,
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
