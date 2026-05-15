// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

class MyProfile extends StatefulWidget {
  const MyProfile({super.key});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  // --- CONTROLLERS & STATE ---
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();

  XFile? _pickedFile;
  String? _currentProfileImageUrl;
  String? _userUid; // Django Database ID

  // Organization Selection State
  String? _selectedProvince;
  String? _selectedRole;
  String? _selectedMemberUid; // Overseer UID
  String? _selectedDistrictElder;
  String? _selectedCommunityName;

  // Cache for Dropdowns
  Map<String, dynamic>? _currentOverseerData;
  List<String> _districtElderNames = [];
  List<String> _communityNames = [];

  Future<Map<String, dynamic>?>? _profileFuture;
  final _formKey = GlobalKey<FormState>();

  // Static Lists
  final List<String> provinces = [
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
  final List<String> roles = ['Seller', "Member", "External Member"];

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  // --- 1. FETCH PROFILE (SECURED GET) ---
  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // SECURE FIX: Get the Token
      String? token = await user.getIdToken();
      if (token == null) return null;

      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${user.uid}',
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
          final userData = results[0] as Map<String, dynamic>; 
          _userUid = userData['id'].toString();
          return userData;
        }
      } else {
        print("Profile Auth Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
    return null;
  } 

  Future<void> _updateUserData(Map<String, dynamic> dataToUpdate) async {
    if (_userUid == null) return;

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Api().showLoading(context);

    try { 
      String? token = await user.getIdToken();
      if (token == null) throw Exception("Session expired");

      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/${user.uid}/'),
      );
 
      request.headers['Authorization'] = 'Bearer $token';

      dataToUpdate.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });

      if (_pickedFile != null) {
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'profile_url',
              await _pickedFile!.readAsBytes(),
              filename: _pickedFile!.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('profile_url', _pickedFile!.path),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      Navigator.pop(context); 
      if (response.statusCode == 200 || response.statusCode == 201) {
        Api().showMessage(
          context,
          'Profile updated successfully!',
          'Success',
          Colors.green,
        );
        setState(() {
          _profileFuture = _fetchUserProfile();
        });
      } else {
        print("Update Error: ${response.body}");
        Api().showMessage(
          context,
          "Update failed: ${response.statusCode}",
          'Error',
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, 'Error: $e', 'Error', Colors.red);
    }
  }

  // --- 3. FETCH OVERSEER DATA (SECURED) ---
  Future<void> _fetchOverseerData(
    String overseerUid,
    StateSetter setModalState,
  ) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?uid=$overseerUid',
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
          setModalState(() {
            _currentOverseerData = data;
            final districts = data['districts'] as List<dynamic>? ?? [];
            _districtElderNames = districts
                .map((d) => (d['district_elder_name'] ?? '').toString())
                .toList();

            if (_selectedDistrictElder != null) {
              final selectedDistrict = districts.firstWhere(
                (d) =>
                    (d['district_elder_name'] ?? '') == _selectedDistrictElder,
                orElse: () => null,
              );
              if (selectedDistrict != null) {
                final communities =
                    selectedDistrict['communities'] as List<dynamic>? ?? [];
                _communityNames = communities
                    .map((c) => (c['community_name'] ?? '').toString())
                    .toList();
              }
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching overseer data: $e");
    }
  }

  // Helper for Applications list (SECURED)
  Future<List<dynamic>> _fetchUserApplications() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    String? token = await user.getIdToken();

    final url = Uri.parse(
      '${Api().BACKEND_BASE_URL_DEBUG}/applications/?user_uid=${user.uid}',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  // --- HELPER: Secure Image URL ---
  String _getSecureImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return "";
    if (originalUrl.startsWith('http')) return originalUrl;
    if (originalUrl.startsWith('/'))
      return '${Api().BACKEND_BASE_URL_DEBUG}$originalUrl';
    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 15.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 50,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back, color: theme.primaryColor),
                    ),
                  ),
                  Text(
                    "My Profile",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: _onEditPressed,
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 50,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.edit, color: theme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData)
                    return Center(child: Text('Profile Not Found'));

                  final data = snapshot.data!;
                  String? profileUrl =
                      data['profile_url'] ?? data['profileUrl'];

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        NeumorphicContainer(
                          color: neumoBaseColor,
                          borderRadius: 100,
                          padding: EdgeInsets.all(8),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage:
                                (profileUrl != null && profileUrl.isNotEmpty)
                                ? NetworkImage(_getSecureImageUrl(profileUrl))
                                : AssetImage('assets/no_profile.png')
                                      as ImageProvider,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '${data['name']} ${data['surname']}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        Text(
                          data['email'] ?? '',
                          style: TextStyle(color: theme.hintColor),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (data['role'] ?? 'N/A').toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),

                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildDetailsSection(
                                      theme,
                                      neumoBaseColor,
                                      data,
                                    ),
                                    SizedBox(height: 20),
                                    _buildWeeklyStats(
                                      theme,
                                      neumoBaseColor,
                                      data,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                child: _buildApplicationsList(
                                  theme,
                                  neumoBaseColor,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildDetailsSection(theme, neumoBaseColor, data),
                              SizedBox(height: 20),
                              _buildApplicationsList(theme, neumoBaseColor),
                              SizedBox(height: 20),
                              _buildWeeklyStats(theme, neumoBaseColor, data),
                            ],
                          ),

                        SizedBox(height: 30),
                        tryBuildAd(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DISPLAY WIDGETS ---

  Widget tryBuildAd() {
    try {
      return AdManager().bannerAdWidget();
    } catch (e) {
      return SizedBox();
    }
  }

  Widget _buildDetailsSection(
    ThemeData theme,
    Color baseColor,
    Map<String, dynamic> data,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      borderRadius: 20,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Personal Details",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          Divider(color: theme.hintColor.withOpacity(0.2)),
          _infoRow(Icons.phone, "Phone", data['phone'] ?? 'N/A'),
          _infoRow(Icons.location_on, "Address", data['address'] ?? 'N/A'),
          SizedBox(height: 10),
          Text(
            "Organization",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          Divider(color: theme.hintColor.withOpacity(0.2)),
          _infoRow(Icons.map, "Province", data['province'] ?? 'N/A'),
          _infoRow(Icons.group, "Community", data['community_name'] ?? 'N/A'),
          _infoRow(Icons.person, "Elder", data['district_elder_name'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList(ThemeData theme, Color baseColor) {
    return NeumorphicContainer(
      color: baseColor,
      borderRadius: 20,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "My Applications",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(height: 15),
          FutureBuilder(
            future:
                _fetchUserApplications(), // SECURE FIX: Call helper instead of raw http
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    "Loading...",
                    style: TextStyle(color: Colors.grey),
                  ),
                );

              if (snapshot.hasData) {
                List apps = snapshot.data as List;
                if (apps.isEmpty)
                  return Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      "No applications yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: apps.length,
                  itemBuilder: (ctx, index) {
                    var data = apps[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: NeumorphicContainer(
                        isPressed: true,
                        color: baseColor,
                        borderRadius: 12,
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.school,
                                color: theme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['university_name'] ?? 'N/A',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    data['status'] ?? 'Pending',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getStatusColor(data['status']),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return Text(
                "Failed to load.",
                style: TextStyle(color: Colors.red),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyStats(
    ThemeData theme,
    Color baseColor,
    Map<String, dynamic> data,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      borderRadius: 20,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Contributions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(height: 15),
          NeumorphicContainer(
            isPressed: true,
            color: baseColor,
            borderRadius: 12,
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                _statRow("Week 1", data['week1']),
                Divider(),
                _statRow("Week 2", data['week2']),
                Divider(),
                _statRow("Week 3", data['week3']),
                Divider(),
                _statRow("Week 4", data['week4']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, dynamic val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(
            "R${double.tryParse(val.toString())?.toStringAsFixed(2) ?? '0.00'}",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'new':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  // --- EDIT SHEET & LOGIC ---

  void _onEditPressed() async {
    final Map<String, dynamic>? userData = await _fetchUserProfile();
    if (userData != null && mounted) {
      _showEditProfileSheet(context, userData);
    }
  }

  void _showEditProfileSheet(
    BuildContext context,
    Map<String, dynamic> currentData,
  ) {
    _nameController.text = currentData['name'] ?? '';
    _surnameController.text = currentData['surname'] ?? '';
    _addressController.text = currentData['address'] ?? '';
    _contactNumberController.text = currentData['phone'] ?? '';
    _currentProfileImageUrl = currentData['profile_url'];

    _pickedFile = null;
    _selectedRole = currentData['role'];
    _selectedProvince = currentData['province'];
    _selectedMemberUid = currentData['overseer_uid'];
    _selectedDistrictElder = currentData['district_elder_name'];
    _selectedCommunityName = currentData['community_name'];

    _currentOverseerData = null;
    _districtElderNames = [];
    _communityNames = [];

    final theme = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                if (_selectedMemberUid != null &&
                    _currentOverseerData == null) {
                  _fetchOverseerData(_selectedMemberUid!, setModalState);
                }

                return Container(
                  margin: EdgeInsets.only(top: 50),
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 20,
                    right: 20,
                    top: 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: NeumorphicContainer(
                                  color: baseColor,
                                  borderRadius: 50,
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final img = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 70,
                              );
                              if (img != null)
                                setModalState(() => _pickedFile = img);
                            },
                            child: NeumorphicContainer(
                              color: baseColor,
                              borderRadius: 100,
                              padding: EdgeInsets.all(5),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: baseColor,
                                backgroundImage: _pickedFile != null
                                    ? FileImage(io.File(_pickedFile!.path))
                                    : (_currentProfileImageUrl != null
                                              ? NetworkImage(
                                                  _getSecureImageUrl(
                                                    _currentProfileImageUrl,
                                                  ),
                                                )
                                              : null)
                                          as ImageProvider?,
                                child:
                                    (_pickedFile == null &&
                                        _currentProfileImageUrl == null)
                                    ? Icon(
                                        Icons.camera_alt,
                                        color: theme.primaryColor,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),

                          _buildSectionHeader("Personal Details", theme),
                          _buildNeuEditField(
                            controller: _nameController,
                            hint: 'First Name',
                            icon: Icons.person,
                            baseColor: baseColor,
                          ),
                          _buildNeuEditField(
                            controller: _surnameController,
                            hint: 'Last Name',
                            icon: Icons.person_outline,
                            baseColor: baseColor,
                          ),
                          _buildNeuEditField(
                            controller: _contactNumberController,
                            hint: 'Phone',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            baseColor: baseColor,
                          ),
                          _buildNeuEditField(
                            controller: _addressController,
                            hint: 'Address',
                            icon: Icons.location_on,
                            maxLines: 2,
                            baseColor: baseColor,
                          ),

                          SizedBox(height: 20),
                          _buildSectionHeader("Organization Details", theme),

                          _buildNeuDropdownRow(
                            title: 'Role',
                            value: _selectedRole,
                            baseColor: baseColor,
                            onTap: () => _buildActionSheet(
                              context: context,
                              title: 'Select Role',
                              actions: roles,
                              onSelected: (val) =>
                                  setModalState(() => _selectedRole = val),
                            ),
                          ),

                          _buildNeuDropdownRow(
                            title: 'Province',
                            value: _selectedProvince,
                            baseColor: baseColor,
                            onTap: () => _buildActionSheet(
                              context: context,
                              title: 'Select Province',
                              actions: provinces,
                              onSelected: (val) {
                                setModalState(() {
                                  _selectedProvince = val;
                                  _selectedMemberUid = null;
                                  _currentOverseerData = null;
                                  _selectedDistrictElder = null;
                                  _selectedCommunityName = null;
                                  _districtElderNames = [];
                                  _communityNames = [];
                                });
                              },
                            ),
                          ),

                          if (_selectedProvince != null)
                            _buildNeuDropdownRow(
                              title: 'Overseer',
                              value:
                                  _currentOverseerData?['overseer_initials_surname'] ??
                                  (_selectedMemberUid != null
                                      ? 'Loading...'
                                      : 'Select'),
                              baseColor: baseColor,
                              onTap: () async {
                                User? user = FirebaseAuth.instance.currentUser;
                                String? token = await user?.getIdToken();
                                final url = Uri.parse(
                                  '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?province=$_selectedProvince',
                                );
                                final response = await http.get(
                                  url,
                                  headers: {'Authorization': 'Bearer $token'},
                                );
                                if (response.statusCode != 200) return;

                                final List overseers = json.decode(
                                  response.body,
                                );
                                final names = overseers
                                    .map(
                                      (o) =>
                                          (o['overseer_initials_surname'] ??
                                                  'Unknown')
                                              .toString(),
                                    )
                                    .toList();

                                _buildActionSheet(
                                  context: context,
                                  title: 'Select Overseer',
                                  actions: names,
                                  onSelected: (val) {
                                    final selectedDoc = overseers.firstWhere(
                                      (o) =>
                                          o['overseer_initials_surname'] == val,
                                    );
                                    setModalState(() {
                                      _selectedMemberUid =
                                          selectedDoc['uid'] ??
                                          selectedDoc['id'].toString();
                                      _currentOverseerData = selectedDoc;
                                      _selectedDistrictElder = null;
                                      _selectedCommunityName = null;
                                      _communityNames = [];
                                      final districts =
                                          selectedDoc['districts']
                                              as List<dynamic>? ??
                                          [];
                                      _districtElderNames = districts
                                          .map(
                                            (d) =>
                                                (d['district_elder_name'] ?? '')
                                                    .toString(),
                                          )
                                          .toList();
                                    });
                                  },
                                );
                              },
                            ),

                          if (_selectedMemberUid != null)
                            _buildNeuDropdownRow(
                              title: 'District Elder',
                              value: _selectedDistrictElder,
                              baseColor: baseColor,
                              onTap: () {
                                if (_districtElderNames.isEmpty) return;
                                _buildActionSheet(
                                  context: context,
                                  title: 'Select District',
                                  actions: _districtElderNames,
                                  onSelected: (val) {
                                    setModalState(() {
                                      _selectedDistrictElder = val;
                                      _selectedCommunityName = null;
                                      final districts =
                                          _currentOverseerData!['districts']
                                              as List<dynamic>;
                                      final selectedDistrict = districts
                                          .firstWhere(
                                            (d) =>
                                                (d['district_elder_name'] ??
                                                    '') ==
                                                val,
                                          );
                                      final communities =
                                          selectedDistrict['communities']
                                              as List<dynamic>? ??
                                          [];
                                      _communityNames = communities
                                          .map(
                                            (c) => (c['community_name'] ?? '')
                                                .toString(),
                                          )
                                          .toList();
                                    });
                                  },
                                );
                              },
                            ),

                          if (_selectedDistrictElder != null)
                            _buildNeuDropdownRow(
                              title: 'Community',
                              value: _selectedCommunityName,
                              baseColor: baseColor,
                              onTap: () {
                                if (_communityNames.isEmpty) return;
                                _buildActionSheet(
                                  context: context,
                                  title: 'Select Community',
                                  actions: _communityNames,
                                  onSelected: (val) => setModalState(
                                    () => _selectedCommunityName = val,
                                  ),
                                );
                              },
                            ),

                          SizedBox(height: 30),
                          GestureDetector(
                            onTap: () {
                              _saveProfileChanges();
                              Navigator.pop(context);
                            },
                            child: NeumorphicContainer(
                              color: theme.primaryColor,
                              borderRadius: 30,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  "SAVE CHANGES",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _saveProfileChanges() {
    if (_nameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty)
      return;

    final updatedData = {
      'name': _nameController.text.trim(),
      'surname': _surnameController.text.trim(),
      'phone': _contactNumberController.text.trim(),
      'address': _addressController.text.trim(),
      'province': _selectedProvince,
      'role': _selectedRole,
      'overseer_uid': _selectedMemberUid,
      'district_elder_name': _selectedDistrictElder,
      'community_name': _selectedCommunityName,
    };
    _updateUserData(updatedData);
  }

  // --- WIDGETS FOR EDIT SHEET ---

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNeuEditField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required Color baseColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: true,
        borderRadius: 12,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: Icon(icon, color: Colors.grey),
            hintText: hint,
          ),
        ),
      ),
    );
  }

  Widget _buildNeuDropdownRow({
    required String title,
    required String? value,
    required VoidCallback onTap,
    required Color baseColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: NeumorphicContainer(
          color: baseColor,
          isPressed: false,
          borderRadius: 12,
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Text(
                    value ?? 'Select',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).hintColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _buildActionSheet({
    required BuildContext context,
    required String title,
    required List<String> actions,
    required ValueChanged<String> onSelected,
  }) {
    if (isIOSPlatform) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(title),
          actions: actions
              .map(
                (item) => CupertinoActionSheetAction(
                  child: Text(item),
                  onPressed: () {
                    onSelected(item);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
                Divider(),
                ...actions
                    .map(
                      (item) => ListTile(
                        title: Text(item),
                        onTap: () {
                          onSelected(item);
                          Navigator.pop(context);
                        },
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        ),
      );
    }
  }
}
