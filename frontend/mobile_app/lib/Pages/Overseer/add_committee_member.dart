// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/NeuDesign.dart';

class AddCommitteeMemberTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;

  final String? currentUserName;
  final String? currentUserPortfolio;

  const AddCommitteeMemberTab({
    super.key,
    required this.isLargeScreen,
    this.committeeMemberName,
    this.committeeMemberRole,
    this.faceUrl,
    this.currentUserName,
    this.currentUserPortfolio,
  });

  @override
  State<AddCommitteeMemberTab> createState() => _AddCommitteeMemberTabState();
}

class _AddCommitteeMemberTabState extends State<AddCommitteeMemberTab> {
  // --- CONTROLLERS ---
  final TextEditingController _committeeNameController =
      TextEditingController();
  final TextEditingController _committeeEmailController =
      TextEditingController();

  // --- STATE ---
  String? _selectedPortfolio;

  // New conditional church office state
  String? _selectedTitle; // Brother, Sister, Mother, Father, Other
  String? _selectedSpecificOffice; // Deacon, Priest, Community Elder

  XFile? _committeeFaceImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingCommittee = false;

  // Data State
  List<dynamic> _committeeMembers = [];
  bool _isLoadingMembers = true;

  // Portfolios
  final List<String> _committeeRoles = [
    'Chairperson',
    'Deputy Chairperson',
    'Secretary',
    'Deputy Secretary',
    'Treasurer',
    'Community Elder',
    'Overseer',
    'District Elder',
    'Additional Member',
  ];

  // Honorific Titles
  final List<String> _churchTitles = [
    'Brother',
    'Sister',
    'Mother',
    'Father',
    'Other',
  ];

  // Specific Offices (only for Mother/Father)
  final List<String> _specificOffices = ['Deacon', 'Priest', 'Community Elder'];

  @override
  void initState() {
    super.initState();
    _fetchCommitteeMembers();
  }

  @override
  void dispose() {
    _committeeNameController.dispose();
    _committeeEmailController.dispose();
    super.dispose();
  }

