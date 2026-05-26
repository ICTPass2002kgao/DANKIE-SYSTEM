// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/API.dart';

// ⭐️ IMPORT YOUR DESIGN COMPONENT
import '../../Components/NeuDesign.dart';

class StaffMembers extends StatefulWidget {
  final String? faceUrl;
  final String? name;
  final String? portfolio;
  final String? province;
  const StaffMembers({
    super.key,
    this.faceUrl,
    this.name,
    this.portfolio,
    this.province,
  });

  @override
  State<StaffMembers> createState() => _StaffMembersState();
}

class _StaffMembersState extends State<StaffMembers> {
  // --- CONTROLLERS ---
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otherPortfolioController =
      TextEditingController();

  // --- STATE ---
  XFile? _faceImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final bool _isWeb = kIsWeb;

  List<dynamic> _staffList = [];
  bool _isFetching = true;

  // --- SELECTION VARIABLES ---
  String? _selectedPortfolio;
  String? _selectedProvince;

  // --- DATA LISTS ---
  final List<String> _provinces = [
    "Eastern Cape",
    "Free State",
    "Gauteng",
    "KwaZulu-Natal",
    "Limpopo",
    "Mpumalanga",
    "Northern Cape",
    "North West",
    "Western Cape",
  ];

  final List<String> _portfolios = [
    "Media Officer",
    "HOD Of Education",
    "UpperHouse Chairperson",
    "Apostle Board",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    _fetchStaffMembers();
  }

