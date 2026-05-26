// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Components/Aduit_Logs/Tactso_Audit_Logs.dart';

class ApplicationsTab extends StatefulWidget {
  final String branchId;
  final Color neumoColor;
  final String universityName;
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? faceUrl;
  final String? universityLogoUrl;

  const ApplicationsTab({
    Key? key,
    required this.branchId,
    required this.neumoColor,
    required this.universityName,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.faceUrl,
    this.universityLogoUrl,
  }) : super(key: key);

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  Future<List<dynamic>>? _applicationsFuture;
  final List<String> _applicationStatuses = [
    'New',
    'Reviewed',
    'Application Submitted',
    'Rejected',
  ];

  Color get _primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  void _fetchApplications() {
    setState(() {
      _applicationsFuture = _getApplicationsData();
    });
  }

  Future<List<dynamic>> _getApplicationsData() async {
    final user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();

    final response = await http.get(
      Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/applications/?branch=${widget.branchId}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      Api().showMessage(
        context,
        'Error',
        'Could not open document',
        Colors.red,
      );
    }
  }

  Future<void> _updateApplicationStatus({
    required String applicationId,
    required String newStatus,
    Map<String, dynamic>? applicationData,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final String? token = await user?.getIdToken();

      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/applications/$applicationId/',
      );
      final response = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        Api().showMessage(
          context,
          'Updated',
          'Status changed to $newStatus.',
          Colors.green,
        );

        if (applicationData != null && applicationData['email'] != null) {
          String userEmail = applicationData['email'];
          String userName = applicationData['full_name'] ?? 'Student';
          String program = applicationData['primary_program'] ?? 'N/A';
          String uniName = widget.universityName;
          String emailSubject = "Application Status Update: $uniName";

          await TactsoAuditLogs.logAction(
            action: "UPDATED_MEMBER_STATUS",
            details: "Updated $userName status to $newStatus",
            referenceId: applicationId,
            universityName: widget.universityName,
            universityLogo: widget.universityLogoUrl,
            committeeMemberName: widget.loggedMemberName ?? "Education Officer",
            committeeMemberRole: widget.loggedMemberRole ?? "Education Officer",
            universityCommitteeFace: widget.faceUrl ?? "",
          );

          String emailBody =
              """
          <!DOCTYPE html>
          <html>
          <head>
          <style>
            body { font-family: 'Helvetica', 'Arial', sans-serif; background-color: #f4f4f9; padding: 20px; }
            .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
            .header { background-color: #003366; padding: 30px; text-align: center; color: white; }
            .header h1 { margin: 0; font-size: 22px; letter-spacing: 1px; }
            .content { padding: 30px; color: #333333; }
            .status-box { background-color: #e3f2fd; border-left: 5px solid #2196f3; padding: 15px; margin: 20px 0; border-radius: 4px; }
            .status-text { color: #0d47a1; font-weight: bold; font-size: 16px; text-transform: uppercase; }
            .info-table { width: 100%; border-collapse: collapse; margin: 25px 0; }
            .info-table th { text-align: left; padding: 10px; background-color: #f8f9fa; color: #666; font-size: 11px; text-transform: uppercase; border-bottom: 2px solid #eee; }
            .info-table td { padding: 12px 10px; border-bottom: 1px solid #eee; font-size: 14px; color: #333; }
            .disclaimer { background-color: #fff3e0; border: 1px solid #ffe0b2; color: #e65100; padding: 15px; border-radius: 8px; font-size: 13px; line-height: 1.5; margin-top: 25px; }
            .footer { background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 11px; color: #999; }
          </style>
          </head>
          <body>
            <div class="container">
              <div class="header"><h1>Application Update</h1><p style="margin: 5px 0 0 0; opacity: 0.9;">$uniName</p></div>
              <div class="content">
                <p>Dear <strong>$userName</strong>,</p>
                <p>This is a notification regarding your application facilitated by the Tactso branch committee.</p>
                <div class="status-box">Current Status: <span class="status-text">$newStatus</span></div>
                <h3>📝 Application Summary</h3>
                <table class="info-table">
                  <thead><tr><th>Institution</th><th>Program/Course</th></tr></thead>
                  <tbody><tr><td><strong>$uniName</strong></td><td>$program</td></tr></tbody>
                </table>
                <p style="font-size: 14px; line-height: 1.6;">We are pleased to inform you that your documents have been successfully forwarded to the university admissions department.</p>
                <div class="disclaimer">
                  <strong>⚠️ Important Note on Admission:</strong><br>
                  Please be aware that this submission <strong>does not guarantee admission</strong>. 
                  It confirms that the student committee has submitted your documents to the university on your behalf. 
                  The final decision rests solely with the University's Admissions Office based on their specific criteria and space availability.
                </div>
              </div>
              <div class="footer"><p>&copy; ${DateTime.now().year} Dankie App & Tactso Committee.</p><p>Track your status anytime in the Dankie App.</p></div>
            </div>
          </body>
          </html>
          """;
          Api().sendEmail(userEmail, emailSubject, emailBody, context);
        }
        _fetchApplications();
      }
    } catch (e) {
      Api().showMessage(context, 'Error', '$e', Colors.red);
    }
  }

  void _showDocsDialog(
    BuildContext context,
    dynamic docs, {
    required String studentName,
  }) {
    if (docs == null || docs is! Map) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Docs: $studentName", style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: docs.entries
                .map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.lock_open,
                      size: 18,
                      color: Colors.green,
                    ),
                    title: Text(e.key, style: TextStyle(fontSize: 14)),
                    onTap: () {
                      // Route through the Django backend view for instant decryption
                      String encryptedUrl = e.value;
                      String serveDecryptedUrl =
                          '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(encryptedUrl)}';
                      _launchUrl(serveDecryptedUrl);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    String currentStatus,
    String appId,
    Map<String, dynamic> data,
  ) {
    return DropdownButton<String>(
      value: _applicationStatuses.contains(currentStatus)
          ? currentStatus
          : null,
      underline: SizedBox(),
      icon: Icon(Icons.arrow_drop_down, size: 16),
      style: TextStyle(color: _primaryColor, fontSize: 12),
      isDense: true,
      items: _applicationStatuses
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      onChanged: (val) => _updateApplicationStatus(
        applicationId: appId,
        newStatus: val!,
        applicationData: data,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _applicationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CupertinoActivityIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.inbox, size: 40, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  "No applications received yet",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return NeumorphicContainer(
          color: widget.neumoColor,
          borderRadius: 12,
          padding: EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: MaterialStateProperty.all(
                Theme.of(context).primaryColor.withOpacity(0.1),
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    "Student Name",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Phone",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Gender",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Campus",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "1st Choice",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "2nd Choice",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "3rd Choice",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Highest Qual.",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Prev School",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Funding",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Residence",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Status",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Docs",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
              rows: snapshot.data!.map<DataRow>((data) {
                final name = data['full_name'] ?? 'Unknown';
                final email = data['email'] ?? '';
                final phone = data['phone'] ?? 'N/A';
                final gender = data['gender'] ?? 'N/A';
                final campus = data['campus'] ?? 'N/A';
                final primaryProgram = data['primary_program'] ?? 'N/A';
                final secondChoice = data['second_choice_program'] ?? 'N/A';
                final thirdChoice = data['third_choice_program'] ?? 'N/A';
                final highestQual = data['highest_qualification'] ?? 'N/A';
                final prevSchool = data['previous_school'] ?? 'N/A';
                final bool funding = data['applying_for_funding'] ?? false;
                final bool residence = data['applying_for_residence'] ?? false;
                final status = data['status'] ?? 'New';
                final id = data['id'].toString();

                Map<String, String> documents = {};
                if (data['id_passport_url'] != null &&
                    data['id_passport_url'].toString().isNotEmpty) {
                  documents['ID/Passport'] = data['id_passport_url'];
                }
                if (data['school_results_url'] != null &&
                    data['school_results_url'].toString().isNotEmpty) {
                  documents['School Results'] = data['school_results_url'];
                }
                if (data['proof_of_registration_url'] != null &&
                    data['proof_of_registration_url'].toString().isNotEmpty) {
                  documents['Proof of Reg'] = data['proof_of_registration_url'];
                }
                if (data['other_qualifications_url'] != null &&
                    data['other_qualifications_url'].toString().isNotEmpty) {
                  documents['Other Docs'] = data['other_qualifications_url'];
                }

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              email,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(phone, style: TextStyle(fontSize: 12))),
                    DataCell(Text(gender, style: TextStyle(fontSize: 12))),
                    DataCell(Text(campus, style: TextStyle(fontSize: 12))),
                    DataCell(
                      Text(primaryProgram, style: TextStyle(fontSize: 12)),
                    ),
                    DataCell(
                      Text(secondChoice, style: TextStyle(fontSize: 12)),
                    ),
                    DataCell(Text(thirdChoice, style: TextStyle(fontSize: 12))),
                    DataCell(Text(highestQual, style: TextStyle(fontSize: 12))),
                    DataCell(Text(prevSchool, style: TextStyle(fontSize: 12))),
                    DataCell(
                      Text(
                        funding ? "Yes" : "No",
                        style: TextStyle(
                          fontSize: 12,
                          color: funding ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        residence ? "Yes" : "No",
                        style: TextStyle(
                          fontSize: 12,
                          color: residence ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                    DataCell(_buildStatusChip(status, id, data)),
                    DataCell(
                      IconButton(
                        icon: Icon(Icons.folder_open, color: _primaryColor),
                        onPressed: () => _showDocsDialog(
                          context,
                          documents,
                          studentName: name,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
