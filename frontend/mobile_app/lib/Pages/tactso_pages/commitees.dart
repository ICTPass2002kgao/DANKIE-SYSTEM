// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ionicons/flutter_ionicons.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
  final TextEditingController _committeePhoneController =
      TextEditingController();
  final TextEditingController _customRoleController = TextEditingController();

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
    'Other',
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
    _committeePhoneController.dispose();
    _customRoleController.dispose();
    super.dispose();
  }

  void _fetchCommittee() {
    setState(() {
      _committeeFuture = _getCommitteeData();
    });
  }

  Future<List<dynamic>> _getCommitteeData() async {
    final user = FirebaseAuth.instance.currentUser;
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

      if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
        allMembers = decoded['results'];
      } else if (decoded is List) {
        allMembers = decoded;
      }

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
    String finalRole = _selectedRole == 'Other'
        ? _customRoleController.text.trim()
        : _selectedRole ?? '';

    if (_committeeNameController.text.isEmpty || finalRole.isEmpty) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please fill all required fields including role.",
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

      final String? token = await user.getIdToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['full_name'] = _committeeNameController.text.trim();
      request.fields['email'] = _committeeEmailController.text.trim();
      request.fields['phone'] = _committeePhoneController.text.trim();
      request.fields['role'] = 'Tactso Branch';
      request.fields['portfolio'] = finalRole;
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
          details: "Added ${_committeeNameController.text} as $finalRole",
          referenceId: "N/A",
          universityName: widget.universityName,
          universityLogo: widget.universityLogoUrl,
          committeeMemberName: widget.loggedMemberName ?? widget.committeeName,
          committeeMemberRole: widget.loggedMemberRole ?? "Education Officer",
          universityCommitteeFace: widget.universityCommitteeFace,
          targetMemberName: _committeeNameController.text,
          targetMemberRole: finalRole,
        );

        _committeeNameController.clear();
        _committeeEmailController.clear();
        _committeePhoneController.clear();
        _customRoleController.clear();

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

  Future<bool> _updateCommitteeMember(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");
      final String? token = await user.getIdToken();

      final response = await http
          .patch(
            Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/$id/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception("Connection timed out."),
          );
      Navigator.pop(context); // Close the loading dialog
      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchCommittee();
        Api().showMessage(
          context,
          "Success",
          "Member updated successfully.",
          Colors.green,
        );
        return true;
      } else {
        Api().showMessage(
          context,
          "Error",
          "Server returned: ${response.statusCode}",
          Colors.red,
        );
        return false;
      }
    } catch (e) {
      Api().showMessage(context, "Network Error", "$e", Colors.red);
      return false;
    }
  }

  void _showEditDialog(dynamic member) {
    final TextEditingController editEmailController = TextEditingController(
      text: member['email'] ?? '',
    );
    final TextEditingController editPhoneController = TextEditingController(
      text: member['phone'] ?? '',
    );
    final TextEditingController editPortfolioController = TextEditingController(
      text: member['portfolio'] ?? member['role'] ?? '',
    );
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: NeumorphicContainer(
              color: widget.neumoColor,
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Edit Member",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    member['full_name'] ??
                        member['fullname'] ??
                        member['name'] ??
                        '',
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey[400]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  _buildNeumorphicTextField(
                    controller: editPortfolioController,
                    placeholder: "Portfolio / Role",
                    baseColor: widget.neumoColor,
                    prefixIcon: Icons.badge,
                  ),
                  SizedBox(height: 16),
                  _buildNeumorphicTextField(
                    controller: editEmailController,
                    placeholder: "Email Address",
                    baseColor: widget.neumoColor,
                    prefixIcon: Icons.email,
                  ),
                  SizedBox(height: 16),
                  _buildNeumorphicTextField(
                    controller: editPhoneController,
                    placeholder: "Phone Number",
                    baseColor: widget.neumoColor,
                    prefixIcon: Icons.phone,
                  ),
                  SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: isUpdating ? null : () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      GestureDetector(
                        onTap: isUpdating
                            ? null
                            : () async {
                                setDialogState(() => isUpdating = true);
                                try {
                                  bool success = await _updateCommitteeMember(
                                    member['id'].toString(),
                                    {
                                      'portfolio': editPortfolioController.text
                                          .trim(),
                                      'email': editEmailController.text.trim(),
                                      'phone': editPhoneController.text.trim(),
                                    },
                                  );
                                  if (mounted && success) {
                                    Navigator.pop(context);
                                  }
                                } finally {
                                  if (mounted) {
                                    setDialogState(() => isUpdating = false);
                                  }
                                }
                              },
                        child: NeumorphicContainer(
                          color: _primaryColor,
                          borderRadius: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: isUpdating
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  "Save Changes",
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
          );
        },
      ),
    );
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

                final String? token = await user.getIdToken();

                final url = Uri.parse(
                  '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/$memberId/',
                );
                final response = await http.delete(
                  url,
                  headers: {'Authorization': 'Bearer $token'},
                );

                if (response.statusCode == 204 || response.statusCode == 200) {
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
                } else {
                  Navigator.pop(context);
                  Api().showMessage(
                    context,
                    "Error",
                    "Failed to delete member. Status Code: ${response.statusCode}",
                    Colors.red,
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

    return SingleChildScrollView(
      child: Column(
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
                        children: _buildFormChildren(
                          widget.neumoColor,
                          isSmall,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildFormChildren(
                          widget.neumoColor,
                          isSmall,
                        ),
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
                  mainAxisExtent:
                      105, // Increased height slightly to fit phone number
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data![index];
                  var faceUrl = data['face_url'] ?? data['faceUrl'];
                  var phone = data['phone'] ?? '';

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
                              SizedBox(height: 2),
                              Text(
                                data['portfolio'] ?? data['role'] ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 10,
                                ),
                              ),
                              if (phone.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 10,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        phone,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: 18,
                              ),
                              onPressed: () => _showEditDialog(data),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            SizedBox(width: 10),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 18,
                              ),
                              onPressed: () => _deleteCommitteeMember(
                                data['id'].toString(),
                                faceUrl,
                                data['full_name'] ??
                                    data['fullname'] ??
                                    data['name'],
                                data['portfolio'] ?? data['role'],
                              ),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
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
        _buildNeumorphicTextField(
          controller: _committeePhoneController,
          placeholder: "Phone",
          baseColor: neumoColor,
          prefixIcon: Icons.phone,
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
        if (_selectedRole == 'Other') ...[
          SizedBox(height: 10),
          _buildNeumorphicTextField(
            controller: _customRoleController,
            placeholder: "Enter Custom Role",
            baseColor: neumoColor,
            prefixIcon: Icons.badge,
          ),
        ],
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
