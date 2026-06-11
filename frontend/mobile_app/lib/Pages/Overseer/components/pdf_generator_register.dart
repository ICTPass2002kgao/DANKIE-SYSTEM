// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ttact/Components/API.dart';

class OverseerPdfGenerator {
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
                    color: PdfColors.blueGrey800,
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
                    color: PdfColors.blueGrey800,
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
                    color: PdfColors.blueGrey800,
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
  }) async {
    if (officialHierarchy.isEmpty) {
      Api().showMessage(context, "No regions or communities found to generate a report.", "Empty", Colors.orange);
      return;
    }

    Api().showMessage(context, "Compiling monthly ledger for all districts...", "Processing", Colors.blue);

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
      Set<int> activeDays = {}; // NEW: Track days with services across all communities

      for (String community in allCommunitiesToFetch) {
        final res = await http.get(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/monthly_attendance_report/?community_name=$community&month=$month&year=$year'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
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
              String dName = matchedUser['district_elder_name'] ?? matchedUser['districtElderName'] ?? 'Unassigned District';
              if (!membersByDistrict.containsKey(dName)) membersByDistrict[dName] = [];

              m['isVisitor'] = matchedUser['isVisitor'];
              m['is_visitor'] = matchedUser['isVisitor'];
              m['visitor_category'] = matchedUser['visitor_category'];
              m['visitor_role'] = matchedUser['visitor_role'];
              m['gender'] = matchedUser['gender'];
              m['ready_for_membership'] = matchedUser['ready_for_membership'];

              // Track active days globally
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
        Api().showMessage(context, "No attendance data found for this month.", "Empty", Colors.orange);
        return;
      }

      // NEW: Recalculate percentages against ACTIVE days only
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
          m['percentage'] = activeDays.isEmpty ? 0 : ((presentCount / activeDays.length) * 100).round();
        }
      });

      bool isParent(dynamic u) => u['visitor_category'] == 'Mother' || u['visitor_category'] == 'Father';
      bool isMale(dynamic u) => u['gender'] != null && u['gender'].toString().toLowerCase() == 'male';
      bool isFemale(dynamic u) => u['gender'] != null && u['gender'].toString().toLowerCase() == 'female';
      bool isVis(dynamic u) => u['isVisitor'] == true || u['is_visitor'] == true;
      bool isTestify(dynamic u) => isVis(u) && !isParent(u);

      void sortList(List<dynamic> list) => list.sort(
        (a, b) => "${a['name']} ${a['surname']}".compareTo("${b['name']} ${b['surname']}"),
      );

      List<String> tableHeaders = ['Member Names'];
      for (int i = 1; i <= globalNumDays; i++) {
        String weekday = DateFormat('E').format(DateTime(year, month, i));
        tableHeaders.add("$i\n$weekday");
      }
      tableHeaders.addAll(['P', 'A', '%']);

      Map<int, pw.TableColumnWidth> columnWidths = {0: const pw.FlexColumnWidth(3.0)};
      for (int i = 1; i <= globalNumDays; i++) {
        columnWidths[i] = const pw.FlexColumnWidth(1.1);
      }
      columnWidths[globalNumDays + 1] = const pw.FlexColumnWidth(1.2);
      columnWidths[globalNumDays + 2] = const pw.FlexColumnWidth(1.2);
      columnWidths[globalNumDays + 3] = const pw.FlexColumnWidth(1.2);

      pw.Widget _buildLedgerSection(String title, List<dynamic> sectionMembers, PdfColor headerColor) {
        if (sectionMembers.isEmpty) return pw.SizedBox();
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 8),
            pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: headerColor)),
            pw.SizedBox(height: 3),
            pw.TableHelper.fromTextArray(
              columnWidths: columnWidths,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerDecoration: pw.BoxDecoration(color: headerColor),
              headerHeight: 24,
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 1.0),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 4.5, color: PdfColors.white),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.center,
              headers: tableHeaders,
              data: sectionMembers.map((m) {
                String nameDisplay = "${m['name']} ${m['surname']}";
                bool isPar = isParent(m);
                bool isVisitorFlag = isVis(m);

                if (isPar) {
                  String role = m['visitor_role'] != null && m['visitor_role'] != 'None' ? " - ${m['visitor_role']}" : "";
                  nameDisplay += "\n[${m['visitor_category']}$role]";
                }

                List<pw.InlineSpan> spans = [
                  pw.TextSpan(
                    text: nameDisplay,
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: isPar ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: isPar ? PdfColors.purple800 : PdfColors.black,
                    ),
                  ),
                ];

                if (isVisitorFlag && !isPar) {
                  spans.add(pw.TextSpan(text: "\n(Testify)", style: const pw.TextStyle(fontSize: 6, color: PdfColors.black)));
                }

                List<dynamic> rowData = [];
                rowData.add(
                  pw.Container(
                    alignment: pw.Alignment.centerLeft,
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.RichText(text: pw.TextSpan(children: spans)),
                  ),
                );

                Map<String, dynamic> attendance = m['attendance'] ?? {};
                for (int day = 1; day <= globalNumDays; day++) {
                  bool isPresent = attendance[day.toString()] ?? false;
                  bool isServiceDay = activeDays.contains(day);
                  
                  if (!isServiceDay) {
                     rowData.add(pw.Text("-", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500)));
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

                rowData.add(pw.Text(m['total_present'].toString(), style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)));
                rowData.add(pw.Text(m['total_absent'].toString(), style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)));
                rowData.add(pw.Text("${m['percentage']}%", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6)));

                return rowData;
              }).toList(),
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
                  if (localLogoImage != null) pw.Image(localLogoImage, width: 45, height: 45),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("TACT OVERSEER REGISTRY", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text("MONTHLY ATTENDANCE LEDGER: ${monthName.toUpperCase()}", style: pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey700)),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text("KEY: ", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text("P = PRESENT", style: pw.TextStyle(fontSize: 9, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
                          pw.Text("   |   ", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                          pw.Text("A = ABSENT", style: pw.TextStyle(fontSize: 9, color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
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
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("OVERSEER: ${overseerName.toUpperCase()}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text("REGION: ${regionName.toUpperCase()}", style: pw.TextStyle(fontSize: 8, color: PdfColors.blue800, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("RECORDER: ${loggerName}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text("DESIGNATION: ${loggerRole}", style: pw.TextStyle(fontSize: 8)),
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
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                ),
              ),
            );

            pdfContent.add(buildPDFDashboardWidget(
              totalMembers: totalMembers, presentMembers: presentMembers, absentMembers: absentMembers,
              totalTestifies: totalTestifies, readyTestifies: readyTestifies, brothersPresent: brothersPresent,
              brothersTotal: brothersTotal, sistersPresent: sistersPresent, sistersTotal: sistersTotal,
            ));
            pdfContent.add(pw.SizedBox(height: 12));

            membersByDistrict.forEach((districtName, districtData) {
              if (districtData.isEmpty) return;

              pdfContent.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 15, bottom: 5),
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(color: PdfColors.blueGrey50, border: pw.Border(left: pw.BorderSide(color: PdfColors.blueGrey800, width: 3))),
                  child: pw.Text("DISTRICT ELDER: ${districtName.toUpperCase()}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                ),
              );

              final spiritualParents = districtData.where(isParent).toList();
              final brothersMembers = districtData.where((u) => !isParent(u) && !isTestify(u) && isMale(u)).toList();
              final sistersMembers = districtData.where((u) => !isParent(u) && !isTestify(u) && isFemale(u)).toList();
              final unassignedMembers = districtData.where((u) => !isParent(u) && !isTestify(u) && !isMale(u) && !isFemale(u)).toList();
              final brothersTestifies = districtData.where((u) => isTestify(u) && isMale(u)).toList();
              final sistersTestifies = districtData.where((u) => isTestify(u) && isFemale(u)).toList();
              final unassignedTestifies = districtData.where((u) => isTestify(u) && !isMale(u) && !isFemale(u)).toList();

              sortList(spiritualParents); sortList(brothersMembers); sortList(sistersMembers);
              sortList(unassignedMembers); sortList(brothersTestifies); sortList(sistersTestifies); sortList(unassignedTestifies);

              pdfContent.add(_buildLedgerSection("SPIRITUAL PARENTS", spiritualParents, PdfColors.purple800));
              pdfContent.add(_buildLedgerSection("BROTHERS (MEMBERS)", brothersMembers, PdfColors.blue800));
              pdfContent.add(_buildLedgerSection("SISTERS (MEMBERS)", sistersMembers, PdfColors.pink700));
              pdfContent.add(_buildLedgerSection("MEMBERS (GENDER UNSPECIFIED)", unassignedMembers, PdfColors.blueGrey600));
              pdfContent.add(_buildLedgerSection("BROTHERS (TESTIFIES)", brothersTestifies, PdfColors.lightBlue700));
              pdfContent.add(_buildLedgerSection("SISTERS (TESTIFIES)", sistersTestifies, PdfColors.pink400));
              pdfContent.add(_buildLedgerSection("TESTIFIES (GENDER UNSPECIFIED)", unassignedTestifies, PdfColors.grey600));
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
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (signatureBytes != null)
                        pw.Image(pw.MemoryImage(signatureBytes), width: 100, height: 40)
                      else
                        pw.SizedBox(height: 40),
                      pw.Container(
                        width: 150,
                        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(loggerName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      pw.SizedBox(height: 2),
                      pw.Text(loggerRole, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
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
  }) async {
    bool isParent(dynamic u) => u['visitor_category'] == 'Mother' || u['visitor_category'] == 'Father';
    bool isMale(dynamic g) => g != null && g.toString().toLowerCase() == 'male';
    bool isFemale(dynamic g) => g != null && g.toString().toLowerCase() == 'female';
    bool isVis(dynamic u) => u['isVisitor'] == true || u['is_visitor'] == true;

    pw.MemoryImage? localLogoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {}

    final pdf = pw.Document();
    final String fullDate = DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());
    final String timestamp = DateFormat('HH:mm').format(DateTime.now());

    String reportStatusLabel = "All Members";
    if (filterType == 'BrothersAndParents') reportStatusLabel = "Brothers & Spiritual Parents";
    if (filterType == 'SistersAndParents') reportStatusLabel = "Sisters & Spiritual Parents";

    pw.Widget _buildCategoryTable(String title, List<dynamic> data, PdfColor headerColor) {
      if (data.isEmpty) return pw.SizedBox();
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 8),
          pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: headerColor)),
          pw.SizedBox(height: 3),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerDecoration: pw.BoxDecoration(color: headerColor),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headers: ['First Name', 'Last Name & Rank', 'Contact No.', 'Status'],
            data: data.map((user) {
              String lastNameDisplay = user['surname'] ?? 'N/A';
              bool isVisFlag = isVis(user);
              bool isReady = user['ready_for_membership'] == true || user['ready_for_membership'] == 'true';

              if (isParent(user)) {
                String role = user['visitor_role'] ?? '';
                String cat = user['visitor_category'] ?? '';
                if (role.isNotEmpty && role != 'None') {
                  lastNameDisplay += ' ($cat - $role)';
                } else {
                  lastNameDisplay += ' ($cat)';
                }
              }

              pw.Widget lastNameWidget;
              if (isVisFlag && !isParent(user)) {
                if (isReady) {
                  lastNameWidget = pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: lastNameDisplay, style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
                      pw.TextSpan(text: '\n(Awaiting Sealing)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                    ]),
                  );
                } else {
                  lastNameWidget = pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(text: lastNameDisplay, style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
                      pw.TextSpan(text: '\n(Testify)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
                    ]),
                  );
                }
              } else {
                lastNameWidget = pw.Text(lastNameDisplay, style: const pw.TextStyle(fontSize: 8, color: PdfColors.black));
              }

              return [user['name'] ?? 'N/A', lastNameWidget, user['phone'] ?? 'N/A', (user['isPresent'] == true) ? 'PRESENT' : 'ABSENT'];
            }).toList(),
          ),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context pdfContext) {
          List<pw.Widget> pdfContent = [];

          pdfContent.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (localLogoImage != null) pw.Image(localLogoImage, width: 45, height: 45),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text("TACT OVERSEER REGISTRY", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text("OFFICIAL REGIONAL ATTENDANCE", style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700)),
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("OVERSEER: ${overseerName.toUpperCase()}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("REGION: ${regionName.toUpperCase()}", style: pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("REPORT STATUS: $reportStatusLabel", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text("GENERATED ON: $fullDate at $timestamp", style: pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
          );

          pdfContent.add(buildPDFDashboardWidget(
            totalMembers: totalMembers, presentMembers: presentMembers, absentMembers: absentMembers,
            totalTestifies: totalTestifies, readyTestifies: readyTestifies, brothersPresent: brothersPresent,
            brothersTotal: brothersTotal, sistersPresent: sistersPresent, sistersTotal: sistersTotal,
          ));

          groupedUsersByDistrict.forEach((districtName, districtUsers) {
            List<dynamic> targetList;
            if (filterType == 'BrothersAndParents') {
              targetList = districtUsers.where((u) => isParent(u) || isMale(u['gender'])).toList();
            } else if (filterType == 'SistersAndParents') {
              targetList = districtUsers.where((u) => isParent(u) || isFemale(u['gender'])).toList();
            } else {
              targetList = districtUsers;
            }

            if (targetList.isEmpty) return;

            pdfContent.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 15, bottom: 5),
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: pw.BoxDecoration(color: PdfColors.blueGrey50, border: pw.Border(left: pw.BorderSide(color: PdfColors.blueGrey800, width: 3))),
                child: pw.Text("DISTRICT ELDER: ${districtName.toUpperCase()}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
              ),
            );

            final spiritualParents = targetList.where((u) => isParent(u)).toList();
            final regularMembers = targetList.where((u) => !isParent(u) && !isVis(u)).toList();
            final maleMembers = regularMembers.where((u) => isMale(u['gender'])).toList();
            final femaleMembers = regularMembers.where((u) => isFemale(u['gender'])).toList();
            final unassignedMembers = regularMembers.where((u) => !isMale(u['gender']) && !isFemale(u['gender'])).toList();
            final regularVisitors = targetList.where((u) => !isParent(u) && isVis(u)).toList();
            final maleTestifies = regularVisitors.where((u) => isMale(u['gender'])).toList();
            final femaleTestifies = regularVisitors.where((u) => isFemale(u['gender'])).toList();
            final unassignedTestifies = regularVisitors.where((u) => !isMale(u['gender']) && !isFemale(u['gender'])).toList();

            pdfContent.add(_buildCategoryTable("SPIRITUAL PARENTS (MOTHERS & FATHERS)", spiritualParents, PdfColors.purple800));
            pdfContent.add(_buildCategoryTable("BROTHERS (MEMBERS)", maleMembers, PdfColors.blue800));
            pdfContent.add(_buildCategoryTable("SISTERS (MEMBERS)", femaleMembers, PdfColors.pink700));
            pdfContent.add(_buildCategoryTable("MEMBERS (GENDER UNSPECIFIED)", unassignedMembers, PdfColors.blueGrey600));
            pdfContent.add(_buildCategoryTable("BROTHERS (TESTIFIES)", maleTestifies, PdfColors.lightBlue600));
            pdfContent.add(_buildCategoryTable("SISTERS (TESTIFIES)", femaleTestifies, PdfColors.pink400));
            pdfContent.add(_buildCategoryTable("TESTIFIES (GENDER UNSPECIFIED)", unassignedTestifies, PdfColors.grey600));
            pdfContent.add(pw.SizedBox(height: 10)); 
          });

          pdfContent.add(pw.SizedBox(height: 30));
          pdfContent.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (signatureBytes != null)
                    pw.Image(pw.MemoryImage(signatureBytes), width: 100, height: 40)
                  else
                    pw.SizedBox(height: 40),
                  pw.Container(
                    width: 150,
                    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(loggerName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                  pw.SizedBox(height: 2),
                  pw.Text(loggerRole, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                ],
              ),
            ),
          );

          return pdfContent;
        },
      ),
    );

    try {
      final Uint8List bytes = await pdf.save();
      final String fileName = 'TACT_OVERSEER_REGISTER_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }
}