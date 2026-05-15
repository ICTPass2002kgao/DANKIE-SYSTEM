// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:io' as io;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/Admin/services/overseer_services.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
bool get isWeb => kIsWeb;

// --- ⭐️ REUSABLE NEUMORPHIC TEXT FIELD ---
Widget _buildNeumorphicTextField({
  required TextEditingController controller,
  required String placeholder,
  required Color baseColor,
  IconData? prefixIcon,
  required BuildContext context,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 15.0),
    child: NeumorphicContainer(
      isPressed: true,
      color: baseColor,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: isIOSPlatform
          ? CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              placeholderStyle: TextStyle(
                color: theme.hintColor.withOpacity(0.6),
              ),
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              prefix: prefixIcon != null
                  ? Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(prefixIcon, color: theme.primaryColor),
                    )
                  : null,
              decoration: null,
              padding: const EdgeInsets.all(16.0),
            )
          : TextFormField(
              controller: controller,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
                prefixIcon: prefixIcon != null
                    ? Icon(prefixIcon, color: theme.primaryColor)
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 10.0,
                ),
              ),
            ),
    ),
  );
}

class AdminAddOverseer extends StatefulWidget {
  final String? uid;
  final String? fullName;
  final String? portfolio;
  final String? province;

  const AdminAddOverseer({
    super.key,
    this.uid,
    this.fullName,
    this.portfolio,
    this.province,
  });

  @override
  State<AdminAddOverseer> createState() => _AdminAddOverseerState();
}

class _AdminAddOverseerState extends State<AdminAddOverseer> {
  final _service = OverseerService();

  // Controllers
  final overseerCodeController = TextEditingController();
  final overseerRegionController = TextEditingController();
  final overseerInitialsAndSurname = TextEditingController();
  final overseerDistrictElderController = TextEditingController();
  final overseerCommunityNameController = TextEditingController();
  final secretaryNameController = TextEditingController();
  final chairpersonNameController = TextEditingController();

  // Images
  XFile? secretaryImageFile;
  XFile? chairpersonImageFile;

  List<String> provinces = [
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];
  String? selectedProvince;

  Map<String, List<Map<String, String>>> districtCommunities = {};