  @override
  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    emailController.dispose();
    otherPortfolioController.dispose();
    super.dispose();
  }

  // --- NATIVE FEEDBACK HELPER (Guarantees you see the error) ---
  void _showFeedback(String title, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "$title: $message",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // --- LOGIC: FETCH DATA (DJANGO) ---
  Future<void> _fetchStaffMembers() async {
    setState(() => _isFetching = true);
    try {
      String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/staff/');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _staffList = json.decode(response.body);
          _isFetching = false;
        });
      } else {
        print("❌ Error fetching staff: ${response.body}");
        setState(() => _isFetching = false);
      }
    } catch (e) {
      print("❌ Network Error: $e");
      setState(() => _isFetching = false);
    }
  }

  // --- LOGIC: IMAGE PICKER ---
  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _faceImageFile = picked;
        });
      }
    } catch (e) {
      print("Image Picker Error: $e");
    }
  }

  // --- LOGIC: ADD STAFF (DJANGO MULTIPART) ---
  Future<void> _addStaffMember() async {
    print("➡️ [DEBUG] Save button was pressed.");

    String finalPortfolio = _selectedPortfolio == "Other"
        ? otherPortfolioController.text.trim()
        : (_selectedPortfolio ?? "");

    // 1. Validation Check
    if (nameController.text.isEmpty ||
        surnameController.text.isEmpty ||
        emailController.text.isEmpty ||
        _selectedPortfolio == null ||
        _selectedProvince == null ||
        finalPortfolio.isEmpty) {
      print("⚠️ [DEBUG] Validation failed: Missing text fields.");
      _showFeedback('Missing Info', 'Please fill all fields.', Colors.orange);
      return;
    }

    if (_faceImageFile == null) {
      print("⚠️ [DEBUG] Validation failed: No face image uploaded.");
      _showFeedback(
        'Face Required',
        'Upload face for biometric login.',
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("⏳ [DEBUG] Preparing to send request to backend...");
      var uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/staff/');
      var request = http.MultipartRequest('POST', uri);

      request.fields['name'] = nameController.text.trim();
      request.fields['surname'] = surnameController.text.trim();
      request.fields['full_name'] =
          "${nameController.text.trim()} ${surnameController.text.trim()}";
      request.fields['portfolio'] = finalPortfolio;
      request.fields['province'] = _selectedProvince!;
      request.fields['email'] = "admin@dankie.co.za";
      request.fields['role'] = 'Admin';
      request.fields['personal_email'] = emailController.text.trim();
      request.fields['uid'] = FirebaseAuth.instance.currentUser?.uid ?? '';

      String token =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      request.headers['Authorization'] = 'Bearer $token';

      if (_isWeb) {
        var bytes = await _faceImageFile!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'face_image',
            bytes,
            filename: _faceImageFile!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('face_image', _faceImageFile!.path),
        );
      }

      print("🚀 [DEBUG] Firing request to Django...");
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("📩 [DEBUG] Response Status Code: ${response.statusCode}");
      print("📩 [DEBUG] Response Body: ${response.body}");

      if (response.statusCode == 201) {
        print("✅ [DEBUG] Successfully saved to database.");

        // ISOLATED EMAIL BLOCK: Errors here won't crash the save process
        try {
          print("⏳ [DEBUG] Attempting to send welcome email...");
          await Api().sendEmail(
            emailController.text.trim(),
            'Welcome to the Admin Team',
            """
Hello ${nameController.text.trim()} ${surnameController.text.trim()},

Welcome to the team! You have successfully been added as an Admin Staff Member.

Your Role Details:
Portfolio: $finalPortfolio
Province: ${_selectedProvince!}

Thank you for your dedication to serving the community. We look forward to working with you.

Best regards,
The Admin Team
            """,
            context,
          );
          print("✅ [DEBUG] Email sent successfully.");
        } catch (emailError) {
          print(
            "⚠️ [DEBUG] Email failed to send, but user was created. Error: $emailError",
          );
        }

        if (mounted) {
          _showFeedback(
            'Success',
            'Staff Member Added Successfully',
            Colors.green,
          );
          _clearForm();
          _fetchStaffMembers();
        }
      } else {
        // Handle Django Errors safely
        String errMsg = "Failed to add staff: ${response.statusCode}";
        try {
          var errorJson = json.decode(response.body);
          errMsg = errorJson
              .toString(); // Shows exactly what Django complained about
        } catch (_) {}

        if (mounted) {
          _showFeedback('Server Error', errMsg, Colors.red);
        }
      }
    } catch (e) {
      print("🔥 [DEBUG] Fatal Catch Block Error: $e");
      if (mounted) {
        _showFeedback('App Error', e.toString(), Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    nameController.clear();
    surnameController.clear();
    emailController.clear();
    otherPortfolioController.clear();
    setState(() {
      _selectedPortfolio = null;
      _selectedProvince = null;
      _faceImageFile = null;
    });
  }

  // --- LOGIC: DELETE STAFF (DJANGO) ---
  Future<void> _deleteStaff(String id) async {
    try {
      Api().isIOSPlatform
          ? Api().showIosLoading(context)
          : Api().showLoading(context);

      if (_staffList.length <= 1) {
        Navigator.pop(context); // Pop loading
        _showFeedback(
          "Action Denied",
          "At least one staff member must remain.",
          Colors.orange,
        );
        return;
      }

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/staff/$id/',
      ); // FIXED URL FORMAT
      final response = await http.delete(
        uri,
        headers: {
          'Authorization':
              'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
        },
      );

      Navigator.pop(context); // Pop loading

      if (response.statusCode == 204) {
        _showFeedback("Deleted", "Staff member removed.", Colors.grey);
        _fetchStaffMembers(); // Refresh
      } else {
        _showFeedback(
          "Error",
          "Failed to delete: ${response.body}",
          Colors.red,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _showFeedback("Error", e.toString(), Colors.red);
    }
  }

  // --- ⭐️ NEUMORPHIC WIDGET HELPERS ---

  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color baseColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        NeumorphicContainer(
          isPressed: true,
          color: baseColor,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Enter $label",
              prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeumorphicDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    required Color baseColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        NeumorphicContainer(
          isPressed: true,
          color: baseColor,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(icon, color: Theme.of(context).primaryColor, size: 24),
                  SizedBox(width: 12),
                  Text("Select $label"),
                ],
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).primaryColor,
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      if (value != null) ...[
                        Icon(
                          icon,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                      ],
                      Text(item),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              dropdownColor: baseColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerBox(Color baseColor) {
    return GestureDetector(
      onTap: _pickImage,
      child: NeumorphicContainer(
        color: baseColor,
        borderRadius: 15,
        padding: EdgeInsets.all(4),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _faceImageFile == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      color: Theme.of(context).primaryColor,
                      size: 30,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Add Photo",
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isWeb
                      ? Image.network(_faceImageFile!.path, fit: BoxFit.cover)
                      : Image.file(
                          io.File(_faceImageFile!.path),
                          fit: BoxFit.cover,
                        ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 800;
          final double gridCardWidth = isMobile ? double.infinity : 350;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    Text(
                      "Add New Staff Member",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 20),

                    // --- INPUT FORM ---
                    NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 20,
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          if (isMobile) ...[
                            // MOBILE LAYOUT
                            Center(child: _buildImagePickerBox(neumoBaseColor)),
                            SizedBox(height: 20),
                            _buildNeumorphicTextField(
                              controller: nameController,
                              label: "Name",
                              icon: Icons.person,
                              baseColor: neumoBaseColor,
                            ),
                            SizedBox(height: 15),
                            _buildNeumorphicTextField(
                              controller: surnameController,
                              label: "Surname",
                              icon: Icons.person_outline,
                              baseColor: neumoBaseColor,
                            ),
                            SizedBox(height: 15),
                            _buildNeumorphicTextField(
                              controller: emailController,
                              label: "Email Address",
                              icon: Icons.email,
                              baseColor: neumoBaseColor,
                            ),
                            SizedBox(height: 15),
                            _buildNeumorphicDropdown(
                              value: _selectedPortfolio,
                              label: "Portfolio",
                              icon: Icons.work,
                              items: _portfolios,
                              onChanged: (val) =>
                                  setState(() => _selectedPortfolio = val),
                              baseColor: neumoBaseColor,
                            ),
                            if (_selectedPortfolio == "Other") ...[
                              SizedBox(height: 15),
                              _buildNeumorphicTextField(
                                controller: otherPortfolioController,
                                label: "Specify Portfolio Name",
                                icon: Icons.edit_note,
                                baseColor: neumoBaseColor,
                              ),
                            ],
                            SizedBox(height: 15),
                            _buildNeumorphicDropdown(
                              value: _selectedProvince,
                              label: "Province",
                              icon: Icons.location_on,
                              items: _provinces,
                              onChanged: (val) =>
                                  setState(() => _selectedProvince = val),
                              baseColor: neumoBaseColor,
                            ),
                          ] else ...[
                            // DESKTOP LAYOUT
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildImagePickerBox(neumoBaseColor),
                                SizedBox(width: 30),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildNeumorphicTextField(
                                              controller: nameController,
                                              label: "Name",
                                              icon: Icons.person,
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                          SizedBox(width: 20),
                                          Expanded(
                                            child: _buildNeumorphicTextField(
                                              controller: surnameController,
                                              label: "Surname",
                                              icon: Icons.person_outline,
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildNeumorphicTextField(
                                              controller: emailController,
                                              label: "Email Address",
                                              icon: Icons.email,
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildNeumorphicDropdown(
                                              value: _selectedPortfolio,
                                              label: "Portfolio",
                                              icon: Icons.work,
                                              items: _portfolios,
                                              onChanged: (val) => setState(
                                                () => _selectedPortfolio = val,
                                              ),
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                          SizedBox(width: 20),
                                          Expanded(
                                            child: _buildNeumorphicDropdown(
                                              value: _selectedProvince,
                                              label: "Province",
                                              icon: Icons.location_on,
                                              items: _provinces,
                                              onChanged: (val) => setState(
                                                () => _selectedProvince = val,
                                              ),
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_selectedPortfolio == "Other") ...[
                                        SizedBox(height: 20),
                                        _buildNeumorphicTextField(
                                          controller: otherPortfolioController,
                                          label: "Specify Portfolio Name",
                                          icon: Icons.edit_note,
                                          baseColor: neumoBaseColor,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 30),

                          GestureDetector(
                            behavior: HitTestBehavior
                                .opaque, // Ensures the tap registers anywhere on the container
                            onTap: _isLoading ? null : _addStaffMember,
                            child: NeumorphicContainer(
                              color: theme.primaryColor,
                              borderRadius: 12,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "Save Staff Member",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),

                    // --- STAFF LIST HEADER ---
                    Text(
                      "Existing Staff Members",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 15),

                    // --- GRID (API DATA) ---
                    _isFetching
                        ? Center(child: CupertinoActivityIndicator())
                        : _staffList.isEmpty
                        ? Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_off,
                                  size: 40,
                                  color: theme.hintColor.withOpacity(0.5),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "No staff members found.",
                                  style: TextStyle(color: theme.hintColor),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: gridCardWidth,
                                  mainAxisExtent: 120,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                ),
                            itemCount: _staffList.length,
                            itemBuilder: (context, index) {
                              final staff = _staffList[index];
                              final String id = staff['id'];

                              return NeumorphicContainer(
                                color: neumoBaseColor,
                                borderRadius: 15,
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.black12,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child:
                                            (staff['face_url'] != null &&
                                                staff['face_url']
                                                    .toString()
                                                    .isNotEmpty)
                                            ? Image.network(
                                                '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(staff['face_url'])}',
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.person,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                    SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "${staff['name']} ${staff['surname']}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.primaryColor,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            staff['portfolio'] ??
                                                'No Portfolio',
                                            style: TextStyle(
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            staff['province'] ?? 'Unknown',
                                            style: TextStyle(
                                              color: theme.hintColor,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _deleteStaff(id),
                                      child: NeumorphicContainer(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: 50,
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
