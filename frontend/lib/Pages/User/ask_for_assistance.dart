// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeumorphicUtils.dart'; // ⭐️ IMPORTED NEUMORPHIC UTILS
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/ViewApplicationsBottomSheet.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

class UniversityApplicationScreen extends StatefulWidget {
  final Map<String, dynamic> universityData;
  final Map<String, dynamic>? selectedCampus;

  const UniversityApplicationScreen({
    Key? key,
    required this.universityData,
    this.selectedCampus,
  }) : super(key: key);

  @override
  State<UniversityApplicationScreen> createState() =>
      _UniversityApplicationScreenState();
}

class _UniversityApplicationScreenState
    extends State<UniversityApplicationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  bool _isLoading = false;
  bool _isProfileLoading = true;
  bool _hasActiveApplication = false;
  Map<String, dynamic>? _existingAppData;

  // Form Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _prevSchoolController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _otherPrimaryProgramController = TextEditingController();
  final _otherSecondProgramController = TextEditingController();

  // Dropdown Values
  String? _primaryProgram;
  String? _secondChoice;
  bool _residence = false;
  bool _funding = false;
  bool _agreedToDisclaimer = false;

  // --- SMART DOCUMENT STATE ---
  String? _savedIdUrl;
  String? _savedResultsUrl;
  String? _savedProofUrl;
  String? _savedOtherUrl;

  dynamic _newIdFile;
  dynamic _newResultsFile;
  dynamic _newProofFile;
  dynamic _newOtherFile;

  String? _djangoDbId;

  @override
  void initState() {
    super.initState();
    _checkUserAndStatus();
  }

  Future<void> _checkUserAndStatus() async {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _emailController.text = _currentUser!.email ?? "";
      await _fetchAndAutofillProfile();
      await _fetchLatestGlobalApplicationDocs(); // ⭐️ NEW: Autofill from previous apps
      await _checkExistingApplications();
    }
  }

  // --- 1. SECURE FETCH PROFILE ---
  Future<void> _fetchAndAutofillProfile() async {
    setState(() => _isProfileLoading = true);
    try {
      String? token = await _currentUser!.getIdToken();
      if (token == null) throw Exception("Token retrieval failed");

      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${_currentUser!.uid}',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final data = results[0];
          setState(() {
            _djangoDbId = data['id'];

            String name = data['name'] ?? '';
            String surname = data['surname'] ?? '';
            _fullNameController.text = '$name $surname'.trim();
            _phoneController.text = data['phone'] ?? '';
            _prevSchoolController.text = data['previous_schools'] ?? '';
            _qualificationController.text = data['highest_qualification'] ?? '';

            if (data['id_passport_url'] != null &&
                data['id_passport_url'].toString().isNotEmpty) {
              _savedIdUrl = data['id_passport_url'];
            }
            if (data['school_results_url'] != null &&
                data['school_results_url'].toString().isNotEmpty) {
              _savedResultsUrl = data['school_results_url'];
            }
            // Add checks for other profile documents if they exist
            if (data['proof_of_registration_url'] != null &&
                data['proof_of_registration_url'].toString().isNotEmpty) {
              _savedProofUrl = data['proof_of_registration_url'];
            }
            if (data['other_qualifications_url'] != null &&
                data['other_qualifications_url'].toString().isNotEmpty) {
              _savedOtherUrl = data['other_qualifications_url'];
            }
          });
        }
      }
    } catch (e) {
      print("Autofill Error: $e");
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  // --- ⭐️ NEW: FETCH LATEST GLOBAL APPLICATION TO REUSE DOCUMENTS ---
  Future<void> _fetchLatestGlobalApplicationDocs() async {
    if (_currentUser == null) return;
    try {
      String? token = await _currentUser!.getIdToken();
      if (token == null) return;

      // Fetch ALL applications for this user regardless of branch
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/applications/?user_uid=${_currentUser!.uid}',
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List apps = json.decode(response.body);
        if (apps.isNotEmpty) {
          // Sort by date to get the most recent application globally
          apps.sort(
            (a, b) =>
                DateTime.parse(
                  a['submission_date'] ?? DateTime.now().toIso8601String(),
                ).compareTo(
                  DateTime.parse(
                    b['submission_date'] ?? DateTime.now().toIso8601String(),
                  ),
                ),
          );
          var latestApp = apps.last;

          if (mounted) {
            setState(() {
              // Only overwrite if the profile didn't already supply these URLs
              _savedIdUrl ??= latestApp['id_passport_url'];
              _savedResultsUrl ??= latestApp['school_results_url'];
              _savedProofUrl ??= latestApp['proof_of_registration_url'];
              _savedOtherUrl ??= latestApp['other_qualifications_url'];

              // Autofill missing text fields from previous app
              if (_prevSchoolController.text.isEmpty) {
                _prevSchoolController.text = latestApp['previous_school'] ?? '';
              }
              if (_qualificationController.text.isEmpty) {
                _qualificationController.text =
                    latestApp['highest_qualification'] ?? '';
              }
            });
          }
        }
      }
    } catch (e) {
      print("Global app autofill error: $e");
    }
  }

  // --- 2. SECURE CHECK APPLICATIONS ---
  Future<void> _checkExistingApplications() async {
    if (_currentUser == null) return;
    try {
      String? token = await _currentUser!.getIdToken();
      if (token == null) return;

      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/applications/?user_uid=${_currentUser!.uid}&branch=${widget.universityData['id']}',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List apps = json.decode(response.body);
        if (apps.isNotEmpty) {
          var latestApp = apps.last;
          DateTime submissionDate = DateTime.parse(
            latestApp['submission_date'],
          );
          if (DateTime.now().isBefore(submissionDate.add(Duration(days: 90)))) {
            if (mounted)
              setState(() {
                _hasActiveApplication = true;
                _existingAppData = latestApp;
              });
          } else {
            if (mounted)
              setState(() {
                _hasActiveApplication = false;
                _existingAppData = null;
              });
          }
        }
      }
    } catch (e) {
      print("Check app error: $e");
    }
  }

  Future<void> _pickFile(Function(dynamic) onSet) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc'],
      withData: true,
    );
    if (result != null) {
      setState(
        () => onSet(
          kIsWeb ? result.files.first : io.File(result.files.single.path!),
        ),
      );
    }
  }

  // --- 3. SECURE PROFILE PATCH ---
  Future<void> _updateUserProfileForFuture() async {
    if (_djangoDbId == null) return;
    try {
      String? token = await _currentUser!.getIdToken();
      if (token == null) return;

      List<String> names = _fullNameController.text.trim().split(' ');
      String name = names.isNotEmpty ? names.first : '';
      String surname = names.length > 1 ? names.sublist(1).join(' ') : '';

      await http.patch(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/$_djangoDbId/'),
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'name': name,
          'surname': surname,
          'phone': _phoneController.text,
          'previous_schools': _prevSchoolController.text,
          'highest_qualification': _qualificationController.text,
        },
      );
    } catch (e) {
      print("Profile update warning: $e");
    }
  }

  // --- 4. SECURE MULTIPART SUBMISSION ---
  Future<void> _submitApplication() async {
    if (!_agreedToDisclaimer) {
      Api().showMessage(
        context,
        'Please acknowledge the disclaimer.',
        'Action Required',
        Colors.orange,
      );
      return;
    }

    bool hasId = _newIdFile != null || _savedIdUrl != null;
    bool hasResults = _newResultsFile != null || _savedResultsUrl != null;

    if (_fullNameController.text.isEmpty || !hasId || !hasResults) {
      Api().showMessage(
        context,
        'Please fill all fields and ensure ID & Results are attached.',
        'Missing Data',
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);

    try {
      String? token = await _currentUser!.getIdToken();
      if (token == null) throw Exception("Session expired");

      await _updateUserProfileForFuture();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/applications/'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      String uniName = widget.universityData['university_name'] ?? 'University';
      String campusName = widget.selectedCampus?['campusName'] ?? 'Main Campus';
      String p1 = _primaryProgram == 'Other'
          ? _otherPrimaryProgramController.text
          : (_primaryProgram ?? 'None');
      String p2 = _secondChoice == 'Other'
          ? _otherSecondProgramController.text
          : (_secondChoice ?? 'None');

      request.fields['branch_id'] = widget.universityData['id'].toString();
      request.fields['user_uid'] = _currentUser!.uid;
      request.fields['uid'] = "APP-${DateTime.now().millisecondsSinceEpoch}";
      request.fields['status'] = 'New';
      request.fields['full_name'] = _fullNameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['phone'] = _phoneController.text;
      request.fields['campus'] = campusName;
      request.fields['highest_qualification'] = _qualificationController.text;
      request.fields['previous_school'] = _prevSchoolController.text;
      request.fields['primary_program'] = p1;
      request.fields['second_choice_program'] = p2;
      request.fields['applying_for_residence'] = _residence.toString();
      request.fields['applying_for_funding'] = _funding.toString();

      // Send the file bytes if new, otherwise just send the existing URL as a string
      // to avoid re-uploading and consuming space.
      if (_newIdFile != null) {
        await _attachFile(request, 'id_passport_url', _newIdFile);
      } else if (_savedIdUrl != null) {
        request.fields['id_passport_url'] = _savedIdUrl!;
      }

      if (_newResultsFile != null) {
        await _attachFile(request, 'school_results_url', _newResultsFile);
      } else if (_savedResultsUrl != null) {
        request.fields['school_results_url'] = _savedResultsUrl!;
      }

      if (_newProofFile != null) {
        await _attachFile(request, 'proof_of_registration_url', _newProofFile);
      } else if (_savedProofUrl != null) {
        request.fields['proof_of_registration_url'] = _savedProofUrl!;
      }

      if (_newOtherFile != null) {
        await _attachFile(request, 'other_qualifications_url', _newOtherFile);
      } else if (_savedOtherUrl != null) {
        request.fields['other_qualifications_url'] = _savedOtherUrl!;
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 201) {
        setState(() => _hasActiveApplication = true);
        _checkExistingApplications();
        AdManager().loadRewardedInterstitialAd();

        String emailSubject = "Application Receipt: $uniName";
        String emailBody =
            """
        <!DOCTYPE html>
        <html>
        <head>
        <style>
          body { font-family: 'Helvetica', 'Arial', sans-serif; background-color: #f4f4f9; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
          .header { background-color: #003366; padding: 30px; text-align: center; color: white; }
          .header h1 { margin: 0; font-size: 24px; letter-spacing: 1px; }
          .content { padding: 30px; color: #333333; }
          .status-badge { background-color: #e8f5e9; color: #2e7d32; padding: 5px 10px; border-radius: 15px; font-size: 12px; font-weight: bold; display: inline-block; margin-bottom: 20px; }
          .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
          .info-table th { text-align: left; padding: 12px; background-color: #f8f9fa; color: #666; font-size: 12px; border-bottom: 2px solid #eee; }
          .info-table td { padding: 12px; border-bottom: 1px solid #eee; font-size: 14px; font-weight: 500; }
          .footer { background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 11px; color: #999; }
        </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Application Submitted</h1>
              <p style="margin: 5px 0 0 0; opacity: 0.8;">$uniName</p>
            </div>
            <div class="content">
              <p>Dear <strong>${_fullNameController.text}</strong>,</p>
              <p>Your application documents have been securely transmitted to the student committee at <strong>$uniName</strong> ($campusName).</p>
              
              <div class="status-badge">STATUS: PENDING REVIEW</div>

              <h3>📋 Application Details</h3>
              <table class="info-table">
                <thead><tr><th>PREFERENCE</th><th>PROGRAM / COURSE</th></tr></thead>
                <tbody>
                  <tr><td><strong>1st Choice</strong></td><td style="color: #003366;">$p1</td></tr>
                  <tr><td><strong>2nd Choice</strong></td><td>$p2</td></tr>
                  <tr><td><strong>Residence</strong></td><td>${_residence ? 'Yes' : 'No'}</td></tr>
                  <tr><td><strong>Funding</strong></td><td>${_funding ? 'Yes' : 'No'}</td></tr>
                </tbody>
              </table>
              <p style="font-size: 13px; color: #666; margin-top: 30px;">
                <strong>Next Steps:</strong> The committee will review your documents. You can check your application status directly within the Dankie app under the "View Status" section.
              </p>
            </div>
            <div class="footer">
              <p>&copy; ${DateTime.now().year} Dankie App. Secure Document Transmission.</p>
              <p>Disclaimer: Dankie facilitates document delivery. Admission decisions rest solely with the university.</p>
            </div>
          </div>
        </body>
        </html>
        """;

        Api().sendEmail(
          _emailController.text,
          emailSubject,
          emailBody,
          context,
        );

        Api().showMessage(
          context,
          'Application Sent Securely!',
          'Success',
          Colors.green,
        );
      } else {
        throw "Auth/Server Error: ${response.statusCode}";
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, e.toString(), 'Error', Colors.red);
    }
  }

  Future<void> _attachFile(
    http.MultipartRequest request,
    String field,
    dynamic file,
  ) async {
    if (kIsWeb) {
      request.files.add(
        http.MultipartFile.fromBytes(field, file.bytes, filename: file.name),
      );
    } else {
      request.files.add(await http.MultipartFile.fromPath(field, file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, theme, neumoBaseColor),
            if (_isProfileLoading)
              LinearProgressIndicator(
                color: theme.primaryColor,
                backgroundColor: neumoBaseColor,
              ),
            Expanded(
              child: _hasActiveApplication
                  ? _buildAlreadyAppliedView(theme, neumoBaseColor)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 900)
                          return _buildDesktopLayout(theme, neumoBaseColor);
                        return _buildMobileLayout(theme, neumoBaseColor);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(ThemeData theme, Color baseColor) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildDisclaimerCard(theme, baseColor),
          SizedBox(height: 20),
          _buildPersonalSection(theme, baseColor),
          SizedBox(height: 20),
          _buildAcademicSection(theme, baseColor),
          SizedBox(height: 20),
          _buildDocumentsSection(theme, baseColor),
          SizedBox(height: 20),
          _buildSubmitButton(theme),
          SizedBox(height: 30),
          AdManager().bannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, Color baseColor) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 100),
      child: Column(
        children: [
          _buildDisclaimerCard(theme, baseColor),
          SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPersonalSection(theme, baseColor),
                    SizedBox(height: 20),
                    _buildAcademicSection(theme, baseColor),
                  ],
                ),
              ),
              SizedBox(width: 30),
              Expanded(
                child: Column(
                  children: [
                    _buildDocumentsSection(theme, baseColor),
                    SizedBox(height: 30),
                    _buildSubmitButton(theme),
                    SizedBox(height: 30),
                    AdManager().bannerAdWidget(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ThemeData theme, Color baseColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: NeumorphicUtils.decoration(
                context: context,
                radius: 12,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: theme.primaryColor,
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "APPLY TO",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  widget.universityData['university_name'] ?? 'University',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard(ThemeData theme, Color baseColor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: NeumorphicUtils.decoration(
        context: context,
        radius: 15,
      ).copyWith(color: Colors.orange.withOpacity(0.05)),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: Colors.orange[800], size: 28),
              SizedBox(width: 10),
              Text(
                "Important Disclaimer",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            "Dankie is a third-party facilitator. This app is NOT responsible for admission decisions. We securely transmit your documents to the ${widget.universityData['university_name']} student committee to apply on your behalf. Documents are automatically cleared 3 months after submission.",
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _agreedToDisclaimer,
                activeColor: Colors.orange,
                onChanged: (v) =>
                    setState(() => _agreedToDisclaimer = v ?? false),
              ),
              Expanded(
                child: Text(
                  "I understand and agree to proceed.",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalSection(ThemeData theme, Color baseColor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: NeumorphicUtils.decoration(context: context, radius: 20),
      child: Column(
        children: [
          _sectionHeader("Personal Details", Icons.person, theme),
          _neumoField(
            controller: _fullNameController,
            placeholder: "Full Name",
            icon: Icons.badge,
            context: context,
            baseColor: baseColor,
          ),
          _neumoField(
            controller: _phoneController,
            placeholder: "Phone Number",
            icon: Icons.phone,
            context: context,
            baseColor: baseColor,
          ),
          _neumoField(
            controller: _emailController,
            placeholder: "Email",
            icon: Icons.email,
            context: context,
            baseColor: baseColor,
            readOnly: true,
          ),
          _neumoSwitch(
            "Applying for Residence?",
            _residence,
            (v) => setState(() => _residence = v),
            baseColor,
            theme,
          ),
          _neumoSwitch(
            "Applying for Funding?",
            _funding,
            (v) => setState(() => _funding = v),
            baseColor,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicSection(ThemeData theme, Color baseColor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: NeumorphicUtils.decoration(context: context, radius: 20),
      child: Column(
        children: [
          _sectionHeader("Academic Choices", Icons.school, theme),
          _neumoField(
            controller: _prevSchoolController,
            placeholder: "Previous School",
            icon: Icons.history_edu,
            context: context,
            baseColor: baseColor,
          ),
          _neumoField(
            controller: _qualificationController,
            placeholder: "Highest Qualification",
            icon: Icons.star,
            context: context,
            baseColor: baseColor,
          ),
          SizedBox(height: 10),
          _programDropdown(
            "Primary Program",
            _primaryProgram,
            (v) => setState(() => _primaryProgram = v),
            baseColor,
          ),
          if (_primaryProgram == 'Other')
            _neumoField(
              controller: _otherPrimaryProgramController,
              placeholder: "Enter Program Name",
              icon: Icons.edit,
              context: context,
              baseColor: baseColor,
            ),
          SizedBox(height: 10),
          _programDropdown(
            "Second Choice",
            _secondChoice,
            (v) => setState(() => _secondChoice = v),
            baseColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(ThemeData theme, Color baseColor) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: NeumorphicUtils.decoration(context: context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Secure Documents", Icons.lock, theme),
          Container(
            margin: const EdgeInsets.only(bottom: 15.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[800],
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Important: Ensure all documents are CERTIFIED COPIES and NOT OLDER THAN 3 MONTHS. Expired or uncertified documents will be rejected.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[900],
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _smartFilePicker(
            "ID / Passport (Certified)",
            _newIdFile,
            _savedIdUrl,
            (f) => _newIdFile = f,
            baseColor,
            theme,
          ),
          _smartFilePicker(
            "School Results (Certified)",
            _newResultsFile,
            _savedResultsUrl,
            (f) => _newResultsFile = f,
            baseColor,
            theme,
          ),
          _smartFilePicker(
            "Proof of Registration",
            _newProofFile,
            _savedProofUrl,
            (f) => _newProofFile = f,
            baseColor,
            theme,
          ),
          _smartFilePicker(
            "Other Certificates",
            _newOtherFile,
            _savedOtherUrl,
            (f) => _newOtherFile = f,
            baseColor,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _smartFilePicker(
    String title,
    dynamic newFile,
    String? savedUrl,
    Function(dynamic) onSet,
    Color baseColor,
    ThemeData theme,
  ) {
    bool hasNew = newFile != null;
    bool hasSaved = savedUrl != null;

    Color stateColor = hasNew
        ? Colors.blue
        : (hasSaved ? Colors.green : theme.hintColor);
    IconData stateIcon = hasNew
        ? Icons.upload_file
        : (hasSaved ? Icons.cloud_done : Icons.add_circle_outline);
    String statusText = hasNew
        ? "New File Selected"
        : (hasSaved ? "Saved Document Found" : "Tap to Upload");

    return GestureDetector(
      onTap: () => _pickFile(onSet),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(15),
        decoration:
            NeumorphicUtils.decoration(
              context: context,
              isPressed: !(hasNew || hasSaved),
              radius: 12,
            ).copyWith(
              color: (hasNew || hasSaved)
                  ? stateColor.withOpacity(0.1)
                  : baseColor,
            ),
        child: Row(
          children: [
            Icon(stateIcon, color: stateColor, size: 28),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasNew || hasSaved)
              Tooltip(
                message: "Tap to replace",
                child: Icon(Icons.edit, color: theme.hintColor, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return GestureDetector(
      onTap: _submitApplication,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 18),
        decoration: NeumorphicUtils.decoration(context: context, radius: 15)
            .copyWith(
              color: _agreedToDisclaimer ? theme.primaryColor : Colors.grey,
            ),
        child: Center(
          child: Text(
            "SUBMIT SECURELY",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyAppliedView(ThemeData theme, Color baseColor) {
    String dateApplied = "Unknown Date";
    if (_existingAppData != null) {
      try {
        DateTime subDate = DateTime.parse(_existingAppData!['submission_date']);
        dateApplied = DateFormat('dd MMM yyyy').format(subDate);
      } catch (e) {}
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: NeumorphicUtils.decoration(
              context: context,
              radius: 100,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 80,
              color: Colors.green,
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Application Active",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Submitted on $dateApplied",
            style: TextStyle(color: theme.hintColor),
          ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(10),
            width: 300,
            child: Text(
              "Your application is currently being processed by the committee. Documents are retained for 3 months.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          SizedBox(height: 30),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (c) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ViewApplicationBottomSheet(
                  userId: _currentUser!.uid,
                  universityUid: widget.universityData['id'].toString(),
                ),
              ),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              decoration: NeumorphicUtils.decoration(
                context: context,
                radius: 12,
              ).copyWith(color: theme.primaryColor),
              child: Text(
                "View Status",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.primaryColor),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _neumoField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    required BuildContext context,
    required Color baseColor,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: NeumorphicUtils.decoration(
          context: context,
          isPressed: true,
          radius: 12,
        ),
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor.withOpacity(0.5),
            ),
            icon: Icon(
              icon,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _neumoSwitch(
    String title,
    bool value,
    Function(bool) onChanged,
    Color baseColor,
    ThemeData theme,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.0),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: NeumorphicUtils.decoration(context: context, radius: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _programDropdown(
    String hint,
    String? value,
    Function(String?) onChanged,
    Color baseColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: NeumorphicUtils.decoration(
        context: context,
        isPressed: true,
        radius: 12,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          items: [
            'BSc Computer Science',
            'BA Psychology',
            'BCom Accounting',
            'BEng Civil Engineering',
            'Other',
            'None',
          ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
