// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Components/Aduit_Logs/Tactso_Audit_Logs.dart';

class CommitteeTab extends StatefulWidget {
  final String branchId;
  final Color neumoColor;
  final String universityName;
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? faceUrl;
  final String? universityLogoUrl;
  final String? committeeName;
  final String? universityCommitteeFace;

  const CommitteeTab({
    Key? key,
    required this.branchId,
    required this.neumoColor,
    required this.universityName,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.faceUrl,
    this.universityLogoUrl,
    this.committeeName,
    this.universityCommitteeFace,
  }) : super(key: key);

  @override
  State<CommitteeTab> createState() => _CommitteeTabState();
}

class _CommitteeTabState extends State<CommitteeTab> {
  Future<List<dynamic>>? _committeeFuture;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _committeeNameController =
      TextEditingController();
  final TextEditingController _committeeEmailController =
      TextEditingController();

  String? _selectedRole;
  XFile? _committeeFaceImage;
  bool _isUploadingCommittee = false;

  final List<String> _committeeRoles = [
    'Chairperson',
    'Deputy Chairperson',
    'Secretary',
    'Deputy Secretary',
    'Treasurer',
    'Additional Member',
  ];

  Color get _primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchCommittee();
  }

  @override
  void dispose() {
    _committeeNameController.dispose();
    _committeeEmailController.dispose();
    super.dispose();
  }

  void _fetchCommittee() {
    setState(() {
      _committeeFuture = _getCommitteeData();
    });
  }

  Future<List<dynamic>> _getCommitteeData() async {
    final user = FirebaseAuth.instance.currentUser;
    // FIXED: Using clean String? syntax
    final String? token = await user?.getIdToken();

    final response = await http.get(
      Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/?branch=${widget.branchId}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      var decoded = json.decode(response.body);
      List<dynamic> allMembers = [];

      // Safely handle both paginated and unpaginated Django responses
      if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
        allMembers = decoded['results'];
      } else if (decoded is List) {
        allMembers = decoded;
      }

      // ⭐️ STRICT LOCAL FILTER: Keep only members assigned to THIS specific branch ID
      return allMembers.where((member) {
        return member['branch'].toString() == widget.branchId.toString();
      }).toList();
    }

    return [];
  }

  Future<void> _pickCommitteeImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _committeeFaceImage = picked);
  }

  Future<void> _addCommitteeMember() async {
    if (_committeeNameController.text.isEmpty || _selectedRole == null) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please fill all fields.",
        Colors.orange,
      );
      return;
    }
    if (_committeeFaceImage == null) {
      Api().showMessage(context, "Face Required", "Upload face.", Colors.red);
      return;
    }

    setState(() => _isUploadingCommittee = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // FIXED: Using clean String? syntax
      final String? token = await user.getIdToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // FIXED: Field name must be 'full_name' to match Django backend model TactsoCommitteeMember
      request.fields['full_name'] = _committeeNameController.text.trim();
      request.fields['email'] = _committeeEmailController.text.trim();
      request.fields['role'] = 'Tactso Branch';
      request.fields['portfolio'] = _selectedRole!;
      request.fields['branch'] = widget.branchId;

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'face_image',
            await _committeeFaceImage!.readAsBytes(),
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
        await TactsoAuditLogs.logAction(
          action: "ADD_COMMITTEE_MEMBER",
          details: "Added ${_committeeNameController.text} as $_selectedRole",
          referenceId: "N/A",
          universityName: widget.universityName,
          universityLogo: widget.universityLogoUrl,
          committeeMemberName: widget.loggedMemberName ?? widget.committeeName,
          committeeMemberRole: widget.loggedMemberRole ?? "Education Officer",
          universityCommitteeFace: widget.universityCommitteeFace,
          targetMemberName: _committeeNameController.text,
          targetMemberRole: _selectedRole,
        );

        _committeeNameController.clear();
        _committeeEmailController.clear();
        setState(() {
          _selectedRole = null;
          _committeeFaceImage = null;
          _isUploadingCommittee = false;
        });
        _fetchCommittee();
        Api().showMessage(context, "Success", "Member added.", Colors.green);
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isUploadingCommittee = false);
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  Future<void> _deleteCommitteeMember(
    String memberId,
    String? faceUrl,
    String memberName,
    String memberRole,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Confirm Deletion"),
        content: Text(
          "Remove $memberName ($memberRole)? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (widget.faceUrl == faceUrl) {
                Api().showMessage(
                  context,
                  "Action Denied",
                  "You cannot delete yourself.",
                  Colors.red,
                );
                return;
              }
              Navigator.pop(context);
              Api().showLoading(context);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception("User not logged in");

                // FIXED: Using clean String? syntax
                final String? token = await user.getIdToken();

                final url = Uri.parse(
                  '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/$memberId/',
                );
                final response = await http.delete(
                  url,
                  headers: {'Authorization': 'Bearer $token'},
                );

                if (response.statusCode == 204) {
                  await TactsoAuditLogs.logAction(
                    action: "DELETE_COMMITTEE_MEMBER",
                    details: "Removed $memberName from committee",
                    referenceId: memberId.toString(),
                    universityName: widget.universityName,
                    universityLogo: widget.universityLogoUrl,
                    committeeMemberName:
                        widget.loggedMemberName ?? widget.committeeName,
                    committeeMemberRole:
                        widget.loggedMemberRole ?? "Education Officer",
                    universityCommitteeFace: widget.universityCommitteeFace,
                    targetMemberName: memberName,
                    targetMemberRole: memberRole,
                  );

                  _fetchCommittee();
                  Navigator.pop(context);
                  Api().showMessage(
                    context,
                    "Deleted",
                    "Member removed.",
                    Colors.grey,
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                Api().showMessage(context, "Error", "$e", Colors.red);
              }
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSmall = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeumorphicContainer(
          color: widget.neumoColor,
          padding: EdgeInsets.all(isSmall ? 16 : 20),
          borderRadius: 16,
          child: Column(
            children: [
              Text(
                "Add Member",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 15),
              isSmall
                  ? Column(
                      children: _buildFormChildren(widget.neumoColor, isSmall),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildFormChildren(widget.neumoColor, isSmall),
                    ),
            ],
          ),
        ),
        SizedBox(height: 20),
        FutureBuilder<List<dynamic>>(
          future: _committeeFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CupertinoActivityIndicator();
            if (snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "No committee members found for this branch.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                mainAxisExtent: 90,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                var data = snapshot.data![index];
                var faceUrl = data['face_url'] ?? data['faceUrl'];

                return NeumorphicContainer(
                  color: widget.neumoColor,
                  padding: EdgeInsets.all(10),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      NeumorphicContainer(
                        child: Icon(
                          Ionicons.person,
                          size: 20,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Ensure frontend falls back if the backend object has `full_name` instead of `fullname`
                            Text(
                              data['full_name'] ??
                                  data['fullname'] ??
                                  data['name'] ??
                                  '',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              data['portfolio'] ?? data['role'] ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () => _deleteCommitteeMember(
                          data['id'].toString(),
                          faceUrl,
                          data['full_name'] ?? data['fullname'] ?? data['name'],
                          data['portfolio'] ?? data['role'],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildFormChildren(Color neumoColor, bool isSmall) {
    Widget formFields = Column(
      children: [
        _buildNeumorphicTextField(
          controller: _committeeNameController,
          placeholder: "Name",
          baseColor: neumoColor,
          prefixIcon: Icons.person,
        ),
        SizedBox(height: 10),
        _buildNeumorphicTextField(
          controller: _committeeEmailController,
          placeholder: "Email",
          baseColor: neumoColor,
          prefixIcon: Icons.email,
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: NeumorphicContainer(
                color: neumoColor,
                isPressed: true,
                borderRadius: 12,
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    hint: Text(
                      "Select Role",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    isDense: true,
                    items: _committeeRoles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, style: TextStyle(fontSize: 12)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRole = v),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: _isUploadingCommittee ? null : _addCommitteeMember,
              child: NeumorphicContainer(
                color: _primaryColor,
                borderRadius: 12,
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: _isUploadingCommittee
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Add",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );

    return [
      InkWell(
        onTap: _pickCommitteeImage,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: _committeeFaceImage == null
              ? Icon(Icons.add_a_photo, color: Colors.grey, size: 20)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(11),
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
      SizedBox(width: 15, height: 15),
      isSmall ? formFields : Expanded(child: formFields),
    ];
  }

  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String placeholder,
    required Color baseColor,
    required IconData prefixIcon,
  }) {
    return NeumorphicContainer(
      isPressed: true,
      color: baseColor,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
            color: Colors.grey.withOpacity(0.6),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: Theme.of(context).primaryColor,
            size: 18,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12.0,
            horizontal: 10.0,
          ),
        ),
      ),
    );
  }
}
