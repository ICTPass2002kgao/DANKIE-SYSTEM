// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert'; // Added for JSON
import 'dart:io' as io;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http; // Added for API
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
  final TextEditingController otherPortfolioController =
      TextEditingController();

  // --- STATE ---
  XFile? _faceImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final bool _isWeb = kIsWeb;

  // Data State
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
    otherPortfolioController.dispose();
    super.dispose();
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
        print("Error fetching staff: ${response.body}");
        setState(() => _isFetching = false);
      }
    } catch (e) {
      print("Network Error: $e");
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
    String finalPortfolio = _selectedPortfolio == "Other"
        ? otherPortfolioController.text.trim()
        : (_selectedPortfolio ?? "");

    if (nameController.text.isEmpty ||
        surnameController.text.isEmpty ||
        _selectedPortfolio == null ||
        _selectedProvince == null ||
        finalPortfolio.isEmpty) {
      Api().showMessage(
        context,
        'Missing Info',
        'Please fill all fields.',
        Colors.orange,
      );
      return;
    }

    if (_faceImageFile == null) {
      Api().showMessage(
        context,
        'Face Required',
        'Upload face for biometric login.',
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/staff/');
      var request = http.MultipartRequest('POST', uri);

      // 1. Text Fields (Snake Case for Django)
      request.fields['name'] = nameController.text.trim();
      request.fields['surname'] = surnameController.text.trim();
      request.fields['full_name'] =
          "${nameController.text.trim()} ${surnameController.text.trim()}";
      request.fields['portfolio'] = finalPortfolio;
      request.fields['province'] = _selectedProvince!;
      request.fields['email'] = 'admin@dankie.co.za'; // Or input
      request.fields['role'] = 'Admin';
      request.fields['uid'] =
          "generated_${DateTime.now().millisecondsSinceEpoch}"; // Or use Auth UID if available

      String token =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      request.headers['Authorization'] = 'Bearer $token';
      // 2. Image File
      if (_isWeb) {
        var bytes = await _faceImageFile!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'face_image', // Key expected by backend for upload
            bytes,
            filename: _faceImageFile!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('face_image', _faceImageFile!.path),
        );
      }

      // 3. Send
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (mounted) {
          Api().showMessage(
            context,
            'Success',
            'Staff Member Added Successfully',
            Colors.green,
          );
          _clearForm();
          _fetchStaffMembers(); // Refresh list
        }
      } else {
        print("Server Error: ${response.body}");
        if (mounted)
          Api().showMessage(
            context,
            'Error',
            'Failed to add staff: ${response.statusCode}',
            Colors.red,
          );
      }
    } catch (e) {
      if (mounted)
        Api().showMessage(context, 'Error', e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    nameController.clear();
    surnameController.clear();
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
        Api().showMessage(
          context,
          "Action Denied",
          "At least one staff member must remain.",
          Colors.orange,
        );
        return;
      }

      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/staff/?id=$id/');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization':
              'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
        },
      );

      Navigator.pop(context); // Pop loading

      if (response.statusCode == 204) {
        Api().showMessage(
          context,
          "Deleted",
          "Staff member removed.",
          Colors.grey,
        );
        _fetchStaffMembers(); // Refresh
      } else {
        Api().showMessage(context, "Error", "Failed to delete.", Colors.red);
      }
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  // --- ⭐️ NEUMORPHIC WIDGET HELPERS (Unchanged UI) ---

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
                              // Map Django 'id' (int) or 'uid' (string)
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
                                                staff['face_url'],
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
