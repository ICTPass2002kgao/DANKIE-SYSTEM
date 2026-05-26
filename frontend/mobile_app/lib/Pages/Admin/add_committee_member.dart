// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 900.0;
bool get isDesktop =>
    kIsWeb ||
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

class AddCommitteeMember extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;

  const AddCommitteeMember({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<AddCommitteeMember> createState() => _AddCommitteeMemberState();
}

class _AddCommitteeMemberState extends State<AddCommitteeMember> {
  // State for Desktop Split View
  String? _selectedBranchId;
  Map<String, dynamic>? _selectedBranchData;

  // Fetch branches with Firebase Auth Token
  Future<http.Response> _fetchBranches() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return http.get(
      Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/tactso_branches/'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width > _desktopBreakpoint;
    final theme = Theme.of(context);
    final neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: isLargeScreen
          ? _buildDesktopLayout(theme, neumoBaseColor)
          : _buildMobileLayout(theme, neumoBaseColor),
    );
  }

  // --- LAYOUTS ---

  Widget _buildMobileLayout(ThemeData theme, Color neumoBaseColor) {
    return _buildBranchList(
      theme: theme,
      neumoBaseColor: neumoBaseColor,
      onTap: (id, data) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: neumoBaseColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      padding: EdgeInsets.all(20),
                      child: CommitteeManagerView(
                        branchId: id,
                        branchData: data,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, Color neumoBaseColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: List
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: neumoBaseColor,
            border: Border(
              right: BorderSide(color: theme.primaryColor.withOpacity(0.1)),
            ),
          ),
          child: _buildBranchList(
            theme: theme,
            neumoBaseColor: neumoBaseColor,
            onTap: (id, data) {
              setState(() {
                _selectedBranchId = id;
                _selectedBranchData = data;
              });
            },
            selectedId: _selectedBranchId,
          ),
        ),

        // Right: Details
        Expanded(
          child: _selectedBranchId == null
              ? Center(
                  child: Text(
                    "Select a University Branch to manage its committee.",
                    style: TextStyle(
                      color: theme.primaryColor.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(40),
                  child: CommitteeManagerView(
                    key: ValueKey(_selectedBranchId), // Force rebuild on change
                    branchId: _selectedBranchId!,
                    branchData: _selectedBranchData!,
                  ),
                ),
        ),
      ],
    );
  }

  // --- BRANCH LIST (DJANGO API) ---

  Widget _buildBranchList({
    required Function(String, Map<String, dynamic>) onTap,
    String? selectedId,
    required ThemeData theme,
    required Color neumoBaseColor,
  }) {
    return FutureBuilder<http.Response>(
      future: _fetchBranches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CupertinoActivityIndicator(color: theme.primaryColor),
          );
        }

        if (snapshot.hasError || snapshot.data?.statusCode != 200) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Error loading branches.\n"
                "Details: ${snapshot.error ?? 'Status Code ${snapshot.data?.statusCode}'}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        List<dynamic> branches = json.decode(snapshot.data!.body);

        if (branches.isEmpty) {
          return Center(
            child: Text(
              "No Branches Found",
              style: TextStyle(color: theme.primaryColor),
            ),
          );
        }

        return ListView.builder(
          itemCount: branches.length,
          padding: EdgeInsets.all(10),
          itemBuilder: (context, index) {
            final data = branches[index];
            final String id = data['id'].toString();
            final bool isSelected = selectedId == id;

            final String uniName = data['university_name'] ?? 'Unknown';
            final String email = data['email'] ?? '';
            String? logoUrl = data['image_url'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GestureDetector(
                onTap: () => onTap(id, data),
                child: NeumorphicContainer(
                  isPressed: isSelected,
                  color: isSelected
                      ? theme.primaryColor.withOpacity(0.1)
                      : null,
                  borderRadius: 12,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 30,
                      padding: EdgeInsets.all(logoUrl != null ? 0 : 8),
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        backgroundImage: (logoUrl != null && logoUrl.isNotEmpty)
                            ? NetworkImage(logoUrl)
                            : null,
                        child: (logoUrl == null || logoUrl.isEmpty)
                            ? Icon(Icons.school, color: theme.primaryColor)
                            : null,
                      ),
                    ),
                    title: Text(
                      uniName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    subtitle: Text(
                      email,
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.primaryColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// === REUSABLE COMMITTEE MANAGER (Django API Integration) ===
// =============================================================================

class CommitteeManagerView extends StatefulWidget {
  final String branchId;
  final Map<String, dynamic> branchData;

  const CommitteeManagerView({
    super.key,
    required this.branchId,
    required this.branchData,
  });

  @override
  State<CommitteeManagerView> createState() => _CommitteeManagerViewState();
}

class _CommitteeManagerViewState extends State<CommitteeManagerView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedRole;
  XFile? _faceImage;
  bool _isUploading = false;

  // Data fetching state
  List<dynamic> _members = [];
  bool _isLoadingMembers = true;

  final List<String> _roles = [
    'Chairperson',
    'Deputy Chairperson',
    'Secretary',
    'Deputy Secretary',
    'Treasurer',
    'Additional Member',
    'Education Officer',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/?branch=${widget.branchId}',
      );
      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> allMembers = json.decode(response.body);

        setState(() {
          // Manually filter the list in Flutter just in case the backend ignores the query parameter
          _members = allMembers.where((member) {
            // Ensure the 'branch' key matches what your JSON returns
            return member['branch'].toString() == widget.branchId;
          }).toList();

          _isLoadingMembers = false;
        });
      } else {
        setState(() => _isLoadingMembers = false);
        print("Error fetching members: ${response.body}");
      }
    } catch (e) {
      setState(() => _isLoadingMembers = false);
      print("Network error: $e");
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _faceImage = picked);
  }

  // --- 2. ADD MEMBER (POST MULTIPART) ---
  Future<void> _addMember() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _selectedRole == null) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please fill all fields",
        Colors.orange,
      );
      return;
    }
    if (_faceImage == null) {
      Api().showMessage(
        context,
        "Face Required",
        "Upload face for biometric login",
        Colors.red,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      var uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/');
      var request = http.MultipartRequest('POST', uri);

      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Fields
      request.fields['branch'] = widget.branchId;
      request.fields['fullname'] = _nameController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['role'] = _selectedRole!;

      // File
      if (kIsWeb) {
        var bytes = await _faceImage!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'face_image',
            bytes,
            filename: _faceImage!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('face_image', _faceImage!.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        _nameController.clear();
        _emailController.clear();
        setState(() {
          _selectedRole = null;
          _faceImage = null;
          _isUploading = false;
        });
        Api().showMessage(context, "Success", "Member added", Colors.green);
        _fetchMembers(); // Refresh list
      } else {
        setState(() => _isUploading = false);
        Api().showMessage(
          context,
          "Error",
          "Failed: ${response.body}",
          Colors.red,
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  // --- 3. DELETE MEMBER (DELETE) ---
  Future<void> _deleteMember(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/$id/',
      );
      final response = await http.delete(
        uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 204) {
        Api().showMessage(context, "Deleted", "Member removed", Colors.grey);
        _fetchMembers(); // Refresh list
      } else {
        Api().showMessage(context, "Error", "Failed to delete", Colors.red);
      }
    } catch (e) {
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uniName = widget.branchData['university_name'] ?? "University";
    final theme = Theme.of(context);
    final neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            NeumorphicContainer(
              isPressed: true,
              borderRadius: 12,
              padding: EdgeInsets.all(12),
              child: Icon(Icons.shield, color: theme.primaryColor, size: 30),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uniName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Committee Management (Admin Override)",
                    style: TextStyle(color: theme.hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 30),

        // --- ADD FORM ---
        NeumorphicContainer(
          borderRadius: 20,
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add New Member",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
              SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 15,
                      padding: EdgeInsets.zero,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: _faceImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    color: theme.primaryColor.withOpacity(0.5),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Face",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: kIsWeb
                                    ? Image.network(
                                        _faceImage!.path,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        io.File(_faceImage!.path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  // Inputs
                  Expanded(
                    child: Column(
                      children: [
                        _styledTextField(
                          _nameController,
                          "Full Name",
                          Icons.person,
                          theme,
                        ),
                        SizedBox(height: 12),
                        _styledTextField(
                          _emailController,
                          "Email",
                          Icons.email,
                          theme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRole,
                          hint: Text(
                            "Select Portfolio",
                            style: TextStyle(
                              color: theme.hintColor.withOpacity(0.6),
                            ),
                          ),
                          dropdownColor: neumoBaseColor,
                          isExpanded: true,
                          items: _roles
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedRole = v),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  GestureDetector(
                    onTap: _isUploading ? null : _addMember,
                    child: NeumorphicContainer(
                      color: theme.primaryColor,
                      borderRadius: 10,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: _isUploading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "ADD MEMBER",
                              style: TextStyle(
                                color: Colors.white,
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
        Text(
          "Current Committee",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: 15),

        // --- GRID LIST (Local Data) ---
        _isLoadingMembers
            ? Center(
                child: CupertinoActivityIndicator(color: theme.primaryColor),
              )
            : _members.isEmpty
            ? NeumorphicContainer(
                isPressed: true,
                padding: EdgeInsets.all(20),
                borderRadius: 12,
                child: Center(
                  child: Text(
                    "No members found.",
                    style: TextStyle(color: theme.hintColor),
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 90,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  var data = _members[index];
                  final String id = data['id'].toString();

                  return NeumorphicContainer(
                    borderRadius: 12,
                    padding: EdgeInsets.all(10),
                    child: Row(
                      children: [
                        NeumorphicContainer(
                          isPressed: true,
                          borderRadius: 10,
                          padding: EdgeInsets.zero,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image:
                                    (data['face_url'] != null &&
                                        data['face_url'].toString().isNotEmpty)
                                    ? NetworkImage(data['face_url'])
                                    : NetworkImage(
                                            'https://via.placeholder.com/150',
                                          )
                                          as ImageProvider,
                                fit: BoxFit.cover,
                                onError: (e, s) => Icon(Icons.person),
                              ),
                            ),
                            child:
                                (data['face_url'] == null ||
                                    data['face_url'].toString().isEmpty)
                                ? Icon(
                                    Icons.person,
                                    color: theme.primaryColor.withOpacity(0.5),
                                  )
                                : null,
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
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                data['portfolio'] ?? 'Member',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade400,
                          ),
                          onPressed: () => _deleteMember(id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        SizedBox(height: 50),
      ],
    );
  }

  Widget _styledTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    ThemeData theme,
  ) {
    return NeumorphicContainer(
      isPressed: true,
      borderRadius: 12,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: TextField(
        controller: controller,
        style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: theme.primaryColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 10.0,
          ),
        ),
      ),
    );
  }
}
