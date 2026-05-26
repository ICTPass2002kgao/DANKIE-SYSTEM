import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ttact/Components/API.dart';

class MonthlyPdfReport {
  static Future<void> generate({
    required BuildContext context,
    required List<dynamic> usersList,
    required String universityName,
    required String filterType, // 'All', 'Brothers', or 'Sisters'
    required String reportMode, // 'Weekly' or 'Monthly'
    required String? loggedMemberName,
    required String? loggedMemberRole,
    required String? universityLogoUrl,
    required DateTime selectedDate,
  }) async {
    if (usersList.isEmpty) {
      Api().showMessage(
        context,
        "No members found to generate a report.",
        "Empty Data",
        Colors.orange,
      );
      return;
    }

    String formatSurname(String? surname) {
      if (surname == null || surname.isEmpty) return '';
      return surname.replaceAll(RegExp(r'\s+[a-zA-Z]\.?$'), '').trim();
    }

    bool hasRole(dynamic u, String targetRole) {
      final role = u['role']?.toString().toLowerCase() ?? '';
      return role.contains(targetRole.toLowerCase());
    }

    // THE VIP OVERRIDE LOGIC: All Elders, Priests, Deacons, and Overseers bypass the filter
    bool isVIP(dynamic u) {
      final role = u['role']?.toString().toLowerCase() ?? '';
      return role.contains('apostle') ||
          role.contains('overseer') ||
          role.contains('elder') ||
          role.contains('priest') ||
          role.contains('deacon');
    }

    List<dynamic> targetList = usersList.where((u) {
      if (filterType == 'All') return true;
      if (isVIP(u)) return true; // VIPs bypass the filter
      if (filterType == 'Brothers' &&
          u['role']?.toString().toLowerCase() == 'brother')
        return true;
      if (filterType == 'Sisters' &&
          u['role']?.toString().toLowerCase() == 'sister')
        return true;
      return false;
    }).toList();

    // Grouping strictly by the visual hierarchy
    final apostles = targetList.where((u) => hasRole(u, 'apostle')).toList();
    final overseers = targetList.where((u) => hasRole(u, 'overseer')).toList();
    final districtElders = targetList
        .where((u) => hasRole(u, 'district elder'))
        .toList();
    final communityElders = targetList
        .where((u) => hasRole(u, 'community elder'))
        .toList();
    final priests = targetList.where((u) => hasRole(u, 'priest')).toList();
    final deacons = targetList.where((u) => hasRole(u, 'deacon')).toList();

    final brothers = targetList
        .where((u) => u['role'] == 'Brother' && u['isVisitor'] == false)
        .toList();
    final sisters = targetList
        .where((u) => u['role'] == 'Sister' && u['isVisitor'] == false)
        .toList();
    final visitors = targetList.where((u) => u['isVisitor'] == true).toList();

    pw.MemoryImage? localLogoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint("Local logo error: $e");
    }

    pw.ImageProvider? uniLogoImage;
    if (universityLogoUrl != null && universityLogoUrl.isNotEmpty) {
      try {
        uniLogoImage = await networkImage(universityLogoUrl);
      } catch (e) {}
    }

    final pdf = pw.Document();
    final String reportPeriodString = reportMode == 'Weekly'
        ? "Week of ${DateFormat('dd MMM yyyy').format(selectedDate)}"
        : DateFormat('MMMM yyyy').format(selectedDate);

    final String printDate = DateFormat(
      'dd MMM yyyy HH:mm',
    ).format(DateTime.now());
    final officerName = loggedMemberName ?? 'Designated Recording Officer';
    final officerRole = loggedMemberRole ?? 'Committee Member';

    pw.Widget buildCategoryTable(
      String title,
      List<dynamic> data,
      PdfColor headerColor,
    ) {
      if (data.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 12),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: headerColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: pw.BoxDecoration(color: headerColor),
            headerHeight: 20,
            cellHeight: 18,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
              color: PdfColors.white,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
            headers: [
              'Role',
              'First Name',
              'Surname',
              'Contact No.',
              'Home Address',
              'Status',
            ],
            data: data.map((user) {
              return [
                (user['role'] ?? 'Member').toString().toUpperCase(),
                user['name'] ?? 'N/A',
                formatSurname(user['surname']),
                user['phone'] ?? 'N/A',
                user['address'] ?? 'N/A',
                user['isPresent'] == true ? 'PRESENT' : 'ABSENT',
              ];
            }).toList(),
          ),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (localLogoImage != null)
                  pw.Image(localLogoImage, width: 50, height: 50),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      "TTACTSO ${universityName.toUpperCase()}",
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "OFFICIAL ${reportMode.toUpperCase()} ATTENDANCE REPORT",
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.Text(
                      "Report Period: $reportPeriodString",
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                if (uniLogoImage != null)
                  pw.Image(uniLogoImage, width: 50, height: 50)
                else
                  pw.SizedBox(width: 50),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.5, color: PdfColors.grey400),
            pw.SizedBox(height: 10),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "RECORDING OFFICER DETAILS",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Name: $officerName",
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "Designation: $officerRole",
                        style: pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "DOCUMENT CONTROL",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Filter: $filterType (VIPs Included)",
                        style: pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        "Printed: $printDate",
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Strict Printing Order
            buildCategoryTable("APOSTLES", apostles, PdfColors.indigo900),
            buildCategoryTable("OVERSEERS", overseers, PdfColors.blue900),
            buildCategoryTable(
              "DISTRICT ELDERS",
              districtElders,
              PdfColors.blue800,
            ),
            buildCategoryTable(
              "COMMUNITY ELDERS",
              communityElders,
              PdfColors.cyan800,
            ),
            buildCategoryTable("PRIESTS", priests, PdfColors.teal800),
            buildCategoryTable("DEACONS", deacons, PdfColors.purple800),
            buildCategoryTable("BROTHERS", brothers, PdfColors.blue700),
            buildCategoryTable("SISTERS", sisters, PdfColors.pink700),
            buildCategoryTable(
              "TESTIFIES / VISITORS",
              visitors,
              PdfColors.grey700,
            ),

            pw.SizedBox(height: 40),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 120),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Recording Officer Signature",
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 120),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Overseer / Elder Signature",
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    try {
      final Uint8List bytes = await pdf.save();
      final String fileName =
          '${reportMode.toUpperCase()}_REPORT_${universityName}_${DateFormat('yyyyMMdd').format(selectedDate)}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }
}