  // --- 1. FETCH COMMITTEE MEMBERS (DJANGO) ---
  Future<void> _fetchCommitteeMembers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoadingMembers = true);

      final String? token = await user.getIdToken();

      final profileUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${user.email}',
      );
      final profileResp = await http.get(
        profileUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (profileResp.statusCode == 200) {
        final List data = json.decode(profileResp.body);
        if (data.isNotEmpty) {
          final overseerId = data[0]['id'];

          final url = Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/?overseer=$overseerId',
          );
          final response = await http.get(
            url,
            headers: {'Authorization': 'Bearer $token'},
          );

          if (response.statusCode == 200) {
            setState(() {
              _committeeMembers = json.decode(response.body);
              _isLoadingMembers = false;
            });
            return;
          }
        }
      }
      setState(() => _isLoadingMembers = false);
    } catch (e) {
      print("Error fetching committee: $e");
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  // --- ACTIONS ---
  Future<void> _pickCommitteeImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _committeeFaceImage = picked);
  }

  // --- 2. ADD MEMBER (DJANGO POST MULTIPART) ---
  Future<void> _addCommitteeMemberTab() async {
    if (_committeeNameController.text.isEmpty || _selectedPortfolio == null) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please fill all fields.",
        Colors.orange,
      );
      return;
    }
    if (_committeeFaceImage == null) {
      Api().showMessage(
        context,
        "Face Required",
        "Upload face for biometric login.",
        Colors.red,
      );
      return;
    }
    if (_selectedTitle == null) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please select a Church Title.",
        Colors.orange,
      );
      return;
    }
    // If Mother/Father, must select a specific office
    if ((_selectedTitle == 'Mother' || _selectedTitle == 'Father') &&
        _selectedSpecificOffice == null) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please select a specific office for $_selectedTitle.",
        Colors.orange,
      );
      return;
    }

    setState(() => _isUploadingCommittee = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final String? token = await user.getIdToken();

      final profileUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${user.email}',
      );
      final profileResp = await http.get(
        profileUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (profileResp.statusCode != 200)
        throw Exception("Failed to get profile");
      final List data = json.decode(profileResp.body);
      if (data.isEmpty) throw Exception("Overseer profile not found");

      final overseerId = data[0]['id'].toString();

      // Construct the final church_office string
      String finalChurchOffice = _selectedTitle!;
      if (_selectedTitle == 'Mother' || _selectedTitle == 'Father') {
        finalChurchOffice = "$_selectedTitle $_selectedSpecificOffice";
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/committee_members/'),
      );

      request.headers.addAll({'Authorization': 'Bearer $token'});

      request.fields['overseer'] = overseerId;
      request.fields['full_name'] = _committeeNameController.text.trim();
      request.fields['email'] = _committeeEmailController.text.trim();
      request.fields['portfolio'] = _selectedPortfolio!;
      request.fields['church_office'] = finalChurchOffice;

      if (kIsWeb) {
        final bytes = await _committeeFaceImage!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'face_image',
            bytes,
            filename: _committeeFaceImage!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'face_image',
            _committeeFaceImage!.path,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (_committeeEmailController.text.trim().isNotEmpty) {
          try {
            await Api().sendEmail(
              _committeeEmailController.text.trim(),
              'Welcome to the Committee',
              '''
Hello ${_committeeNameController.text.trim()},

Welcome to the team! You have successfully been added as a Committee Member.

Your Details:
Portfolio: $_selectedPortfolio
Church Office: $finalChurchOffice

Thank you for your dedication to serving the community. We look forward to working with you.

Best regards,
The Leadership Team
''',
              context,
            );
          } catch (emailError) {
            print("⚠️ Email error: $emailError");
          }
        }

        OverseerAuditLogs.logAction(
          action: "CREATED",
          details:
              "Created committee member ${_committeeNameController.text.trim()}",
          committeeMemberName: widget.committeeMemberName,
          committeeMemberRole: widget.committeeMemberRole,
          universityCommitteeFace: widget.faceUrl,
        );

        _committeeNameController.clear();
        _committeeEmailController.clear();
        setState(() {
          _selectedPortfolio = null;
          _selectedTitle = null;
          _selectedSpecificOffice = null;
          _committeeFaceImage = null;
          _isUploadingCommittee = false;
        });

        _fetchCommitteeMembers();

        if (mounted) {
          Api().showMessage(
            context,
            "Success",
            "Member added successfully.",
            Colors.green,
          );
        }
      } else {
        print("Upload Error: ${response.body}");
        throw Exception("Server rejected upload: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingCommittee = false);
        Api().showMessage(context, "Error", e.toString(), Colors.red);
      }
    }
  }

  // --- 3. DELETE MEMBER (DJANGO DELETE) ---
  Future<void> _deleteCommitteeMember(String memberId, String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final String? token = await user.getIdToken();

      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/$memberId/',
      );

      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 204) {
        _fetchCommitteeMembers();
        if (mounted) {
          Api().showMessage(context, "Deleted", "$name removed.", Colors.grey);
        }
      } else {
        print("Delete failed: ${response.statusCode}");
        throw Exception("Server rejected delete: ${response.statusCode}");
      }
    } catch (e) {
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  // --- 4. PARSE CHURCH OFFICE STRING ---
  // Parses "Mother Deacon" -> title: "Mother", specific: "Deacon"
  // Parses "Brother" -> title: "Brother", specific: null
  (String? title, String? specific) _parseChurchOffice(String? office) {
    if (office == null || office.isEmpty) return (null, null);
    List<String> parts = office.trim().split(' ');
    if (parts.length == 2) {
      if (_churchTitles.contains(parts[0]) &&
          _specificOffices.contains(parts[1])) {
        return (parts[0], parts[1]);
      }
    }
    if (_churchTitles.contains(office)) {
      return (office, null);
    }
    return (null, null);
  }

  // --- 5. EDIT CHURCH OFFICE (NEUMORPHIC DIALOG) ---
  Future<void> _editChurchOffice(String memberId, String? currentOffice) async {
    // Parse the current combined string
    var (initialTitle, initialSpecific) = _parseChurchOffice(currentOffice);

    String? newTitle = initialTitle;
    String? newSpecific = initialSpecific;
    final Color baseColor = Api().neumoBaseColor(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Helper to reset specific when title changes
            void onTitleChanged(String? val) {
              setDialogState(() {
                newTitle = val;
                // If new title is not Mother/Father, clear specific
                if (val != 'Mother' && val != 'Father') {
                  newSpecific = null;
                } else {
                  // If switching from one to the other, preserve specific if valid
                  if (!_specificOffices.contains(newSpecific)) {
                    newSpecific = null;
                  }
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.transparent,
              child: NeumorphicContainer(
                borderRadius: 24,
                padding: EdgeInsets.all(24),
                color: baseColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Update Church Office",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Title Dropdown
                    NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      color: baseColor,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: newTitle,
                          isExpanded: true,
                          hint: Text(
                            "Select Title",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          dropdownColor: baseColor,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(context).primaryColor,
                          ),
                          items: _churchTitles.map((title) {
                            return DropdownMenuItem(
                              value: title,
                              child: Text(title),
                            );
                          }).toList(),
                          onChanged: onTitleChanged,
                        ),
                      ),
                    ),

                    // Specific Office Dropdown (Conditional)
                    if (newTitle == 'Mother' || newTitle == 'Father') ...[
                      SizedBox(height: 12),
                      NeumorphicContainer(
                        isPressed: true,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        color: baseColor,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: newSpecific,
                            isExpanded: true,
                            hint: Text(
                              "Select Specific Office",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            dropdownColor: baseColor,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context).primaryColor,
                            ),
                            items: _specificOffices.map((office) {
                              return DropdownMenuItem(
                                value: office,
                                child: Text(office),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setDialogState(() => newSpecific = val),
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Cancel button
                        GestureDetector(
                          onTap: () => Navigator.pop(dialogContext),
                          child: NeumorphicContainer(
                            isPressed: true,
                            borderRadius: 12,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            color: baseColor,
                            child: Text(
                              "Cancel",
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Save button
                        GestureDetector(
                          onTap: () async {
                            // Ensure we have a valid selection
                            if (newTitle == null) {
                              Api().showMessage(
                                dialogContext,
                                "Error",
                                "Please select a title",
                                Colors.red,
                              );
                              return;
                            }
                            // If Mother/Father, must select specific
                            if ((newTitle == 'Mother' ||
                                    newTitle == 'Father') &&
                                newSpecific == null) {
                              Api().showMessage(
                                dialogContext,
                                "Error",
                                "Please select a specific office",
                                Colors.red,
                              );
                              return;
                            }

                            // Construct the combined string
                            String finalOffice = newTitle!;
                            if (newTitle == 'Mother' || newTitle == 'Father') {
                              finalOffice = "$newTitle $newSpecific";
                            }

                            // Check if actually changed
                            if (finalOffice == currentOffice) {
                              Navigator.pop(dialogContext);
                              return;
                            }

                            Navigator.pop(dialogContext);
                            await _updateChurchOffice(memberId, finalOffice);
                          },
                          child: NeumorphicContainer(
                            borderRadius: 12,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            color: baseColor,
                            child: Text(
                              "Save",
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
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
      },
    );
  }

  // --- 6. UPDATE CHURCH OFFICE (PATCH) ---
  Future<void> _updateChurchOffice(String memberId, String newOffice) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");
      final String? token = await user.getIdToken();
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/$memberId/',
      );

      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'church_office': newOffice}),
      );

      if (response.statusCode == 200) {
        _fetchCommitteeMembers();
        if (mounted) {
          Api().showMessage(
            context,
            "Updated",
            "Church office changed to $newOffice",
            Colors.green,
          );
        }
      } else {
        print("Update failed: ${response.body}");
        throw Exception("Update failed: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        Api().showMessage(context, "Error", e.toString(), Colors.red);
      }
    }
  }

  String _getSecureImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return "";
    if (originalUrl.startsWith('http') && !originalUrl.contains('.enc'))
      return originalUrl;
    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  Widget _styledNeumorphicTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color hintColor,
    required Color primaryColor,
  }) {
    return NeumorphicContainer(
      isPressed: true,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      borderRadius: 12,
      child: TextField(
        controller: controller,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: hintColor),
          icon: Icon(icon, color: hintColor),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = theme.primaryColor;
    final Color hintColor = theme.hintColor;
    final Color baseColor = Api().neumoBaseColor(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (widget.currentUserName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 25.0),
              child: NeumorphicContainer(
                borderRadius: 12,
                padding: EdgeInsets.all(20),
                color: baseColor,
                child: Row(
                  children: [
                    NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 50,
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.badge_outlined,
                        color: primaryColor,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Session:",
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        Text(
                          "${widget.currentUserName}\n${widget.currentUserPortfolio ?? 'Member'}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          Text(
            "Committee Members",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 20),

          // --- ADD MEMBER FORM ---
          NeumorphicContainer(
            padding: EdgeInsets.all(24),
            borderRadius: 16,
            color: baseColor,
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickCommitteeImage,
                      child: NeumorphicContainer(
                        isPressed: true,
                        borderRadius: 12,
                        color: baseColor,
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: _committeeFaceImage == null
                              ? Icon(Icons.add_a_photo, color: hintColor)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: kIsWeb
                                      ? Image.network(
                                          _committeeFaceImage!.path,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          io.File(_committeeFaceImage!.path),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _styledNeumorphicTextField(
                            controller: _committeeNameController,
                            label: "Full Name",
                            icon: Icons.person,
                            hintColor: hintColor,
                            primaryColor: primaryColor,
                          ),
                          SizedBox(height: 10),
                          _styledNeumorphicTextField(
                            controller: _committeeEmailController,
                            label: "Email Address",
                            icon: Icons.email_outlined,
                            hintColor: hintColor,
                            primaryColor: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),

                // Row 1: Portfolio and Church Title
                Row(
                  children: [
                    Expanded(
                      child: NeumorphicContainer(
                        isPressed: true,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPortfolio,
                            hint: Text(
                              "Select Portfolio",
                              style: TextStyle(color: hintColor),
                            ),
                            dropdownColor: baseColor,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: primaryColor,
                            ),
                            items: _committeeRoles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedPortfolio = v),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: NeumorphicContainer(
                        isPressed: true,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTitle,
                            hint: Text(
                              "Title",
                              style: TextStyle(color: hintColor),
                            ),
                            dropdownColor: baseColor,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: primaryColor,
                            ),
                            items: _churchTitles
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedTitle = v;
                                if (v != 'Mother' && v != 'Father') {
                                  _selectedSpecificOffice = null;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Row 2: Specific Office (Conditional)
                if (_selectedTitle == 'Mother' ||
                    _selectedTitle == 'Father') ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NeumorphicContainer(
                          isPressed: true,
                          borderRadius: 12,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSpecificOffice,
                              isExpanded: true,
                              hint: Text(
                                "Select Office (Deacon, Priest, Elder)",
                                style: TextStyle(
                                  color: hintColor,
                                  fontSize: 13,
                                ),
                              ),
                              dropdownColor: baseColor,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: primaryColor,
                              ),
                              items: _specificOffices
                                  .map(
                                    (o) => DropdownMenuItem(
                                      value: o,
                                      child: Text(o),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedSpecificOffice = v),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                SizedBox(height: 15),

                // Add button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: _isUploadingCommittee
                          ? null
                          : _addCommitteeMemberTab,
                      child: NeumorphicContainer(
                        isPressed: false,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 15,
                        ),
                        color: baseColor,
                        child: _isUploadingCommittee
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Add",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 30),

          // --- LIST OF MEMBERS ---
          _isLoadingMembers
              ? Center(child: CupertinoActivityIndicator())
              : _committeeMembers.isEmpty
              ? Center(
                  child: NeumorphicContainer(
                    isPressed: true,
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "No members added yet.",
                      style: TextStyle(color: hintColor),
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 100,
                  ),
                  itemCount: _committeeMembers.length,
                  itemBuilder: (context, index) {
                    var data = _committeeMembers[index];
                    String? faceUrl = data['face_url'];
                    String? secureUrl = (faceUrl != null && faceUrl.isNotEmpty)
                        ? _getSecureImageUrl(faceUrl)
                        : null;
                    String? churchOffice = data['church_office'];

                    return NeumorphicContainer(
                      borderRadius: 12,
                      padding: EdgeInsets.all(12),
                      color: baseColor,
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey[300],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: secureUrl != null
                                  ? Image.network(
                                      secureUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                            Icons.person,
                                            color: hintColor,
                                          ),
                                    )
                                  : Icon(Icons.person, color: hintColor),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data['full_name'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "${data['portfolio'] ?? 'No Portfolio'} • ${churchOffice ?? ''}",
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: Colors.blue.shade300,
                            ),
                            onPressed: () => _editChurchOffice(
                              data['id'].toString(),
                              churchOffice,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade300,
                            ),
                            onPressed: () => _deleteCommitteeMember(
                              data['id'].toString(),
                              data['full_name'] ?? 'Member',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