  Future<void> _pickImage(String role) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        if (role == 'secretary') {
          secretaryImageFile = image;
        } else {
          chairpersonImageFile = image;
        }
      });
    }
  }

  Future<void> _handleSubmit() async {
    // UPDATED VALIDATION: Ensure committee details are present
    if (overseerInitialsAndSurname.text.isEmpty ||
        selectedProvince == null ||
        districtCommunities.isEmpty ||
        secretaryNameController.text.isEmpty ||
        secretaryImageFile == null ||
        chairpersonNameController.text.isEmpty ||
        chairpersonImageFile == null) {
      Api().showMessage(
        context,
        'Please fill all fields, including Committee details and photos.',
        'Missing Info',
        Colors.orange,
      );
      return;
    }

    Api().showLoading(context);

    try {
      await _service.addOverseer(
        initialsSurname: overseerInitialsAndSurname.text.trim(),
        region: overseerRegionController.text.trim(),
        code: overseerCodeController.text.trim(),
        province: selectedProvince!,
        // --- COMMITTEE DATA ---
        secretaryName: secretaryNameController.text.trim(),
        secretaryImage: secretaryImageFile,
        chairpersonName: chairpersonNameController.text.trim(),
        chairpersonImage: chairpersonImageFile,
        // ----------------------
        districtsData: districtCommunities,
        adminUid: widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '',
      );

      Navigator.pop(context);
      Api().showMessage(
        context,
        'Overseer & Committee Created!',
        'Success',
        Colors.green,
      );
      _resetForm();
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(context, e.toString(), 'Error', Colors.red);
    }
  }

  void _resetForm() {
    overseerInitialsAndSurname.clear();
    overseerDistrictElderController.clear();
    overseerCommunityNameController.clear();
    secretaryNameController.clear();
    chairpersonNameController.clear();
    overseerCodeController.clear();
    overseerRegionController.clear();
    setState(() {
      selectedProvince = null;
      districtCommunities.clear();
      secretaryImageFile = null;
      chairpersonImageFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.3),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                    NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 20,
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 40,
                            color: theme.primaryColor,
                          ),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Add New Overseer",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: theme.primaryColor,
                                ),
                              ),
                              Text(
                                "Configure hierarchy & access",
                                style: TextStyle(
                                  color: theme.primaryColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),

                    isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildLeftColumn(
                                  context,
                                  neumoBaseColor,
                                ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: _buildRightColumn(
                                  context,
                                  neumoBaseColor,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildLeftColumn(context, neumoBaseColor),
                              SizedBox(height: 20),
                              _buildRightColumn(context, neumoBaseColor),
                            ],
                          ),

                    SizedBox(height: 40),

                    GestureDetector(
                      onTap: _handleSubmit,
                      child: NeumorphicContainer(
                        color: theme.primaryColor,
                        borderRadius: 15,
                        padding: EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 60,
                        ),
                        child: Text(
                          "CREATE OVERSEER PROFILE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context, Color baseColor) {
    final theme = Theme.of(context);
    return Column(
      children: [
        NeumorphicContainer(
          color: baseColor,
          borderRadius: 20,
          padding: EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("1. Overseer Details", theme),
              _buildNeumorphicTextField(
                context: context,
                controller: overseerInitialsAndSurname,
                placeholder: "Initials & Surname",
                baseColor: baseColor,
                prefixIcon: Icons.person,
              ),
              _buildNeumorphicTextField(
                context: context,
                controller: overseerRegionController,
                placeholder: "Region",
                baseColor: baseColor,
                prefixIcon: Icons.map,
              ),
              _buildNeumorphicTextField(
                context: context,
                controller: overseerCodeController,
                placeholder: "Code (e.g. 001)",
                baseColor: baseColor,
                prefixIcon: Icons.numbers,
              ),
              NeumorphicContainer(
                isPressed: true,
                color: baseColor,
                borderRadius: 12,
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Text("Select Province"),
                    value: selectedProvince,
                    items: provinces
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedProvince = val),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        NeumorphicContainer(
          color: baseColor,
          borderRadius: 20,
          padding: EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("2. Committee (Biometrics)", theme),
              _buildNeumorphicTextField(
                context: context,
                controller: secretaryNameController,
                placeholder: "Secretary Name",
                baseColor: baseColor,
              ),
              _buildImagePicker(
                "Secretary Face",
                secretaryImageFile,
                () => _pickImage('secretary'),
                baseColor,
              ),
              SizedBox(height: 15),
              _buildNeumorphicTextField(
                context: context,
                controller: chairpersonNameController,
                placeholder: "Chairperson Name",
                baseColor: baseColor,
              ),
              _buildImagePicker(
                "Chairperson Face",
                chairpersonImageFile,
                () => _pickImage('chairperson'),
                baseColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context, Color baseColor) {
    final theme = Theme.of(context);
    return Column(
      children: [
        NeumorphicContainer(
          color: baseColor,
          borderRadius: 20,
          padding: EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("3. Add Structure", theme),
              Row(
                children: [
                  Expanded(
                    child: _buildNeumorphicTextField(
                      context: context,
                      controller: overseerDistrictElderController,
                      placeholder: "District Elder Name",
                      baseColor: baseColor,
                    ),
                  ),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      String name = overseerDistrictElderController.text.trim();
                      if (name.isNotEmpty &&
                          !districtCommunities.containsKey(name)) {
                        setState(() {
                          districtCommunities[name] = [];
                          overseerDistrictElderController.clear();
                        });
                      }
                    },
                    child: NeumorphicContainer(
                      color: theme.primaryColor,
                      borderRadius: 12,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        if (districtCommunities.isNotEmpty)
          ...districtCommunities.keys.map((elderName) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: NeumorphicContainer(
                color: baseColor,
                borderRadius: 20,
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "District: $elderName",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.primaryColor,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(
                            () => districtCommunities.remove(elderName),
                          ),
                          child: Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    Divider(),
                    ...districtCommunities[elderName]!.map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.home_work, size: 14, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(c['communityName']!),
                            Spacer(),
                            InkWell(
                              onTap: () => setState(
                                () => districtCommunities[elderName]!.remove(c),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: theme.cardColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: overseerCommunityNameController,
                              decoration: InputDecoration(
                                hintText: "Add Community...",
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (val) =>
                                  _addCommunity(elderName, val),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () => _addCommunity(
                            elderName,
                            overseerCommunityNameController.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _addCommunity(String elderName, String commName) {
    if (commName.trim().isNotEmpty) {
      setState(() {
        districtCommunities[elderName]!.add({'communityName': commName.trim()});
        overseerCommunityNameController.clear();
      });
    }
  }

  Widget _sectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Text(
        title,
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  // UPDATED IMAGE PICKER: Enhanced feedback for biometrics
  Widget _buildImagePicker(
    String label,
    XFile? file,
    VoidCallback onTap,
    Color baseColor,
  ) {
    bool hasFile = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: NeumorphicContainer(
          isPressed: true,
          color: baseColor,
          borderRadius: 12,
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              if (hasFile)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: kIsWeb
                      ? Image.network(
                          file.path,
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          io.File(file.path),
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                        ),
                )
              else
                Icon(
                  Icons.camera_enhance_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasFile ? "Face Captured" : "Upload $label",
                  style: TextStyle(
                    color: hasFile
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    fontWeight: hasFile ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (hasFile)
                Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
