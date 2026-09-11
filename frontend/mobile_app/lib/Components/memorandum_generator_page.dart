// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/tactso_pages/components/spiritual_pdf_generated.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class CircularGeneratorPage extends StatefulWidget {
  final String branchId;
  final String universityName;
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? universityLogoUrl;
  final Color neumoColor;

  const CircularGeneratorPage({
    Key? key,
    required this.branchId,
    required this.universityName,
    required this.neumoColor,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.universityLogoUrl,
  }) : super(key: key);

  @override
  State<CircularGeneratorPage> createState() => _CircularGeneratorPageState();
}

class _CircularGeneratorPageState extends State<CircularGeneratorPage> {
  final TextEditingController _subjectController = TextEditingController();
  final quill.QuillController _quillController = quill.QuillController.basic();
  bool _isLoading = false;
  List<dynamic> _committeeMembers = [];
  List<dynamic> _selectedMembers = [];
  bool _fetched = false;

  Color get _primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchCommittee();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _fetchCommittee() async {
    setState(() => _isLoading = true);
    try {
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
        setState(() {
          _committeeMembers = allMembers.where((member) {
            return member['branch'].toString() == widget.branchId.toString();
          }).toList();
          _fetched = true;
        });
      } else {
        setState(() {
          _fetched = true;
        });
      }
    } catch (e) {
      print("Error fetching committee: $e");
      setState(() {
        _fetched = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleMemberSelection(dynamic member) {
    setState(() {
      if (_selectedMembers.contains(member)) {
        _selectedMembers.remove(member);
      } else {
        if (_selectedMembers.length < 3) {
          _selectedMembers.add(member);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can only select exactly 3 committee members.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  Future<void> _generatePDF() async {
    if (_subjectController.text.trim().isEmpty ||
        _quillController.document.toPlainText().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter both subject and message.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_committeeMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No committee members found. Please add members first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedMembers.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select exactly 3 committee members for signatures.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Load logo
    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/tact_logo.PNG');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    // Fetch overseer signature (optional)
    Uint8List? signatureBytes;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      try {
        final res = await http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?uid=${user.uid}',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty) {
            final sigStr = data[0]['signature_base64'];
            if (sigStr != null && sigStr.isNotEmpty) {
              signatureBytes = base64Decode(sigStr);
            }
          }
        }
      } catch (_) {}
    }

    SpiritualPdfGenerator.generateCircularPDF(
      context: context,
      subject: _subjectController.text.trim(),
      messageJson: jsonEncode(_quillController.document.toDelta().toList()),
      committeeMembers: _selectedMembers,
      universityName: widget.universityName,
      universityLogoUrl: widget.universityLogoUrl,
      loggedMemberName: widget.loggedMemberName ?? 'Authorized Officer',
      loggedMemberRole: widget.loggedMemberRole ?? '',
      logoBytes: logoBytes,
      signatureBytes: signatureBytes,
    );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeumorphicContainer(
              color: widget.neumoColor,
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Compose Circular',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      hintText: 'Enter the subject of the circular',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.subject, color: _primaryColor),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Rich Text Editor Header
                  Text(
                    '  Message',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Quill Rich Text Editor
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        quill.QuillSimpleToolbar(
                          controller: _quillController,
                          config: const quill.QuillSimpleToolbarConfig(
                            showFontFamily: false,
                            showFontSize: false,
                            showColorButton: false,
                            showBackgroundColorButton: false,
                            showSearchButton: false,
                            showIndent: false,
                            showQuote: false,
                            showCodeBlock: false,
                            showInlineCode: false,
                            showSubscript: false,
                            showSuperscript: false,
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.grey[400],
                        ),
                        Container(
                          height: 200,
                          padding: const EdgeInsets.all(12),
                          child: quill.QuillEditor.basic(
                            controller: _quillController,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generatePDF,
                        icon: _isLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isLoading ? 'Generating...' : 'Generate PDF',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            if (_isLoading && !_fetched)
              Center(child: CupertinoActivityIndicator())
            else if (_fetched && _committeeMembers.isEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No committee members found. Please add members before generating a circular.',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              )
            else if (_fetched && _committeeMembers.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select Signatories (${_selectedMembers.length}/3)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please choose exactly 3 members who will serve on the signature fields.',
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey[600]),
                  ),
                  SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _committeeMembers.length,
                    itemBuilder: (context, index) {
                      final member = _committeeMembers[index];
                      final isSelected = _selectedMembers.contains(member);

                      return GestureDetector(
                        onTap: () => _toggleMemberSelection(member),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: NeumorphicContainer(
                            color: widget.neumoColor,
                            borderRadius: 12,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? _primaryColor
                                      : Colors.grey[400],
                                  size: 28,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member['full_name'] ??
                                            member['fullname'] ??
                                            member['name'] ??
                                            'Unknown Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blueGrey[800],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        member['portfolio'] ??
                                            member['role'] ??
                                            'No Portfolio Assigned',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blueGrey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
