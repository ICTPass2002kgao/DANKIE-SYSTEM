// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/NeuDesign.dart'; // ⭐️ IMPORTED

class OverseerAuditpage extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;

  const OverseerAuditpage({
    super.key,
    this.committeeMemberName,
    this.committeeMemberRole,
    this.faceUrl,
    this.isLargeScreen = true,
  });

  @override
  State<OverseerAuditpage> createState() => _OverseerAuditpageState();
}

class _OverseerAuditpageState extends State<OverseerAuditpage> {
  // --- Style Constants ---
  final Color baseColor = const Color(0xFFE0E5EC); // Neumorphic base
  final Color primaryColor = const Color(0xFF1976D2);
  final Color successGreen = const Color(0xFF388E3C);
  final Color errorRed = const Color(0xFFD32F2F);

  List<dynamic> _auditLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAuditLogs();
  }

  // Inside _OverseerAuditpageState class

  Future<void> _fetchAuditLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoading = true);

      final String token = await user.getIdToken() ?? '';

      // ⭐️ FIX: Added '&t=' with a current timestamp to bypass browser caching
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/audit_logs/?uid=${user.uid}&t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache', // Explicitly tell the system no caching
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        // Backend handles order_by('-timestamp'), but we sort again
        // in frontend just to be 100% safe.
        data.sort(
          (a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''),
        );

        if (mounted) {
          setState(() {
            _auditLogs = data;
            _isLoading = false;
          });
        }
      } else {
        print("Error fetching logs: ${response.statusCode}");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Network error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getSecureImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty || originalUrl == 'N/A')
      return "";
    return originalUrl.startsWith('http')
        ? originalUrl
        : '${Api().BACKEND_BASE_URL_DEBUG}$originalUrl';
  }

  Future<void> _generateAndDownloadPdf() async {
    final pdf = pw.Document();
    final data = _auditLogs;
    final logoImage = await rootBundle.load('assets/dankie_logo.PNG');
    final logoProvider = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Use your specific App Color
    final pdfPrimaryColor = PdfColor.fromInt(primaryColor.value);

    List<List<dynamic>> pdfRows = [];
    for (var d in data) {
      String dateStr = d['timestamp'] != null
          ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(d['timestamp']))
          : '-';
      // Removed university_name (Area) from this list
      pdfRows.add([
        dateStr,
        d['actor_name'] ?? '-',
        d['action'] ?? '-',
        d['details'] ?? '-',
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4, // PORTRAIT
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "AUDIT REPORT",
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfPrimaryColor,
                        ),
                      ),
                      pw.Text(
                        "Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  // ⭐️ Circular Logo
                  pw.ClipRRect(
                    child: pw.Image(logoProvider, width: 60, height: 60),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: const {
                  0: pw.FixedColumnWidth(80), // Time
                  1: pw.FixedColumnWidth(90), // Actor
                  2: pw.FixedColumnWidth(80), // Action
                  3: pw.FlexColumnWidth(1), // Details
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: pdfPrimaryColor),
                    children: ['Time', 'Actor', 'Action', 'Details'].map((
                      text,
                    ) {
                      return pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          text,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  ...data.asMap().entries.map((entry) {
                    int idx = entry.key;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: idx % 2 == 0
                            ? PdfColors.grey100
                            : PdfColors.white,
                      ),
                      children: pdfRows[idx]
                          .map(
                            (cell) => pw.Padding(
                              padding: pw.EdgeInsets.all(6),
                              child: pw.Text(
                                cell.toString(),
                                style: pw.TextStyle(fontSize: 9),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }).toList(),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Audit_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );

    OverseerAuditLogs.logAction(
      action: "EXPORTED",
      details: "Downloaded Audit Log PDF",
      committeeMemberName: widget.committeeMemberName,
      committeeMemberRole: widget.committeeMemberRole,
      universityCommitteeFace: widget.faceUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header Card
            NeumorphicContainer(
              color: baseColor,
              borderRadius: 15,
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Audit Logs",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          "Track committee actions and system updates.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _generateAndDownloadPdf,
                    child: NeumorphicContainer(
                      color: primaryColor,
                      borderRadius: 10,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        "Export PDF",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Table Container
            NeumorphicContainer(
              color: baseColor,
              borderRadius: 15,
              padding: EdgeInsets.all(20),
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('TIME')),
                          DataColumn(label: Text('ACTOR')),
                          DataColumn(label: Text('AREA')),
                          DataColumn(label: Text('ACTION')),
                          DataColumn(label: Text('DETAILS')),
                        ],
                        rows: _auditLogs.map((data) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat(
                                    'MMM dd, HH:mm',
                                  ).format(DateTime.parse(data['timestamp'])),
                                ),
                              ),
                              DataCell(Text(data['actor_name'] ?? '-')),
                              DataCell(Text(data['university_name'] ?? '-')),
                              DataCell(
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getActionColor(
                                      data['action'],
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    data['action'] ?? '',
                                    style: TextStyle(
                                      color: _getActionColor(data['action']),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(data['details'] ?? '-')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(dynamic action) {
    final String act = (action ?? '').toString().toUpperCase();
    if (act.contains('CREATE') ||
        act.contains('UPDATE') ||
        act.contains('ARCHIVED'))
      return successGreen;
    if (act.contains('DELETE') || act.contains('REJECT')) return errorRed;
    return primaryColor;
  }
}
