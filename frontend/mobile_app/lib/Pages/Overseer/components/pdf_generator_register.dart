// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';

class OverseerPdfGenerator {
  // ---------------------------------------------------------------------------
  // HELPER: Extract role label
  // ---------------------------------------------------------------------------
  static String _getRoleLabel(Map<String, dynamic> user) {
    final isVis = user['isVisitor'] == true || user['is_visitor'] == true;
    if (!isVis) return 'Member';
    final category = user['visitor_category'] ?? '';
    final role = user['visitor_role'] ?? '';
    if (category == 'Mother' || category == 'Father') {
      return role.isNotEmpty && role != 'None' ? '$category ($role)' : category;
    }
    if (role.isNotEmpty && role != 'None') return role;
    return category.isEmpty ? 'Visitor' : category;
  }

  // ---------------------------------------------------------------------------
  // HELPER: Group by role
  // ---------------------------------------------------------------------------
  static Map<String, List<Map<String, dynamic>>> _groupByRole(
    List<dynamic> users,
  ) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var u in users) {
      final role = _getRoleLabel(u);
      groups.putIfAbsent(role, () => []).add(u);
    }
    return groups;
  }

  static Future<void> exportMemberListPDF({
    required BuildContext context,
    required List<dynamic> members,
    required String overseerName,
    required String regionName,
    required String loggerName,
    required String loggerRole,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
    String branchName = 'All Branches', // NEW
  }) async {
    final pdf = pw.Document();

    // Load font (use the same as your other reports)
    final ttf = await rootBundle.load('assets/CloisterBlack.ttf');
    final font = pw.Font.ttf(ttf);

    // Helper to capitalise names
    String capitalise(String? name) {
      if (name == null || name.isEmpty) return '';
      return name
          .split(' ')
          .map(
            (w) => w.isNotEmpty
                ? w[0].toUpperCase() + w.substring(1).toLowerCase()
                : '',
          )
          .join(' ');
    }

    // Prepare data rows: No., Name, Surname, Contact
    List<List<String>> rows = [];
    int index = 1;
    for (var member in members) {
      final name = capitalise(member['name']);
      final surname = capitalise(member['surname']);
      final contact = member['phone'] ?? member['contact'] ?? '';
      rows.add([index.toString(), name, surname, contact]);
      index++;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        build: (pw.Context context) {
          return [
            // ----- HEADER (reuse _buildHeader) -----
            _buildHeader(font, logoBytes),
            pw.SizedBox(height: 20),

            pw.Text(
              'MEMBERS REGISTER',
              style: pw.TextStyle(
                font: font,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Overseer: $overseerName  |  Region: $regionName',
              style: pw.TextStyle(fontSize: 12),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              // NEW: branch info
              'Branch: $branchName',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 20),

            // ----- TABLE (No., Name, Surname, Contact) -----
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30), // No.
                1: const pw.FlexColumnWidth(2), // Name
                2: const pw.FlexColumnWidth(2), // Surname
                3: const pw.FlexColumnWidth(2), // Contact
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('No.', font: font, bold: true),
                    _cell('Name', font: font, bold: true),
                    _cell('Surname', font: font, bold: true),
                    _cell('Contact', font: font, bold: true),
                  ],
                ),
                // Data
                ...rows.map((row) {
                  return pw.TableRow(
                    children: [
                      _cell(row[0], font: font),
                      _cell(row[1], font: font),
                      _cell(row[2], font: font),
                      _cell(row[3], font: font),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // ----- FOOTER with prepared by and signature (optional) -----
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Prepared by:', style: pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '$loggerName ($loggerRole)',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                if (signatureBytes != null)
                  pw.Container(
                    height: 30,
                    width: 80,
                    child: pw.Image(
                      pw.MemoryImage(signatureBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated on: ${DateTime.now().toLocal().toString().split(' ')[0]}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    await _sharePDF(
      context,
      bytes,
      'Member_List_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
    );
  }

  // ------------------------------------------------------------
  // Helper: cell widget
  // ------------------------------------------------------------
  static pw.Widget _cell(String text, {pw.Font? font, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          font: font,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ------------------------------------------------------------
  // Helper: share PDF
  // ------------------------------------------------------------

  static Future<void> _sharePDF(
    BuildContext context,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Member List PDF');
    } catch (e) {
      print('Error sharing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF. Please try again.')),
      );
    }
  }

  // ------------------------------------------------------------
  // Header widget (reused from financial reports)
  // ------------------------------------------------------------
  static pw.Widget _buildHeader(pw.Font font, Uint8List? logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        if (logo != null)
          pw.Container(
            width: 80,
            height: 80,
            margin: const pw.EdgeInsets.only(right: 15),
            child: pw.Image(pw.MemoryImage(logo)),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                "The Twelve Apostles Church in Trinity",
                style: pw.TextStyle(font: font, fontSize: 20),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                "P. O. Box 40376, Red Hill, 4071",
                style: pw.TextStyle(fontSize: 12, font: font),
              ),
              pw.Text(
                "Tel. / Fax No's: (031) 569 6164",
                style: pw.TextStyle(fontSize: 12, font: font),
              ),
              pw.Text(
                "Email: thetacc@telkomsa.net",
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.blue),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED DASHBOARD WIDGET
  // ---------------------------------------------------------------------------
  static pw.Widget buildPDFDashboardWidget({
    required int totalMembers,
    required int presentMembers,
    required int absentMembers,
    required int totalTestifies,
    required int readyTestifies,
    required int brothersPresent,
    required int brothersTotal,
    required int sistersPresent,
    required int sistersTotal,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16, top: 4),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "ATTENDANCE OVERVIEW",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  "Total: $totalMembers | Present: $presentMembers | Absent: $absentMembers",
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          pw.Container(
            width: 1,
            height: 30,
            color: PdfColors.grey300,
            margin: const pw.EdgeInsets.symmetric(horizontal: 12),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "GUESTS & TESTIFIES",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  "Total: $totalTestifies",
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange700,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Ready for Sealing: $readyTestifies",
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            width: 1,
            height: 30,
            color: PdfColors.grey300,
            margin: const pw.EdgeInsets.symmetric(horizontal: 12),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "GENDER ATTENDANCE",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Brothers", style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      "$brothersPresent / $brothersTotal",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Sisters", style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      "$sistersPresent / $sistersTotal",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.pink700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ROLE SUMMARY TABLE
  // ---------------------------------------------------------------------------
  static pw.Widget _buildRoleSummaryTable(Map<String, int> roleCounts) {
    if (roleCounts.isEmpty) return pw.SizedBox();
    var sorted = roleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Text(
          "ROLE BREAKDOWN (COUNTS)",
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          headerDecoration: pw.BoxDecoration(color: PdfColors.blue900),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 8,
            color: PdfColors.white,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Role', 'Present'],
          data: sorted
              .map((entry) => [entry.key, entry.value.toString()])
              .toList(),
        ),
      ],
    );
  }

  // =========================================================================
  // 1. DAILY REGISTER EXPORT (REDESIGNED – ONLY PRESENT ATTENDEES)
  // =========================================================================
  static Future<void> exportRegisterToPDF({
    required BuildContext context,
    required String filterType,
    required Map<String, List<dynamic>> groupedUsersByDistrict,
    required String overseerName,
    required String regionName,
    required String loggerName,
    required String loggerRole,
    required Uint8List? signatureBytes,
    required int totalMembers,
    required int presentMembers,
    required int absentMembers,
    required int totalTestifies,
    required int readyTestifies,
    required int brothersPresent,
    required int brothersTotal,
    required int sistersPresent,
    required int sistersTotal,
    String branchName = 'All Branches', // NEW
  }) async {
    // --- Helper predicates ---
    bool isParent(dynamic u) =>
        u['visitor_category'] == 'Mother' || u['visitor_category'] == 'Father';
    bool isMale(dynamic g) => g != null && g.toString().toLowerCase() == 'male';
    bool isFemale(dynamic g) =>
        g != null && g.toString().toLowerCase() == 'female';
    bool isVis(dynamic u) => u['isVisitor'] == true || u['is_visitor'] == true;

    // --- Load logo ---
    pw.MemoryImage? localLogoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final pdf = pw.Document();

    // --- Date strings ---
    final String fullDate = DateFormat(
      'EEEE, dd MMMM yyyy',
    ).format(DateTime.now());
    final String timestamp = DateFormat('HH:mm').format(DateTime.now());

    // --- Flatten all users ---
    final allUsers = groupedUsersByDistrict.values
        .expand((list) => list)
        .toList();

    // --- FILTER: only present attendees ---
    final presentUsers = allUsers.where((u) => u['isPresent'] == true).toList();

    // --- Compute district & community totals (present only) ---
    Map<String, int> districtTotals = {};
    Map<String, int> communityTotals = {};
    for (var entry in groupedUsersByDistrict.entries) {
      String district = entry.key;
      int count = entry.value.where((u) => u['isPresent'] == true).length;
      if (count > 0) districtTotals[district] = count;
    }
    for (var u in presentUsers) {
      String comm = u['community_name'] ?? 'Unknown';
      communityTotals[comm] = (communityTotals[comm] ?? 0) + 1;
    }

    // --- Role counts (present only) ---
    final roleGroups = _groupByRole(presentUsers);
    final Map<String, int> roleCounts = {};
    roleGroups.forEach((role, list) {
      roleCounts[role] = list.where((u) => u['isPresent'] == true).length;
    });

    // --- Spiritual parents (present only) ---
    final List<dynamic> spiritualParents = presentUsers
        .where(isParent)
        .toList();

    // --- General attendees (present only, sorted by role and name) ---
    final List<dynamic> generalAttendees =
        presentUsers.where((u) => !isParent(u)).toList()..sort((a, b) {
          int roleComp = (_getRoleLabel(a)).compareTo(_getRoleLabel(b));
          if (roleComp != 0) return roleComp;
          return ("${a['name']} ${a['surname']}").compareTo(
            "${b['name']} ${b['surname']}",
          );
        });

    // --- Build PDF with MultiPage ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context pdfContext) {
          List<pw.Widget> content = [];

          // --- HEADER ---
          content.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (localLogoImage != null)
                  pw.Image(localLogoImage, width: 50, height: 50)
                else
                  pw.Container(width: 50, height: 50),

                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      "TACT OVERSEER REGISTRY",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "OFFICIAL REGIONAL ATTENDANCE",
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      // NEW: branch info
                      "Branch: $branchName",
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(width: 50),
              ],
            ),
          );
          content.add(pw.SizedBox(height: 12));

          // --- SERVICE / EVENT INFO ---
          content.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    "OVERSEER: ",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    overseerName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Text(
                    "REGION: ",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    regionName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),
          );
          content.add(pw.SizedBox(height: 16));

          // --- OVERALL SUMMARY METRICS BOX ---
          content.add(
            _buildSummaryMetricsBox(
              total: totalMembers,
              bros: brothersPresent,
              sis: sistersPresent,
              parents: spiritualParents.length, // present parents only
              vis: totalTestifies,
              test: totalTestifies,
              ready: readyTestifies,
            ),
          );

          // --- ROLE SUMMARY TABLE ---
          if (roleCounts.isNotEmpty) {
            content.add(pw.SizedBox(height: 12));
            content.add(_buildRoleSummaryTable(roleCounts));
          }

          // --- TOP DISTRICTS & COMMUNITIES CHARTS ---
          var sortedDistricts = districtTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          var topDistricts = Map.fromEntries(sortedDistricts.take(3));

          var sortedCommunities = communityTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          var topCommunities = Map.fromEntries(sortedCommunities.take(3));

          content.add(pw.SizedBox(height: 20));
          if (branchName == 'All Branches') {
            content.add(
              pw.Text(
                "PERFORMANCE CHARTS",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            );
            content.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
            content.add(pw.SizedBox(height: 10));

            content.add(
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildCustomBarChart(
                      "Top 3 Districts",
                      topDistricts,
                      PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Expanded(
                    child: _buildCustomBarChart(
                      "Top 3 Communities",
                      topCommunities,
                      PdfColors.teal700,
                    ),
                  ),
                ],
              ),
            );
          }
          // --- SPIRITUAL PARENTS TABLE (only present) ---
          if (spiritualParents.isNotEmpty) {
            content.add(pw.SizedBox(height: 20));
            content.add(
              pw.Text(
                "SPIRITUAL PARENTS (PRESENT)",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            );
            content.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
            content.add(pw.SizedBox(height: 6));

            final Map<String, PdfColor> roleColors = {
              'Apostle': PdfColors.blue,
              'Overseer': PdfColors.white,
              'District Elder': PdfColor.fromHex('#800000'),
              'Community Elder': PdfColors.red,
              'Priest': PdfColors.green,
              'Deacon': PdfColors.yellow,
            };

            List<List<pw.Widget>> rows = [];
            for (var p in spiritualParents) {
              String fullName = "${p['name'] ?? ''} ${p['surname'] ?? ''}"
                  .trim();
              String category = p['visitor_category'] ?? '';
              String role = p['visitor_role'] ?? '';
              String displayRole = role.isNotEmpty && role != 'None'
                  ? "$category ($role)"
                  : category;
              String baseRole = role.contains('Apostle')
                  ? 'Apostle'
                  : role.contains('Overseer')
                  ? 'Overseer'
                  : role.contains('District Elder')
                  ? 'District Elder'
                  : role.contains('Community Elder')
                  ? 'Community Elder'
                  : role.contains('Priest')
                  ? 'Priest'
                  : role.contains('Deacon')
                  ? 'Deacon'
                  : category;
              PdfColor bgColor = roleColors[baseRole] ?? PdfColors.grey;
              if (bgColor == PdfColors.white) bgColor = PdfColors.grey200;

              rows.add([
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 4,
                  ),
                  child: pw.Text(
                    fullName,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: bgColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    displayRole,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: baseRole == 'Overseer'
                          ? PdfColors.black
                          : PdfColors.white,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 4,
                  ),
                  child: pw.Text(
                    p['district_elder_name'] ?? 'N/A',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ]);
            }

            content.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Name', 'Role', 'District Elder'],
                data: rows,
              ),
            );
          }

          // --- DISTRICT BREAKDOWN (only present attendees) ---
          content.add(pw.SizedBox(height: 24));
          content.add(
            pw.Text(
              "DISTRICT BREAKDOWN (PRESENT ONLY)",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          );
          content.add(pw.SizedBox(height: 6));

          // Filter districts to only those with at least one present member
          var districtsWithPresent = groupedUsersByDistrict.keys
              .where(
                (d) => groupedUsersByDistrict[d]!.any(
                  (u) => u['isPresent'] == true,
                ),
              )
              .toList();

          // Sort by present count descending
          districtsWithPresent.sort((a, b) {
            int aCount = groupedUsersByDistrict[a]!
                .where((u) => u['isPresent'] == true)
                .length;
            int bCount = groupedUsersByDistrict[b]!
                .where((u) => u['isPresent'] == true)
                .length;
            return bCount.compareTo(aCount);
          });

          for (String district in districtsWithPresent) {
            List<dynamic> usersInDistrict = groupedUsersByDistrict[district]!
                .where((u) => u['isPresent'] == true)
                .toList();
            int distPresent = usersInDistrict.length;

            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 15, bottom: 5),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(4),
                    topRight: pw.Radius.circular(4),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      district.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      "Present: $distPresent",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber300,
                      ),
                    ),
                  ],
                ),
              ),
            );

            // Sort users within district: parents first, then by name
            usersInDistrict.sort((a, b) {
              bool aParent = isParent(a);
              bool bParent = isParent(b);
              if (aParent && !bParent) return -1;
              if (!aParent && bParent) return 1;
              return ("${a['name']} ${a['surname']}").compareTo(
                "${b['name']} ${b['surname']}",
              );
            });

            List<List<dynamic>> rows = usersInDistrict.map((u) {
              String name = "${u['name'] ?? ''} ${u['surname'] ?? ''}".trim();
              String roleLabel = _getRoleLabel(u);
              return [
                pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
                pw.Text(roleLabel, style: const pw.TextStyle(fontSize: 9)),
                pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'PRESENT',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                ),
              ];
            }).toList();

            content.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.blue900,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                },
                headers: ['Name', 'Role', 'Status'],
                data: rows,
              ),
            );
            content.add(pw.SizedBox(height: 10));
          }

          // --- GENERAL ATTENDEE LIST (only present non-parents) ---
          if (generalAttendees.isNotEmpty) {
            content.add(pw.SizedBox(height: 20));
            content.add(
              pw.Text(
                "LIST OF ALL ATTENDEES (PRESENT)",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            );
            content.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
            content.add(pw.SizedBox(height: 6));

            content.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.blue900),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['#', 'Name', 'Surname', 'Role'],
                data: generalAttendees.asMap().entries.map((entry) {
                  int idx = entry.key + 1;
                  var a = entry.value;
                  return [
                    idx.toString(),
                    a['name'] ?? 'N/A',
                    a['surname'] ?? 'N/A',
                    _getRoleLabel(a),
                  ];
                }).toList(),
              ),
            );
          }

          // --- SIGNATURE & FOOTER ---
          content.add(pw.SizedBox(height: 30));
          if (signatureBytes != null && loggerName.isNotEmpty) {
            content.add(
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(
                      pw.MemoryImage(signatureBytes),
                      width: 100,
                      height: 40,
                    ),
                    pw.Container(
                      width: 150,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(width: 1)),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      loggerName,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      loggerRole,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return content;
        },
      ),
    );

    // --- Share PDF ---
    try {
      final Uint8List bytes = await pdf.save();
      final String fileName =
          'TACT_OVERSEER_REGISTER_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }

  // =========================================================================
  // 2. MONTHLY LEDGER EXPORT (FIXED – SIMPLIFIED NAME COLUMN)
  // =========================================================================
  static Future<void> generateMonthlyReportPDF({
    required BuildContext context,
    required int month,
    required int year,
    required Map<String, List<String>> officialHierarchy,
    required List<dynamic> usersList,
    required String overseerName,
    required String regionName,
    required String loggerName,
    required String loggerRole,
    required Uint8List? signatureBytes,
    required int totalMembers,
    required int presentMembers,
    required int absentMembers,
    required int totalTestifies,
    required int readyTestifies,
    required int brothersPresent,
    required int brothersTotal,
    required int sistersPresent,
    required int sistersTotal,
    String branchName = 'All Branches', // NEW
  }) async {
    if (officialHierarchy.isEmpty) {
      Api().showMessage(
        context,
        "No regions or communities found to generate a report.",
        "Empty",
        Colors.orange,
      );
      return;
    }

    Api().showMessage(
      context,
      "Compiling monthly ledger for all districts...",
      "Processing",
      Colors.blue,
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";
      final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));

      pw.MemoryImage? localLogoImage;
      try {
        final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
        localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}

      Set<String> allCommunitiesToFetch = {};
      for (var commList in officialHierarchy.values) {
        allCommunitiesToFetch.addAll(commList);
      }

      Map<String, List<dynamic>> membersByDistrict = {};
      int globalNumDays = 0;
      Set<int> activeDays = {};

      for (String community in allCommunitiesToFetch) {
        final res = await http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/monthly_attendance_report/?community_name=$community&month=$month&year=$year',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['num_days'] > globalNumDays) {
            globalNumDays = data['num_days'];
          }
          List<dynamic> commMembers = data['data'];

          for (var m in commMembers) {
            final matchedUser = usersList.firstWhere(
              (u) => u['ui_id'] == m['ui_id'],
              orElse: () => null,
            );

            if (matchedUser != null) {
              String dName =
                  matchedUser['district_elder_name'] ??
                  matchedUser['districtElderName'] ??
                  'Unassigned District';
              if (!membersByDistrict.containsKey(dName))
                membersByDistrict[dName] = [];

              m['isVisitor'] = matchedUser['isVisitor'];
              m['is_visitor'] = matchedUser['isVisitor'];
              m['visitor_category'] = matchedUser['visitor_category'];
              m['visitor_role'] = matchedUser['visitor_role'];
              m['gender'] = matchedUser['gender'];
              m['ready_for_membership'] = matchedUser['ready_for_membership'];

              Map<String, dynamic> att = m['attendance'] ?? {};
              for (int d = 1; d <= globalNumDays; d++) {
                if (att[d.toString()] == true) {
                  activeDays.add(d);
                }
              }

              membersByDistrict[dName]!.add(m);
            }
          }
        }
      }

      bool hasData = membersByDistrict.values.any((list) => list.isNotEmpty);
      if (!hasData) {
        Api().showMessage(
          context,
          "No attendance data found for this month.",
          "Empty",
          Colors.orange,
        );
        return;
      }

      membersByDistrict.forEach((district, members) {
        for (var m in members) {
          int presentCount = 0;
          int absentCount = 0;
          Map<String, dynamic> att = m['attendance'] ?? {};

          for (int d in activeDays) {
            if (att[d.toString()] == true) {
              presentCount++;
            } else {
              absentCount++;
            }
          }
          m['total_present'] = presentCount;
          m['total_absent'] = absentCount;
          m['percentage'] = activeDays.isEmpty
              ? 0
              : ((presentCount / activeDays.length) * 100).round();
        }
      });

      bool isParent(dynamic u) =>
          u['visitor_category'] == 'Mother' ||
          u['visitor_category'] == 'Father';
      bool isMale(dynamic u) =>
          u['gender'] != null && u['gender'].toString().toLowerCase() == 'male';
      bool isFemale(dynamic u) =>
          u['gender'] != null &&
          u['gender'].toString().toLowerCase() == 'female';
      bool isVis(dynamic u) =>
          u['isVisitor'] == true || u['is_visitor'] == true;
      bool isTestify(dynamic u) => isVis(u) && !isParent(u);

      void sortList(List<dynamic> list) => list.sort(
        (a, b) => "${a['name']} ${a['surname']}".compareTo(
          "${b['name']} ${b['surname']}",
        ),
      );

      List<String> tableHeaders = ['Member Names'];
      for (int i = 1; i <= globalNumDays; i++) {
        String weekday = DateFormat('E').format(DateTime(year, month, i));
        tableHeaders.add("$i\n$weekday");
      }
      tableHeaders.addAll(['P', 'A', '%']);

      Map<int, pw.TableColumnWidth> columnWidths = {
        0: const pw.FlexColumnWidth(3.0),
      };
      for (int i = 1; i <= globalNumDays; i++) {
        columnWidths[i] = const pw.FlexColumnWidth(1.1);
      }
      columnWidths[globalNumDays + 1] = const pw.FlexColumnWidth(1.2);
      columnWidths[globalNumDays + 2] = const pw.FlexColumnWidth(1.2);
      columnWidths[globalNumDays + 3] = const pw.FlexColumnWidth(1.2);

      pw.Widget _buildLedgerSection(
        String title,
        List<dynamic> sectionMembers,
        PdfColor headerColor,
      ) {
        if (sectionMembers.isEmpty) return pw.SizedBox();

        // Prepare data for the table: simplified name column using pw.Column instead of RichText
        List<List<dynamic>> rows = sectionMembers.map((m) {
          String nameDisplay = "${m['name']} ${m['surname']}";
          bool isPar = isParent(m);
          bool isVisitorFlag = isVis(m);
          pw.Widget nameWidget;

          if (isPar) {
            String role =
                m['visitor_role'] != null && m['visitor_role'] != 'None'
                ? " - ${m['visitor_role']}"
                : "";
            String cat = m['visitor_category'] ?? '';
            nameWidget = pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  nameDisplay,
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.purple800,
                  ),
                ),
                pw.Text(
                  "[$cat$role]",
                  style: pw.TextStyle(fontSize: 6, color: PdfColors.black),
                ),
              ],
            );
          } else if (isVisitorFlag && !isPar) {
            nameWidget = pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  nameDisplay,
                  style: const pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.black,
                  ),
                ),
                pw.Text(
                  "(Testify)",
                  style: const pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.black,
                  ),
                ),
              ],
            );
          } else {
            nameWidget = pw.Text(
              nameDisplay,
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.black),
            );
          }

          List<dynamic> rowData = [];
          rowData.add(nameWidget);

          Map<String, dynamic> attendance = m['attendance'] ?? {};
          for (int day = 1; day <= globalNumDays; day++) {
            bool isPresent = attendance[day.toString()] ?? false;
            bool isServiceDay = activeDays.contains(day);
            if (!isServiceDay) {
              rowData.add(
                pw.Text(
                  "-",
                  style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
                ),
              );
            } else {
              rowData.add(
                pw.Text(
                  isPresent ? "P" : "A",
                  style: pw.TextStyle(
                    color: isPresent ? PdfColors.green700 : PdfColors.red700,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 6,
                  ),
                ),
              );
            }
          }

          rowData.add(
            pw.Text(
              m['total_present'].toString(),
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          );
          rowData.add(
            pw.Text(
              m['total_absent'].toString(),
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red800,
              ),
            ),
          );
          rowData.add(
            pw.Text(
              "${m['percentage']}%",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6),
            ),
          );

          return rowData;
        }).toList();

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 8),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: headerColor,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              columnWidths: columnWidths,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerDecoration: pw.BoxDecoration(color: headerColor),
              headerHeight: 24,
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 1.5,
                horizontal: 1.0,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 4.5,
                color: PdfColors.white,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.center,
              headers: tableHeaders,
              data: rows,
            ),
          ],
        );
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            List<pw.Widget> pdfContent = [];

            pdfContent.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (localLogoImage != null)
                    pw.Image(localLogoImage, width: 45, height: 45),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "TACT OVERSEER REGISTRY",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "MONTHLY ATTENDANCE LEDGER: ${monthName.toUpperCase()}",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.blueGrey700,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        // NEW: branch info
                        "Branch: $branchName",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            "KEY: ",
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "P = PRESENT",
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.green700,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "   |   ",
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey500,
                            ),
                          ),
                          pw.Text(
                            "A = ABSENT",
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.red700,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 45),
                ],
              ),
            );
            pdfContent.add(pw.SizedBox(height: 10));
            pdfContent.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
            pdfContent.add(pw.SizedBox(height: 6));

            pdfContent.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "OVERSEER: ${overseerName.toUpperCase()}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "REGION: ${regionName.toUpperCase()}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blue800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "RECORDER: ${loggerName}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "DESIGNATION: ${loggerRole}",
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            pdfContent.add(pw.SizedBox(height: 12));
            pdfContent.add(
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Text(
                  "DAYS OF THE MONTH: ${monthName.toUpperCase()} (Total Active Services: ${activeDays.length})",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ),
            );

            pdfContent.add(
              buildPDFDashboardWidget(
                totalMembers: totalMembers,
                presentMembers: presentMembers,
                absentMembers: absentMembers,
                totalTestifies: totalTestifies,
                readyTestifies: readyTestifies,
                brothersPresent: brothersPresent,
                brothersTotal: brothersTotal,
                sistersPresent: sistersPresent,
                sistersTotal: sistersTotal,
              ),
            );
            pdfContent.add(pw.SizedBox(height: 12));

            membersByDistrict.forEach((districtName, districtData) {
              if (districtData.isEmpty) return;

              pdfContent.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 15, bottom: 5),
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                    border: pw.Border(
                      left: pw.BorderSide(
                        color: PdfColors.blueGrey800,
                        width: 3,
                      ),
                    ),
                  ),
                  child: pw.Text(
                    "DISTRICT ELDER: ${districtName.toUpperCase()}",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                ),
              );

              final spiritualParents = districtData.where(isParent).toList();
              final brothersMembers = districtData
                  .where((u) => !isParent(u) && !isTestify(u) && isMale(u))
                  .toList();
              final sistersMembers = districtData
                  .where((u) => !isParent(u) && !isTestify(u) && isFemale(u))
                  .toList();
              final unassignedMembers = districtData
                  .where(
                    (u) =>
                        !isParent(u) &&
                        !isTestify(u) &&
                        !isMale(u) &&
                        !isFemale(u),
                  )
                  .toList();
              final brothersTestifies = districtData
                  .where((u) => isTestify(u) && isMale(u))
                  .toList();
              final sistersTestifies = districtData
                  .where((u) => isTestify(u) && isFemale(u))
                  .toList();
              final unassignedTestifies = districtData
                  .where((u) => isTestify(u) && !isMale(u) && !isFemale(u))
                  .toList();

              sortList(spiritualParents);
              sortList(brothersMembers);
              sortList(sistersMembers);
              sortList(unassignedMembers);
              sortList(brothersTestifies);
              sortList(sistersTestifies);
              sortList(unassignedTestifies);

              pdfContent.add(
                _buildLedgerSection(
                  "SPIRITUAL PARENTS",
                  spiritualParents,
                  PdfColors.purple800,
                ),
              );
              pdfContent.add(
                _buildLedgerSection(
                  "BROTHERS (MEMBERS)",
                  brothersMembers,
                  PdfColors.blue800,
                ),
              );
              pdfContent.add(
                _buildLedgerSection(
                  "SISTERS (MEMBERS)",
                  sistersMembers,
                  PdfColors.pink700,
                ),
              );
              pdfContent.add(
                _buildLedgerSection(
                  "MEMBERS (GENDER UNSPECIFIED)",
                  unassignedMembers,
                  PdfColors.blueGrey600,
                ),
              );
              pdfContent.add(
                _buildLedgerSection(
                  "BROTHERS (TESTIFIES)",
                  brothersTestifies,
                  PdfColors.lightBlue700,
                ),
              );
              pdfContent.add(
                _buildLedgerSection(
                  "SISTERS (TESTIFIES)",
                  sistersTestifies,
                  PdfColors.pink400,
                ),
              );
              pdfContent.add(
                _buildLedgerSection(
                  "TESTIFIES (GENDER UNSPECIFIED)",
                  unassignedTestifies,
                  PdfColors.grey600,
                ),
              );
              pdfContent.add(pw.SizedBox(height: 10));
            });

            pdfContent.add(pw.SizedBox(height: 30));
            pdfContent.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Report Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (signatureBytes != null)
                        pw.Image(
                          pw.MemoryImage(signatureBytes),
                          width: 100,
                          height: 40,
                        )
                      else
                        pw.SizedBox(height: 40),
                      pw.Container(
                        width: 150,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(width: 1)),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        loggerName,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        loggerRole,
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            return pdfContent;
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final String fileName = 'TACT_REGIONAL_MONTHLY_${year}_$month.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      debugPrint(e.toString());
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }

  // =========================================================================
  // 3. GLOBAL ATTENDANCE REPORT (with includeAttendees toggle)
  // =========================================================================
  static Future<void> generateGlobalAttendanceReportPDF({
    required BuildContext context,
    required DateTime selectedDate,
    required List<Map<String, dynamic>> overseerDataList,
    required int overallTotal,
    required int overallBrothers,
    required int overallSisters,
    required int overallParents,
    required int overallVisitors,
    required int overallTestifies,
    required int overallReadyTestifies,
    required Map<String, int> overallRoleCounts,
    required List<Map<String, dynamic>> globalAttendees,
    required bool includeAttendees,
    Uint8List? signatureBytes,
    String loggerName = '',
    String loggerRole = '',
    String branchName = 'All Branches', // NEW
  }) async {
    try {
      pw.MemoryImage? localLogoImage;
      try {
        final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
        localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}

      final pdf = pw.Document();

      Map<String, List<Map<String, dynamic>>> groupedByProvince = {};
      Map<String, int> provTotals = {};
      Map<String, int> regTotals = {};

      for (var entry in overseerDataList) {
        String province = entry['province'] ?? 'Unknown Province';
        String region = entry['region'] ?? 'Unknown Region';

        groupedByProvince.putIfAbsent(province, () => []).add(entry);

        int currentTotal = (entry['total_present'] as int?) ?? 0;
        provTotals[province] = (provTotals[province] ?? 0) + currentTotal;
        regTotals[region] = (regTotals[region] ?? 0) + currentTotal;
      }

      List<String> provinces = groupedByProvince.keys.toList()..sort();

      var sortedProvinces = provTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      var top3Provinces = Map.fromEntries(sortedProvinces.take(3));

      var sortedRegions = regTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      var top3Regions = Map.fromEntries(sortedRegions.take(3));

      Map<String, int> demographicsData = {
        'Bros': overallBrothers,
        'Sis': overallSisters,
        'Parents': overallParents,
        'Visits': overallVisitors,
      };

      // ---------- SPIRITUAL PARENTS LOGIC ----------
      final List<String> spiritualRoleOrder = [
        'Apostle',
        'Overseer',
        'District Elder',
        'Community Elder',
        'Priest',
        'Deacon',
      ];

      String? getBaseSpiritualRole(String rawRole) {
        for (String keyword in spiritualRoleOrder) {
          if (rawRole.contains(keyword)) {
            return keyword;
          }
        }
        return null;
      }

      List<Map<String, dynamic>> spiritualParents = globalAttendees.where((a) {
        String role = a['role'] ?? '';
        return role.contains('Mother') ||
            role.contains('Father') ||
            getBaseSpiritualRole(role) != null;
      }).toList();

      spiritualParents.sort((a, b) {
        String? baseA = getBaseSpiritualRole(a['role'] ?? '');
        String? baseB = getBaseSpiritualRole(b['role'] ?? '');
        int indexA = baseA != null ? spiritualRoleOrder.indexOf(baseA) : 999;
        int indexB = baseB != null ? spiritualRoleOrder.indexOf(baseB) : 999;
        if (indexA == 999 && indexB == 999) {
          return 0;
        }
        return indexA.compareTo(indexB);
      });

      List<Map<String, dynamic>> generalAttendees = globalAttendees.where((a) {
        String role = a['role'] ?? '';
        return !role.contains('Mother') &&
            !role.contains('Father') &&
            getBaseSpiritualRole(role) == null;
      }).toList();

      generalAttendees.sort((a, b) {
        int roleComp = (a['role'] ?? '').compareTo(b['role'] ?? '');
        if (roleComp != 0) return roleComp;
        return (a['name'] ?? '').compareTo(b['name'] ?? '');
      });

      final Map<String, PdfColor> roleColors = {
        'Apostle': PdfColors.blue,
        'Overseer': PdfColors.white,
        'District Elder': PdfColor.fromHex('#800000'),
        'Community Elder': PdfColors.red,
        'Priest': PdfColors.green,
        'Deacon': PdfColors.yellow,
      };

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          footer: (pw.Context context) => _buildFooter(context),
          build: (pw.Context pdfContext) {
            List<pw.Widget> pdfContent = [];

            // ---- HEADER ----
            pdfContent.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (localLogoImage != null)
                    pw.Image(localLogoImage, width: 50, height: 50)
                  else
                    pw.Container(width: 50, height: 50),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "TACT GLOBAL ATTENDANCE REPORT",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Date: ${DateFormat('dd MMMM yyyy').format(selectedDate)}",
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        // NEW: branch info
                        "Branch: $branchName",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 50),
                ],
              ),
            );

            pdfContent.add(pw.SizedBox(height: 12));

            pdfContent.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      "SERVICE / EVENT: ",
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      loggerName.isEmpty
                          ? "NOT SPECIFIED"
                          : loggerName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ),
            );

            pdfContent.add(pw.SizedBox(height: 16));

            // ---- OVERALL ATTENDANCE SUMMARY ----
            pdfContent.add(
              pw.Text(
                "OVERALL ATTENDANCE SUMMARY",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            );
            pdfContent.add(pw.SizedBox(height: 8));

            pdfContent.add(
              _buildSummaryMetricsBox(
                total: overallTotal,
                bros: overallBrothers,
                sis: overallSisters,
                parents: overallParents,
                vis: overallVisitors,
                test: overallTestifies,
                ready: overallReadyTestifies,
              ),
            );

            if (overallRoleCounts.isNotEmpty) {
              pdfContent.add(pw.SizedBox(height: 12));
              pdfContent.add(_buildRoleSummaryTable(overallRoleCounts));
            }

            // ---- SPIRITUAL PARENTS TABLE (always included) ----
            if (spiritualParents.isNotEmpty) {
              pdfContent.add(pw.SizedBox(height: 20));
              pdfContent.add(
                pw.Text(
                  "SPIRITUAL PARENTS",
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              );
              pdfContent.add(
                pw.Divider(thickness: 1, color: PdfColors.grey300),
              );
              pdfContent.add(pw.SizedBox(height: 6));

              List<List<pw.Widget>> rows = [];
              for (var p in spiritualParents) {
                String fullName = "${p['name'] ?? ''} ${p['surname'] ?? ''}"
                    .trim();
                String role = p['role'] ?? '';
                String baseRole = getBaseSpiritualRole(role) ?? role;
                PdfColor bgColor = roleColors[baseRole] ?? PdfColors.grey;
                if (bgColor == PdfColors.white) {
                  bgColor = PdfColors.grey200;
                }

                rows.add([
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 4,
                    ),
                    child: pw.Text(
                      fullName,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: bgColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      role,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: baseRole == 'Overseer'
                            ? PdfColors.black
                            : PdfColors.white,
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 4,
                    ),
                    child: pw.Text(
                      p['overseer_name'] ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ]);
              }

              pdfContent.add(
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.blue),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headers: ['Name', 'Role', 'Overseer'],
                  data: rows,
                ),
              );
            }

            // ---- CHARTS AND PROVINCIAL BREAKDOWN ----
            pdfContent.add(pw.SizedBox(height: 20));

            pdfContent.add(
              pw.Text(
                "PERFORMANCE & DEMOGRAPHIC CHARTS",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            );
            pdfContent.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
            pdfContent.add(pw.SizedBox(height: 10));

            pdfContent.add(
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildCustomBarChart(
                      "Top 3 Provinces",
                      top3Provinces,
                      PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Expanded(
                    child: _buildCustomBarChart(
                      "Top 3 Regions",
                      top3Regions,
                      PdfColors.teal700,
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Expanded(
                    child: _buildCustomBarChart(
                      "Demographics",
                      demographicsData,
                      PdfColors.indigo600,
                    ),
                  ),
                ],
              ),
            );

            pdfContent.add(pw.SizedBox(height: 24));

            pdfContent.add(
              pw.Text(
                "PROVINCIAL BREAKDOWN",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            );
            pdfContent.add(pw.SizedBox(height: 6));

            for (String province in provinces) {
              List<Map<String, dynamic>> overseersInProvince =
                  groupedByProvince[province]!;
              int provTotal = 0,
                  provBrothers = 0,
                  provSisters = 0,
                  provParents = 0,
                  provVisitors = 0,
                  provTestifies = 0,
                  provReady = 0;

              for (var o in overseersInProvince) {
                provTotal += (o['total_present'] as int?) ?? 0;
                provBrothers += (o['brothers_present'] as int?) ?? 0;
                provSisters += (o['sisters_present'] as int?) ?? 0;
                provParents += (o['parents_present'] as int?) ?? 0;
                provVisitors += (o['visitors_present'] as int?) ?? 0;
                provTestifies += (o['testifies_present'] as int?) ?? 0;
                provReady += (o['ready_testifies'] as int?) ?? 0;
              }

              pdfContent.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 15, bottom: 5),
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(4),
                      topRight: pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "${province.toUpperCase()} (${overseersInProvince.length} Overseers)",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        "Total Present: $provTotal",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber300,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              pdfContent.add(
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    color: PdfColors.blue900,
                  ),
                  cellStyle: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey800,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(1),
                    5: const pw.FlexColumnWidth(1),
                    6: const pw.FlexColumnWidth(1),
                    7: const pw.FlexColumnWidth(1.5),
                  },
                  headers: [
                    'Overseer',
                    'Region',
                    'Total',
                    'Brothers',
                    'Sisters',
                    'Parents',
                    'Visitors',
                    'Testifies (Ready)',
                  ],
                  data: [
                    [
                      'TOTAL',
                      '',
                      provTotal.toString(),
                      provBrothers.toString(),
                      provSisters.toString(),
                      provParents.toString(),
                      provVisitors.toString(),
                      '$provTestifies ($provReady ready)',
                    ],
                    ...overseersInProvince.map((o) {
                      return [
                        o['overseer_name'] ?? 'Unknown',
                        o['region'] ?? 'N/A',
                        (o['total_present']).toString(),
                        (o['brothers_present']).toString(),
                        (o['sisters_present']).toString(),
                        (o['parents_present']).toString(),
                        (o['visitors_present']).toString(),
                        '${o['testifies_present']} (${o['ready_testifies']} ready)',
                      ];
                    }).toList(),
                  ],
                ),
              );
              pdfContent.add(pw.SizedBox(height: 10));
            }

            // ---- GENERAL ATTENDEE LIST (only if includeAttendees is true) ----
            if (includeAttendees && generalAttendees.isNotEmpty) {
              pdfContent.add(pw.SizedBox(height: 20));
              pdfContent.add(
                pw.Text(
                  "LIST OF ALL ATTENDEES",
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              );
              pdfContent.add(
                pw.Divider(thickness: 1, color: PdfColors.grey300),
              );
              pdfContent.add(pw.SizedBox(height: 6));

              pdfContent.add(
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.blue900),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headers: ['#', 'Name', 'Surname', 'Role'],
                  data: generalAttendees.asMap().entries.map((entry) {
                    int idx = entry.key + 1;
                    var a = entry.value;
                    return [
                      idx.toString(),
                      a['name'] ?? 'N/A',
                      a['surname'] ?? 'N/A',
                      a['role'] ?? 'Unknown',
                    ];
                  }).toList(),
                ),
              );
            }

            // ---- SIGNATURE ----
            pdfContent.add(pw.SizedBox(height: 30));
            if (signatureBytes != null && loggerName.isNotEmpty) {
              pdfContent.add(
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(
                        pw.MemoryImage(signatureBytes),
                        width: 100,
                        height: 40,
                      ),
                      pw.Container(
                        width: 150,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(width: 1)),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        loggerName,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        loggerRole,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return pdfContent;
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final String fileName =
          'TACT_GLOBAL_ATTENDANCE_${DateFormat('yyyyMMdd').format(selectedDate)}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      debugPrint("Export Error: $e");
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }

  // =========================================================================
  // SHARED HELPER WIDGETS
  // =========================================================================
  static pw.Widget _buildSummaryMetricsBox({
    required int total,
    required int bros,
    required int sis,
    required int parents,
    required int vis,
    required int test,
    required int ready,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _metricItem("Total", total, PdfColors.blue900, 'groups'),
          _metricItem("Brothers", bros, PdfColors.blue700, 'person'),
          _metricItem("Sisters", sis, PdfColors.pink700, 'person'),
          _metricItem("Parents", parents, PdfColors.purple700, 'family'),
          _metricItem("Visitors", vis, PdfColors.orange700, 'badge'),
          _metricItem("Ready Test.", ready, PdfColors.green700, 'check'),
        ],
      ),
    );
  }

  static pw.Widget _metricItem(
    String title,
    int value,
    PdfColor color,
    String iconType,
  ) {
    String svgData = '';
    if (iconType == 'groups') {
      svgData =
          '<svg viewBox="0 0 24 24"><path fill="${color.toHex()}" d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5s-3 1.34-3 3 1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5s-3 1.34-3 3 1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/></svg>';
    } else if (iconType == 'person') {
      svgData =
          '<svg viewBox="0 0 24 24"><path fill="${color.toHex()}" d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>';
    } else if (iconType == 'family') {
      svgData =
          '<svg viewBox="0 0 24 24"><path fill="${color.toHex()}" d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5s-3 1.34-3 3 1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5s-3 1.34-3 3 1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/></svg>';
    } else if (iconType == 'badge') {
      svgData =
          '<svg viewBox="0 0 24 24"><path fill="${color.toHex()}" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/></svg>';
    } else if (iconType == 'check') {
      svgData =
          '<svg viewBox="0 0 24 24"><path fill="${color.toHex()}" d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SvgImage(svg: svgData, width: 22, height: 22),
        pw.SizedBox(height: 6),
        pw.Text(
          value.toString(),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildCustomBarChart(
    String title,
    Map<String, int> data,
    PdfColor barColor,
  ) {
    if (data.isEmpty) return pw.SizedBox();
    int maxVal = data.values.first;
    for (var val in data.values) {
      if (val > maxVal) maxVal = val;
    }
    if (maxVal == 0) maxVal = 1;

    return pw.Container(
      height: 140,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: data.entries.map((entry) {
                double heightFactor = entry.value / maxVal;
                if (heightFactor > 1.0) heightFactor = 1.0;
                String label = entry.key.trim();
                if (label.isEmpty) label = "N/A";
                if (label.length > 7) label = "${label.substring(0, 7)}.";
                return pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      entry.value.toString(),
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: 20,
                      height: 65 * heightFactor,
                      decoration: pw.BoxDecoration(
                        color: barColor,
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(3),
                          topRight: pw.Radius.circular(3),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      label,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Report generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }
}
