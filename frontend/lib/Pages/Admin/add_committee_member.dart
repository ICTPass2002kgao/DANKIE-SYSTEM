// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables, avoid_print

import 'dart:convert'; // Added for JSON
import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Added for API
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';

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
  int? _selectedBranchId; // Changed to int (Django ID)
  Map<String, dynamic>? _selectedBranchData;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width > _desktopBreakpoint;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Manage Committees (Super Admin)",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: isLargeScreen ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // --- LAYOUTS ---

  Widget _buildMobileLayout() {
    return _buildBranchList(
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
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
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

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: List
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: _buildBranchList(
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
                    style: TextStyle(color: Colors.grey),
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
    required Function(int, Map<String, dynamic>) onTap,
    int? selectedId,
  }) {
    return FutureBuilder<http.Response>(
      // Fetch branches from Django
      future: http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/tactso_branches/'),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CupertinoActivityIndicator());
        }

        if (snapshot.hasError || snapshot.data?.statusCode != 200) {
          return Center(child: Text("Error loading branches"));
        }

        List<dynamic> branches = json.decode(snapshot.data!.body);

        if (branches.isEmpty) {
          return Center(child: Text("No Branches Found"));
        }

        return ListView.builder(
          itemCount: branches.length,
          itemBuilder: (context, index) {
            final data = branches[index];
            final int id = data['id'];
            final bool isSelected = selectedId == id;

            // Handle Django Snake Case
            final String uniName = data['university_name'] ?? 'Unknown';
            final String email = data['email'] ?? '';
            String? logoUrl = data['image_url'];

            return Container(
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (logoUrl != null && logoUrl.isNotEmpty)
                      ? NetworkImage(logoUrl)
                      : null,
                  child: (logoUrl == null || logoUrl.isEmpty)
                      ? Icon(Icons.school, color: Colors.grey)
                      : null,
                ),
                title: Text(
                  uniName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(email, style: TextStyle(fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => onTap(id, data),
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
  final int branchId; // Django ID
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

  final Color _cardColor = Colors.white;
  final Color _borderColor = Colors.grey.shade300;
  final Color _inputFillColor = Colors.grey.shade50;
  final Color _primaryColor = const Color(0xFF1E3A8A);
  final Color _textColor = Colors.black87;
  final Color _subTextColor = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  // --- 1. FETCH MEMBERS (GET) ---
  Future<void> _fetchMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      // Filter by branch ID
      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/?branch=${widget.branchId}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        setState(() {
          _members = json.decode(response.body);
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

      // Fields
      request.fields['branch'] = widget.branchId.toString();
      request.fields['fullname'] = _nameController.text
          .trim(); // Matches Django Model 'fullname'
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
  Future<void> _deleteMember(int id) async {
    try {
      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/$id/',
      );
      final response = await http.delete(uri);

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
    // Handle potential null/missing keys from Django map
    final String uniName = widget.branchData['university_name'] ?? "University";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shield, color: Colors.blue, size: 30),
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
                      color: _textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Committee Management (Admin Override)",
                    style: TextStyle(color: _subTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 30),

        // --- ADD FORM ---
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add New Member",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Picker
                  InkWell(
                    onTap: _pickImage,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: _inputFillColor,
                        border: Border.all(color: _borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _faceImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: _subTextColor),
                                SizedBox(height: 4),
                                Text(
                                  "Face",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _subTextColor,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(11),
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
                  SizedBox(width: 20),
                  // Inputs
                  Expanded(
                    child: Column(
                      children: [
                        _styledTextField(
                          _nameController,
                          "Full Name",
                          Icons.person,
                        ),
                        SizedBox(height: 12),
                        _styledTextField(
                          _emailController,
                          "Email",
                          Icons.email,
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
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      hint: Text("Select Portfolio"),
                      dropdownColor: _cardColor,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: _roles
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRole = v),
                    ),
                  ),
                  SizedBox(width: 15),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _addMember,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24),
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
                          : Text("Add Member"),
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
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        SizedBox(height: 15),

        // --- GRID LIST (Local Data) ---
        _isLoadingMembers
            ? Center(child: CupertinoActivityIndicator())
            : _members.isEmpty
            ? Container(
                padding: EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "No members found.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
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
                  final int id = data['id'];

                  return Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[200],
                            image: DecorationImage(
                              image:
                                  (data['face_url'] != null &&
                                      data['face_url'].toString().isNotEmpty)
                                  ? NetworkImage(data['face_url'])
                                  : NetworkImage(
                                          'https://via.placeholder.com/150',
                                        )
                                        as ImageProvider, // Fallback
                              fit: BoxFit.cover,
                              onError: (e, s) => Icon(Icons.person),
                            ),
                          ),
                          child:
                              (data['face_url'] == null ||
                                  data['face_url'].toString().isEmpty)
                              ? Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data['fullname'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                data['role'] ?? 'Member',
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteMember(id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        SizedBox(height: 50), // Bottom padding
      ],
    );
  }

  Widget _styledTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _subTextColor, size: 20),
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
