// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:url_launcher/url_launcher.dart';

class MemberSkillsTab extends StatefulWidget {
  final bool isLargeScreen;
  final String committeeMemberName;
  final String committeeMemberRole;
  final String? faceUrl;

  const MemberSkillsTab({
    Key? key,
    required this.isLargeScreen,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    this.faceUrl,
  }) : super(key: key);

  @override
  State<MemberSkillsTab> createState() => _MemberSkillsTabState();
}

class _MemberSkillsTabState extends State<MemberSkillsTab> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<dynamic> _allMembers = [];
  String? _overseerUid;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadOverseerAndMembers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. DATA FETCHING ---
  Future<void> _loadOverseerAndMembers() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken() ?? '';
      final email = user.email ?? '';

      final overseerRes = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${Uri.encodeComponent(email)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (overseerRes.statusCode == 200) {
        final List data = json.decode(overseerRes.body);
        if (data.isNotEmpty) {
          _overseerUid = data[0]['uid'].toString();
        }
      }

      if (_overseerUid == null) {
        final commRes = await http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/?email=${Uri.encodeComponent(email)}',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (commRes.statusCode == 200) {
          final List data = json.decode(commRes.body);
          if (data.isNotEmpty) {
            final overseerId = data[0]['overseer'];
            final overseerDetail = await http.get(
              Uri.parse(
                '${Api().BACKEND_BASE_URL_DEBUG}/overseers/$overseerId/',
              ),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (overseerDetail.statusCode == 200) {
              final ovData = json.decode(overseerDetail.body);
              _overseerUid = ovData['uid'];
            }
          }
        }
      }

      if (_overseerUid != null) {
        final membersRes = await http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$_overseerUid',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (membersRes.statusCode == 200) {
          final List data = json.decode(membersRes.body);
          setState(() {
            _allMembers = data;
          });
        }
      } else {
        Api().showMessage(
          context,
          'You are not associated with an overseer',
          'Error',
          Colors.orange,
        );
      }
    } catch (e) {
      print('Error loading members: $e');
      Api().showMessage(context, 'Error loading data', 'Error', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to fetch encrypted images
  String _getSecureImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return "";
    if (originalUrl.startsWith('http') && !originalUrl.contains('.enc'))
      return originalUrl;
    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  // --- 2. SKILL SAVING ---
  Future<void> _saveSkillsForMember(
    String memberUid,
    List<dynamic> updatedSkills,
  ) async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken() ?? '';

      final response = await http.post(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/users/update_member_skills/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'uid': memberUid, 'skills': updatedSkills}),
      );

      if (response.statusCode == 200) {
        setState(() {
          final idx = _allMembers.indexWhere((m) => m['uid'] == memberUid);
          if (idx != -1) {
            _allMembers[idx]['skills_services'] = updatedSkills;
          }
        });
        Api().showMessage(
          context,
          'Skills updated successfully.',
          'Success',
          Colors.green,
        );
      } else {
        final respBody = json.decode(response.body);
        Api().showMessage(
          context,
          respBody['error'] ?? 'Failed to save skills.',
          'Error',
          Colors.red,
        );
      }
    } catch (e) {
      print('Error saving skills: $e');
      Api().showMessage(context, 'Error: $e', 'Error', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- 3. FILTERING ---
  // ONLY returns members who ALREADY have skills assigned to them
  List<dynamic> get _filteredMembersWithSkills {
    final membersWithSkills = _allMembers.where((m) {
      final skills = m['skills_services'] as List? ?? [];
      return skills.isNotEmpty;
    }).toList();

    if (_searchQuery.isEmpty) return membersWithSkills;

    return membersWithSkills.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final surname = (m['surname'] ?? '').toString().toLowerCase();
      final fullName = "$name $surname";

      final skills = m['skills_services'] as List? ?? [];
      bool matchesSkill = skills.any((s) {
        final title = (s['title'] ?? '').toString().toLowerCase();
        final desc = (s['description'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery) || desc.contains(_searchQuery);
      });

      return fullName.contains(_searchQuery) || matchesSkill;
    }).toList();
  }

  // --- 4. DIALOGS ---
  void _showAddEditSkillDialog(Map<String, dynamic> member, {int? skillIndex}) {
    final isEditing = skillIndex != null;
    final List<dynamic> currentSkills = List.from(
      member['skills_services'] ?? [],
    );

    final _titleController = TextEditingController();
    final _descController = TextEditingController();
    final _linkController = TextEditingController();

    if (isEditing) {
      final skill = currentSkills[skillIndex];
      _titleController.text = skill['title'] ?? '';
      _descController.text = skill['description'] ?? '';
      _linkController.text = skill['link'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Api().neumoBaseColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEditing ? 'Edit Service/Skill' : 'Add Service/Skill',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[900],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Assigning to: ${member['name']} ${member['surname']}",
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title (e.g., Plumber, Developer)*',
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: InputDecoration(labelText: 'Description (Optional)'),
              maxLines: 2,
            ),
            SizedBox(height: 8),
            TextField(
              controller: _linkController,
              decoration: InputDecoration(labelText: 'Website/Link (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final title = _titleController.text.trim();
              if (title.isEmpty) {
                Api().showMessage(
                  context,
                  "Title is required",
                  "Validation",
                  Colors.orange,
                );
                return;
              }

              final newSkill = {
                'title': title,
                'description': _descController.text.trim(),
                'link': _linkController.text.trim(),
              };

              if (isEditing) {
                currentSkills[skillIndex] = newSkill;
              } else {
                currentSkills.add(newSkill);
              }

              Navigator.pop(context);
              _saveSkillsForMember(member['uid'], currentSkills);
            },
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Opens a searchable list of ALL members so you can assign a skill to someone who doesn't have one yet
  void _showSelectMemberDialog() {
    TextEditingController _dialogSearchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final query = _dialogSearchController.text.toLowerCase();
            final displayedMembers = _allMembers.where((m) {
              final fullName = "${m['name'] ?? ''} ${m['surname'] ?? ''}"
                  .toLowerCase();
              return fullName.contains(query);
            }).toList();

            return Dialog(
              backgroundColor: Api().neumoBaseColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: widget.isLargeScreen
                    ? 500
                    : MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Select Member to Assign Service",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _dialogSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: "Search all members...",
                        prefixIcon: Icon(CupertinoIcons.search),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        physics: BouncingScrollPhysics(),
                        itemCount: displayedMembers.length,
                        itemBuilder: (context, index) {
                          final member = displayedMembers[index];
                          final fullName =
                              "${member['name'] ?? ''} ${member['surname'] ?? ''}"
                                  .trim();
                          final elder =
                              member['district_elder_name'] ??
                              member['districtElderName'] ??
                              'Unassigned';

                          // Secure face loading
                          final faceUrlRaw =
                              member['face_image_url'] ??
                              member['face_url'] ??
                              member['profile_url'];
                          final secureFace = _getSecureImageUrl(faceUrlRaw);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              backgroundImage: secureFace.isNotEmpty
                                  ? NetworkImage(secureFace)
                                  : null,
                              child: secureFace.isEmpty
                                  ? Text(
                                      fullName.isNotEmpty ? fullName[0] : '?',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              fullName,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Elder: $elder",
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: Icon(
                              CupertinoIcons.add_circled_solid,
                              color: Theme.of(context).primaryColor,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showAddEditSkillDialog(member);
                            },
                          );
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Close"),
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

  // --- 5. PDF EXPORT (ALL MEMBERS WITH SKILLS - COMPACT) ---
  static pw.Widget _buildHeader(pw.Font font, Uint8List? logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        if (logo != null)
          pw.Container(
            width: 100,
            height: 100,
            margin: const pw.EdgeInsets.only(right: 15),
            child: pw.Image(pw.MemoryImage(logo)),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                "The Twelve Apostles Church in Trinity",
                style: pw.TextStyle(font: font, fontSize: 22),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                "P. O. Box 40376, Red Hill, 4071",
                style: pw.TextStyle(fontSize: 14, font: font),
              ),
              pw.Text(
                "Tel. / Fax No's: (031) 569 6164",
                style: pw.TextStyle(fontSize: 14, font: font),
              ),
              pw.Text(
                "Email: thetacc@telkomsa.net",
                style: const pw.TextStyle(fontSize: 14, color: PdfColors.blue),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportAllMembersPdf() async {
    if (_filteredMembersWithSkills.isEmpty) {
      Api().showMessage(
        context,
        "No members to export.",
        "Info",
        Colors.orange,
      );
      return;
    }

    Api().showMessage(
      context,
      "Generating Skills Directory PDF...",
      "Processing",
      Colors.blue,
    );

    try {
      final pdf = pw.Document();
      final ttf = await rootBundle.load('assets/CloisterBlack.ttf');
      final font = pw.Font.ttf(ttf);

      Uint8List? logoBytes;
      try {
        final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
        logoBytes = bytes.buffer.asUint8List();
      } catch (_) {}

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          build: (pw.Context pdfContext) {
            return [
              _buildHeader(font, logoBytes),
              pw.SizedBox(height: 15),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  "MEMBER SKILLS & SERVICES DIRECTORY",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
              pw.SizedBox(height: 15),

              // Compact layout to easily fit 60+ members without taking too many pages
              ..._filteredMembersWithSkills.map((member) {
                final String fullName =
                    "${member['name'] ?? ''} ${member['surname'] ?? ''}".trim();
                final String phone = member['phone'] ?? 'N/A';
                final String email = member['email'] ?? 'N/A';
                final String districtElder =
                    member['district_elder_name'] ??
                    member['districtElderName'] ??
                    'Unassigned';
                final List<dynamic> skills = member['skills_services'] ?? [];

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Column: Personal Information
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              fullName,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              "D/E: $districtElder",
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey800,
                              ),
                            ),
                            pw.Text(
                              "Cell: $phone",
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey800,
                              ),
                            ),
                            pw.Text(
                              "Email: $email",
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right Column: Skills & Services list
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: skills.map((s) {
                            final title = s['title'] ?? 'Untitled';
                            final desc =
                                (s['description'] != null &&
                                    s['description']
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                ? " - ${s['description']}"
                                : "";
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 3),
                              child: pw.Text(
                                "$title$desc",
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ];
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final String fileName = 'TACT_Skills_Directory.pdf';

      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'TACT Skills Directory');
      } catch (shareErr) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } catch (e) {
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }

  // --- 6. UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    final neumoBase = Api().neumoBaseColor(context);
    final primaryColor = Theme.of(context).primaryColor;

    if (_isLoading && _allMembers.isEmpty) {
      return Center(child: CupertinoActivityIndicator(radius: 16));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.briefcase_fill,
                    color: primaryColor,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Skills Directory',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _exportAllMembersPdf,
                    icon: Icon(
                      CupertinoIcons.doc_text_fill,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      "Export List",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showSelectMemberDialog,
            icon: Icon(CupertinoIcons.add, color: Colors.white, size: 18),
            label: Text(
              "Assign Service",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          SizedBox(height: 10),
          // Search Bar
          NeumorphicContainer(
            color: neumoBase,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                icon: Icon(CupertinoIcons.search, color: primaryColor),
                hintText: "Search by Name, Surname, or Service...",
                border: InputBorder.none,
              ),
            ),
          ),
          SizedBox(height: 24),

          // Box Cards Grid / List
          Expanded(
            child: _filteredMembersWithSkills.isEmpty
                ? Center(
                    child: Text(
                      "No members with assigned services found.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    physics: BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.isLargeScreen
                          ? 2
                          : 1, // 2 columns on desktop, 1 on mobile
                      mainAxisExtent:
                          220, // Fixed height for beautiful box cards
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredMembersWithSkills.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembersWithSkills[index];
                      final String fullName =
                          "${member['name'] ?? ''} ${member['surname'] ?? ''}"
                              .trim();
                      final String email = member['email'] ?? 'N/A';
                      final String phone = member['phone'] ?? 'N/A';
                      final String elder =
                          member['district_elder_name'] ??
                          member['districtElderName'] ??
                          'Unassigned';
                      final List<dynamic> skills =
                          member['skills_services'] ?? [];

                      // Secure Face Image
                      final faceUrlRaw =
                          member['face_image_url'] ??
                          member['face_url'] ??
                          member['profile_url'];
                      final secureFace = _getSecureImageUrl(faceUrlRaw);

                      return NeumorphicContainer(
                        color: neumoBase,
                        borderRadius: 20,
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Profile Section
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: primaryColor.withOpacity(
                                    0.15,
                                  ),
                                  backgroundImage: secureFace.isNotEmpty
                                      ? NetworkImage(secureFace)
                                      : null,
                                  child: secureFace.isEmpty
                                      ? Text(
                                          fullName.isNotEmpty
                                              ? fullName[0].toUpperCase()
                                              : "?",
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24,
                                          ),
                                        )
                                      : null,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fullName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blueGrey[900],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.person_3_fill,
                                            size: 12,
                                            color: Colors.blueGrey[400],
                                          ),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              elder,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blueGrey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // Contact Details
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.phone_fill,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 6),
                                Text(
                                  phone,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(width: 16),
                                Icon(
                                  CupertinoIcons.mail_solid,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[800],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            Spacer(),
                            Divider(color: Colors.grey[300]),

                            // Bottom Service Tags
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: BouncingScrollPhysics(),
                                    child: Row(
                                      children: skills
                                          .map(
                                            (s) => Container(
                                              margin: EdgeInsets.only(right: 8),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: primaryColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: primaryColor
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                s['title'] ?? 'Service',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    CupertinoIcons.pencil_circle_fill,
                                    color: primaryColor,
                                    size: 28,
                                  ),
                                  onPressed: () =>
                                      _showManageServicesDialog(member),
                                  tooltip: "Manage Services",
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Dialog to view, edit, or delete existing services for a member who is already in the directory
  void _showManageServicesDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final List<dynamic> skills = member['skills_services'] ?? [];
            final String fullName =
                "${member['name'] ?? ''} ${member['surname'] ?? ''}".trim();

            return Dialog(
              backgroundColor: Api().neumoBaseColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: widget.isLargeScreen
                    ? 500
                    : MediaQuery.of(context).size.width * 0.9,
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Manage Services for $fullName",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            CupertinoIcons.add_circled_solid,
                            color: Theme.of(context).primaryColor,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddEditSkillDialog(member);
                          },
                        ),
                      ],
                    ),
                    Divider(),
                    if (skills.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          "No services found.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: skills.length,
                          itemBuilder: (ctx, i) {
                            final s = skills[i];
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                title: Text(
                                  s['title'] ?? 'Untitled',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle:
                                    s['description'] != null &&
                                        s['description'].toString().isNotEmpty
                                    ? Text(
                                        s['description'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12),
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        CupertinoIcons.pencil,
                                        color: Colors.blueGrey,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showAddEditSkillDialog(
                                          member,
                                          skillIndex: i,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Close"),
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
}
