// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

import 'package:ttact/Pages/Admin/admin_portal.dart';
import 'package:ttact/Pages/Overseer/overseer_page.dart';
import 'package:ttact/Pages/tactso_pages/tactso_branches__applications.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String entityUid;
  final String role;
  final String branchName; // Added to identify the organization
  final CameraDescription camera;

  // ⭐️ UPDATED: Accepts a LIST of Identity Maps
  // Format: [{'name': '...', 'portfolio': '...', 'faceUrl': '...'}]
  final List<Map<String, String>> identities;

  const FaceVerificationScreen({
    super.key,
    required this.entityUid,
    required this.camera,
    required this.email,
    required this.password,
    required this.role,
    required this.identities,
    required this.branchName,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  late FlutterTts _flutterTts;
  late AudioPlayer _audioPlayer;
  final Api _api = Api();

  bool _isVerifying = false;
  String _processStatus = "Initializing...";
  bool _isCameraInitialized = false;
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _audioPlayer = AudioPlayer();
    _flutterTts = FlutterTts();
    _initializeCamera();
  }

  Future<void> playSound(bool isSuccess) async {
    try {
      String fileName = isSuccess ? 'success.mp3' : 'denied.mp3';
      await _audioPlayer.play(AssetSource(fileName));
    } catch (e) {
      print("Audio Error: $e");
    }
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) {
      var status = await Permission.camera.status;
      if (!status.isGranted) await Permission.camera.request();
    }
    try {
      final cameras = await availableCameras();
      CameraDescription targetCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted)
        setState(() {
          _isCameraInitialized = true;
          _processStatus = "Ready";
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _isCameraInitialized = false;
          _processStatus = "Camera Error";
        });
    }
  }

  // --- ⭐️ UPDATED LOGIC: Checking identities one by one ---
  Future<void> _captureAndVerify() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isVerifying)
      return;

    if (widget.identities.isEmpty) {
      _api.showMessage(
        context,
        'No authorized members found.',
        'Security Error',
        Colors.red,
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _processStatus = 'Scanning...';
    });

    try {
      final XFile capturedFile = await _cameraController!.takePicture();
      if (mounted) await _cameraController?.resumePreview();

      Map<String, String>? matchedIdentity;
      final Uint8List capturedBytes = await capturedFile.readAsBytes();

      // Loop through all committee members/staff assigned to this account
      for (var identity in widget.identities) {
        if (!mounted) break;
        String refUrl = identity['faceUrl'] ?? '';
        if (refUrl.isEmpty) continue;

        setState(() {
          _processStatus = "Verifying ${identity['name']}...";
        });

        final result = await _compareFaces(capturedBytes, refUrl);

        if (result['matched'] == true) {
          matchedIdentity = identity;
          break; // Stop loop immediately once we find the person
        }
      }

      if (matchedIdentity != null) {
        await _finalizeLogin(matchedIdentity);
      } else {
        _handleFailure(reason: "Face not recognized for ${widget.branchName}");
      }
    } catch (e) {
      _cameraController?.resumePreview();
      _handleFailure(reason: "Identification Error");
    }
  }

  Future<Map<String, dynamic>> _compareFaces(
    Uint8List capturedBytes,
    String referenceImageUrl,
  ) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/verify_faces/'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['reference_url'] = referenceImageUrl;
      request.files.add(
        http.MultipartFile.fromBytes(
          'live_image',
          capturedBytes,
          filename: 'face_scan.jpg',
        ),
      );

      var response = await request.send();
      final respString = await response.stream.bytesToString();
      final json = jsonDecode(respString);

      return {'matched': response.statusCode == 200 && json['matched'] == true};
    } catch (e) {
      return {'matched': false};
    }
  }

  Future<void> _finalizeLogin(Map<String, String> identity) async {
    setState(() => _processStatus = "Welcome, ${identity['name']}");
    try {
      await playSound(true);
      if (mounted)
        _api.showMessage(
          context,
          'Identity Verified ✅',
          'Access Granted',
          Colors.green,
        );

      Widget nextScreen;
      // Extract specific person details
      String name = identity['name']!;
      String role = identity['portfolio']!;
      String img = identity['faceUrl']!;

      if (widget.role == 'Admin') {
        nextScreen = AdminPortal(
          fullName: name,
          portfolio: role,
          province: 'HQ',
          faceUrl: img,
        );
      } else if (widget.role == 'Overseer') {
        nextScreen = OverseerPage(
          loggedMemberName: name,
          loggedMemberRole: role,
          faceUrl: img,
        );
      } else {
        nextScreen = TactsoBranchesApplications(
          loggedMemberName: name,
          loggedMemberRole: role,
          faceUrl: img,
        );
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => nextScreen),
        (route) => false,
      );
    } catch (e) {
      _handleFailure(reason: "Session Error");
    }
  }

  void _handleFailure({String reason = "Access Denied"}) async {
    if (!mounted) return;
    await playSound(false);
    _cameraController?.resumePreview();
    setState(() {
      _isVerifying = false;
      _processStatus = "Ready";
    });

    // Kick out of temporary firebase session for security
    await FirebaseAuth.instance.signOut();
    _api.showMessage(context, reason, 'Denied', Colors.red);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scannerController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // --- ⭐️ NEUMORPHIC UI (UNCHANGED VISUALS) ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final Color hintColor = theme.hintColor;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: NeumorphicContainer(
              color: neumoBaseColor,
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
            ),
          ),
        ),
        title: Text(
          'Verification',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                _buildDetailsPanel(neumoBaseColor, textColor, hintColor),
                const SizedBox(height: 40),
                if (_isVerifying)
                  _buildProcessingPanel(
                    neumoBaseColor,
                    textColor,
                    theme.primaryColor,
                  )
                else
                  _buildLiveCamPanel(
                    neumoBaseColor,
                    textColor,
                    theme.primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(Color baseColor, Color textColor, Color hintColor) {
    return NeumorphicContainer(
      color: baseColor,
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hintColor.withOpacity(0.1)),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: Icon(Icons.person, color: hintColor)),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.branchName,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Identifying Authorized Personnel",
                  style: GoogleFonts.poppins(color: hintColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCamPanel(
    Color baseColor,
    Color textColor,
    Color primaryColor,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      padding: const EdgeInsets.all(24),
      borderRadius: 20,
      child: Column(
        children: [
          _sectionTitle('Live Scan', primaryColor, textColor),
          const SizedBox(height: 10),
          Text(
            _isCameraInitialized
                ? 'Align your face within the frame.'
                : 'Initializing...',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 40),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [baseColor.withOpacity(0.5), baseColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 20,
                      offset: const Offset(10, 10),
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Container(
                  width: 220,
                  height: 300,
                  color: Colors.black,
                  child: _isCameraInitialized
                      ? AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        )
                      : Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        ),
                ),
              ),
              if (_isCameraInitialized)
                Positioned.fill(
                  child: ClipOval(
                    child: AnimatedBuilder(
                      animation: _scannerController,
                      builder: (context, child) => Align(
                        alignment: Alignment(
                          0,
                          _scannerController.value * 2 - 1,
                        ),
                        child: Container(
                          height: 4,
                          width: 220,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.green,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.green,
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _captureAndVerify,
            child: NeumorphicContainer(
              color: primaryColor,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Start Face Match',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingPanel(
    Color baseColor,
    Color textColor,
    Color primaryColor,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      borderRadius: 20,
      child: Center(
        child: Column(
          children: [
            Icon(Icons.fingerprint_outlined, size: 60, color: primaryColor),
            const SizedBox(height: 40),
            Text(
              "Processing...",
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _processStatus,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                backgroundColor: baseColor,
                color: Colors.green,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color primaryColor, Color textColor) {
    return Row(
      children: [
        Container(
          height: 25,
          width: 4,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
