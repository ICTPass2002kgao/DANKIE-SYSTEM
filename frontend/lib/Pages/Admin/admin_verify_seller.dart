// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class AdminVerifySeller extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;

  const AdminVerifySeller({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<AdminVerifySeller> createState() => _AdminVerifySellerState();
}

class _AdminVerifySellerState extends State<AdminVerifySeller> {
  Future<Map<String, String>> _getAuthHeaders() async {
    final String token =
        await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Secure URL Wrapper for Encrypted Documents
  String _getSecureImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.endsWith('.enc') || url.contains('.enc?')) {
      return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  Future<List<dynamic>> _fetchAllSellers() async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/?role=Seller');
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> allUsers = json.decode(response.body);
      return allUsers;
    } else {
      throw Exception('Failed to load sellers: ${response.statusCode}');
    }
  }

  Future<void> _approveSeller(String uid, Map<String, dynamic> userData) async {
    Api().showLoading(context);
    try {
      final headers = await _getAuthHeaders();
      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/$uid/');
      final response = await http.patch(
        uri,
        headers: headers,
        body: json.encode({
          'account_verified': true,
          'verification_status': 'Verified',
        }),
      );

      // ⭐️ SAFETY FIX: Prevents "deactivated widget ancestor" crash
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // Refresh List
        Api().sendEmail(
          userData['email'] ?? '',
          "✅ Account Approved",
          "<p>Your seller account is approved and bound by the signed agreement.</p>",
          context,
        );
      } else {
        throw Exception('Update failed: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve seller: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================================
  // PDF GENERATION & STRICT CONTRACT LOGIC
  // ============================================================================
  // ============================================================================
  // ⭐️ PREMIUM PDF GENERATION & STRICT CONTRACT LOGIC
  // ============================================================================
  Future<void> _generateAndDownloadContract(Map<String, dynamic> user) async {
    Api().showLoading(context);
    try {
      final pdf = pw.Document();

      // 1. Fetch decrypted signature
      pw.MemoryImage? signatureImage;
      final String? sigUrlRaw = user['contract_signature_url'];

      if (sigUrlRaw != null && sigUrlRaw.isNotEmpty) {
        final secureSigUrl = _getSecureImageUrl(sigUrlRaw);
        final headers = await _getAuthHeaders();
        final response = await http.get(
          Uri.parse(secureSigUrl),
          headers: headers,
        );
        if (response.statusCode == 200) {
          signatureImage = pw.MemoryImage(response.bodyBytes);
        }
      }

      // 2. Load the Dankie Logo from Assets
      pw.MemoryImage? logoImage;
      try {
        final ByteData bytes = await rootBundle.load('assets/dankie_logo.PNG');
        logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (e) {
        print("Logo not found: $e");
      }

      // 3. Format Timestamp
      final String timeStampStr =
          user['updated_at'] ?? DateTime.now().toIso8601String();
      final DateTime timestamp = DateTime.parse(timeStampStr).toLocal();
      final String formattedDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(timestamp);

      // 4. User Details Extraction
      final String fullName = "${user['name'] ?? ''} ${user['surname'] ?? ''}"
          .trim();
      final String idNumber = user['uid'] ?? 'N/A';
      final String phone = user['phone'] ?? 'N/A';
      final String community = user['community_name'] ?? 'N/A';
      final String districtElder = user['district_elder_name'] ?? 'N/A';
      final String overseerName = user['overseer_name'] ?? 'N/A';
      final String overseerRegion = user['overseer_region'] ?? 'N/A';

      // 5. Build Premium PDF Layout
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [
            _buildPdfHeader(logoImage),
            pw.SizedBox(height: 25),
            _buildPdfUserDetails(
              fullName,
              phone,
              community,
              districtElder,
              overseerName,
              overseerRegion,
              idNumber,
            ),
            pw.SizedBox(height: 25),
            _buildPdfLegalClauses(fullName),
            pw.SizedBox(height: 40),
            _buildPdfSignatureSection(signatureImage, formattedDate, fullName),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);  
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Dankie_Seller_Contract_${user['name']}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      Api().showMessage(
        context,
        "Error generating contract: $e",
        "PDF Error",
        Colors.red,
      );
    }
  }

  pw.Widget _buildPdfHeader(pw.MemoryImage? logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null) pw.Image(logo, height: 60),
        if (logo != null) pw.SizedBox(height: 15),
        pw.Text(
          "DANKIE PLATFORM",
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
            letterSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          "SELLER ACCOUNTABILITY & SERVICE LEVEL AGREEMENT",
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
        pw.SizedBox(height: 5),
        pw.Text(
          "CONFIDENTIAL & LEGALLY BINDING DOCUMENT",
          style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.red800,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfUserDetails(
    String name,
    String phone,
    String community,
    String elder,
    String overseer,
    String region,
    String uid,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue900, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Dark Header for the table
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: PdfColors.blue900,
            child: pw.Text(
              "PARTICULARS OF THE SELLER",
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          // Two-column layout for details
          pw.Padding(
            padding: const pw.EdgeInsets.all(15),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfDetailRow("Full Name:", name),
                      pw.SizedBox(height: 8),
                      _pdfDetailRow("System UID:", uid),
                      pw.SizedBox(height: 8),
                      _pdfDetailRow("Phone:", phone),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfDetailRow("Community/Branch:", community),
                      pw.SizedBox(height: 8),
                      _pdfDetailRow("District Elder:", elder),
                      pw.SizedBox(height: 8),
                      _pdfDetailRow(
                        "Overseer & Region:",
                        "$overseer ($region)",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfDetailRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  pw.Widget _buildPdfLegalClauses(String name) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "TERMS OF AGREEMENT AND STRICT FRAUD LIABILITY",
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Text(
          "I, $name, hereby acknowledge and legally bind myself to the following conditions of operating as a verified seller on the Dankie Platform:",
          textAlign: pw.TextAlign.justify,
          style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
        ),
        pw.SizedBox(height: 15),

        _pdfClause(
          "1. GUARANTEE OF SERVICE:",
          "I declare under penalty of perjury that I possess the goods and services I am listing. I commit to fulfilling all orders placed and paid for by customers promptly.",
        ),
        _pdfClause(
          "2. FRAUD AND SCAM ACCOUNTABILITY:",
          "I understand that listing phantom products, failing to deliver paid goods, or engaging in any form of scam is a direct violation of the law. Should I fail to provide the promised service, I accept full legal and financial liability.",
        ),
        _pdfClause(
          "3. PLATFORM RIGHTS & LAW ENFORCEMENT:",
          "The platform reserves the right to immediately suspend my account, freeze payouts, and hand over my provided ID Document, Face Image, and this digitally signed contract to law enforcement agencies in the event of fraud.",
        ),
        _pdfClause(
          "4. REIMBURSEMENT & RECOVERY:",
          "In the event of a dispute where I am found at fault, I authorize the platform to deduct funds from my Paystack subaccount or pursue legal channels to reimburse the affected parties without prior notice.",
        ),
      ],
    );
  }

  pw.Widget _pdfClause(String title, String body) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          style: const pw.TextStyle(
            fontSize: 11,
            color: PdfColors.black,
            lineSpacing: 1.5,
          ),
          children: [
            pw.TextSpan(
              text: "$title ",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: body),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfSignatureSection(
    pw.MemoryImage? signature,
    String timestamp,
    String name,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "ELECTRONIC SIGNATURE & VERIFICATION",
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            "By signing this document electronically, the seller agrees that this signature holds the exact same legal weight as a physical handwritten signature.",
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Signature Area
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    height: 70,
                    width: 200,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(
                        color: PdfColors.grey400,
                        style: pw.BorderStyle.dashed,
                      ),
                    ),
                    child: signature != null
                        ? pw.Image(signature, fit: pw.BoxFit.contain)
                        : pw.Center(
                            child: pw.Text(
                              "Signature securely withheld or missing",
                              style: pw.TextStyle(
                                color: PdfColors.red,
                                fontSize: 10,
                              ),
                            ),
                          ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    "Signed By: $name",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Signed on: $timestamp",
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),

              // Official Stamp
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.red900, width: 2),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      "DANKIE PLATFORM",
                      style: pw.TextStyle(
                        color: PdfColors.red900,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "VERIFIED",
                      style: pw.TextStyle(
                        color: PdfColors.red900,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "LEGALLY BINDING",
                      style: pw.TextStyle(color: PdfColors.red900, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  void _showApprovalDialog(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Seller'),
        content: Text(
          'Are you sure you want to approve ${user['name']}? Ensure you have reviewed their contract.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _approveSeller(user['uid'], user);
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _openDocumentViewer(BuildContext context, String title, String url) {
    if (url.isEmpty) {
      Api().showMessage(
        context,
        "No document provided.",
        "Not Found",
        Colors.orange,
      );
      return;
    }

   
  }

  void _showSellerDetailsSheet(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final theme = Theme.of(context);
    final String? profile = data['face_image_url'] ?? data['profile_url'];
    final String? idDoc = data['id_document_url'];
    final bool isVerified = data['account_verified'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: (profile != null && profile.isNotEmpty)
                  ? NetworkImage(_getSecureImageUrl(profile))
                  : null,
              child: (profile == null || profile.isEmpty)
                  ? Icon(Icons.person, size: 40)
                  : null,
            ),
            SizedBox(height: 12),
            Text(
              '${data['name']} ${data['surname']}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),

            Container(
              margin: EdgeInsets.only(top: 5),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isVerified
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                data['verification_status'] ??
                    (isVerified ? 'Verified' : 'Unverified'),
                style: TextStyle(
                  color: isVerified ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Divider(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNeumorphicInfoRow(
                      Icons.phone,
                      'Phone',
                      data['phone'],
                    ),
                    const SizedBox(height: 10),
                    _buildNeumorphicInfoRow(
                      Icons.location_city,
                      'Community',
                      data['community_name'],
                    ),
                    const SizedBox(height: 10),
                    _buildNeumorphicInfoRow(
                      Icons.person_pin,
                      'Elder',
                      data['district_elder_name'],
                    ),
                    const SizedBox(height: 10),
                    _buildNeumorphicInfoRow(
                      Icons.admin_panel_settings,
                      'Overseer',
                      data['overseer_name'],
                    ),
                    const SizedBox(height: 10),
                    _buildNeumorphicInfoRow(
                      Icons.map,
                      'Region',
                      data['overseer_region'],
                    ),
                    const SizedBox(height: 25),

                    Text(
                      "Legal & Documents",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 15),

                    GestureDetector(
                      onTap: () => _generateAndDownloadContract(data),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(15),
                        decoration: NeumorphicUtils.decoration(context: context)
                            .copyWith(
                              color: theme.primaryColor.withOpacity(0.1),
                              border: Border.all(color: theme.primaryColor),
                            ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Download Legal Contract",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                            Icon(Icons.download, color: theme.primaryColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildDocButton(
                      "View Uploaded ID",
                      idDoc,
                      () => _openDocumentViewer(context, "ID Document", idDoc!),
                    ),
                    const SizedBox(height: 30),

                    if (!isVerified)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showApprovalDialog(context, data);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: NeumorphicUtils.decoration(
                            context: context,
                          ).copyWith(color: theme.primaryColor),
                          child: const Center(
                            child: Text(
                              "Approve Seller",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicInfoRow(IconData icon, String label, dynamic value) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: NeumorphicUtils.decoration(context: context, isPressed: true),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
                Text(
                  value?.toString() ?? 'N/A',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocButton(String title, String? url, VoidCallback onTap) {
    bool hasDoc = url != null && url.isNotEmpty;
    return GestureDetector(
      onTap: hasDoc ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(15),
        decoration: NeumorphicUtils.decoration(context: context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasDoc ? Colors.black : Colors.grey,
              ),
            ),
            Icon(
              hasDoc ? Icons.remove_red_eye : Icons.error,
              color: hasDoc ? Theme.of(context).primaryColor : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<dynamic> sellers) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.all(15),
          decoration: NeumorphicUtils.decoration(context: context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                Theme.of(context).primaryColor.withOpacity(0.1),
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    'Full Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Community',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'District Elder',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Overseer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: sellers.map((data) {
                final bool isVerified = data['account_verified'] ?? false;
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundImage: (data['profile_url'] != null)
                                ? NetworkImage(
                                    _getSecureImageUrl(data['profile_url']),
                                  )
                                : null,
                            child: (data['profile_url'] == null)
                                ? Icon(Icons.person, size: 15)
                                : null,
                          ),
                          SizedBox(width: 10),
                          Text('${data['name']} ${data['surname']}'),
                        ],
                      ),
                    ),
                    DataCell(Text(data['community_name'] ?? 'N/A')),
                    DataCell(Text(data['district_elder_name'] ?? 'N/A')),
                    DataCell(Text(data['overseer_name'] ?? 'N/A')),
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['verification_status'] ??
                              (isVerified ? 'Verified' : 'Pending'),
                          style: TextStyle(
                            color: isVerified ? Colors.green : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _showSellerDetailsSheet(context, data),
                        icon: Icon(Icons.visibility, size: 16),
                        label: Text("Review"),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<dynamic> sellers) {
    return ListView.builder(
      padding: EdgeInsets.all(15),
      itemCount: sellers.length,
      itemBuilder: (context, index) {
        final data = sellers[index];
        final bool isVerified = data['account_verified'] ?? false;

        return GestureDetector(
          onTap: () => _showSellerDetailsSheet(context, data),
          child: Container(
            margin: EdgeInsets.only(bottom: 15),
            padding: EdgeInsets.all(15),
            decoration: NeumorphicUtils.decoration(context: context),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: (data['profile_url'] != null)
                      ? NetworkImage(_getSecureImageUrl(data['profile_url']))
                      : null,
                  child: (data['profile_url'] == null)
                      ? Icon(Icons.person)
                      : null,
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['name']} ${data['surname']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        data['verification_status'] ??
                            (isVerified ? 'Verified' : 'Pending'),
                        style: TextStyle(
                          color: isVerified ? Colors.green : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).primaryColor,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchAllSellers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        final sellers = snapshot.data ?? [];
        if (sellers.isEmpty)
          return const Center(child: Text('No sellers found in the system.'));

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 850) {
              return _buildDesktopTable(sellers);
            } else {
              return _buildMobileList(sellers);
            }
          },
        );
      },
    );
  }
}

// ============================================================================
// ⭐️ PREMIUM DOCUMENT PREVIEW SCREEN (PDF & IMAGE SUPPORT)
// ============================================================================
 