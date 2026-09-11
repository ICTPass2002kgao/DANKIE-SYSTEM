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

class SpiritualPdfGenerator {
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

  // =========================================================================
  // 4. NEW: CIRCULAR / LETTER PDF
  // =========================================================================
  static Future<void> generateCircularPDF({
    required BuildContext context,
    required String subject,
    required String messageJson,
    required List<dynamic> committeeMembers,
    required String universityName,
    required String? universityLogoUrl,
    required String loggedMemberName,
    required String loggedMemberRole,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final pdf = pw.Document();

    final ttf = await rootBundle.load('assets/CloisterBlack.ttf');
    final font = pw.Font.ttf(ttf);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          content.add(_buildHeader(font, logoBytes));
          content.add(pw.SizedBox(height: 20));

          // ----- SUBJECT -----
          content.add(
            pw.Center(
              child: pw.Text(
                _sanitizeText(subject).toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          );
          content.add(pw.SizedBox(height: 16));

          // ----- MESSAGE -----
          content.addAll(_buildQuillParagraphs(messageJson));

          content.add(pw.SizedBox(height: 24));

          // ----- COMMITTEE SIGNATURE FIELDS -----
          if (committeeMembers.isNotEmpty) {
            content.add(pw.SizedBox(height: 30));
            content.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: committeeMembers.map((member) {
                  String fullName =
                      member['full_name'] ??
                      member['fullname'] ??
                      member['name'] ??
                      '';
                  String portfolio =
                      member['portfolio'] ?? member['role'] ?? '';
                  String contacts = member['phone'] ?? '';

                  return pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          _sanitizeText(fullName),
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          _sanitizeText(portfolio),
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          _sanitizeText(contacts),
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 24),
                        pw.Text(
                          '______________________',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }

          content.add(pw.SizedBox(height: 40));
          return content;
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = '${universityName} Memo.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  // Parses Quill JSON to support inline styles, headers, and lists
  static List<pw.Widget> _buildQuillParagraphs(String jsonString) {
    List<pw.Widget> widgets = [];
    List<pw.TextSpan> currentSpans = [];
    int orderedListCounter = 1;

    try {
      final List<dynamic> ops = jsonDecode(jsonString);

      for (var op in ops) {
        if (op is! Map || !op.containsKey('insert')) continue;

        final insertData = op['insert'];
        final attributes = op['attributes'] as Map<String, dynamic>? ?? {};

        if (insertData is String) {
          // If the operation is a newline carrying block styles
          if (insertData == '\n') {
            if (currentSpans.isEmpty) {
              widgets.add(pw.SizedBox(height: 6));
              continue;
            }

            pw.Widget blockWidget;

            // Headers
            if (attributes.containsKey('header')) {
              int level = attributes['header'];
              double fontSize = level == 1
                  ? 20
                  : level == 2
                  ? 16
                  : 14;
              blockWidget = pw.RichText(
                text: pw.TextSpan(
                  children: List.from(currentSpans),
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              orderedListCounter = 1;
            }
            // Bullet Lists (using a native vector circle instead of unicode character)
            else if (attributes['list'] == 'bullet') {
              blockWidget = pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 5, right: 6),
                      width: 4,
                      height: 4,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.black,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(children: List.from(currentSpans)),
                      ),
                    ),
                  ],
                ),
              );
              orderedListCounter = 1;
            }
            // Numbered Lists
            else if (attributes['list'] == 'ordered') {
              blockWidget = pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$orderedListCounter. ',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Expanded(
                      child: pw.RichText(
                        text: pw.TextSpan(children: List.from(currentSpans)),
                      ),
                    ),
                  ],
                ),
              );
              orderedListCounter++;
            }
            // Standard Paragraph
            else {
              blockWidget = pw.RichText(
                text: pw.TextSpan(children: List.from(currentSpans)),
              );
              orderedListCounter = 1;
            }

            widgets.add(blockWidget);
            widgets.add(pw.SizedBox(height: 6));
            currentSpans.clear();
          }
          // Text operation
          else {
            pw.FontWeight weight = attributes['bold'] == true
                ? pw.FontWeight.bold
                : pw.FontWeight.normal;
            pw.FontStyle style = attributes['italic'] == true
                ? pw.FontStyle.italic
                : pw.FontStyle.normal;
            pw.TextDecoration decoration = attributes['underline'] == true
                ? pw.TextDecoration.underline
                : pw.TextDecoration.none;

            List<String> lines = insertData.split('\n');

            for (int i = 0; i < lines.length; i++) {
              if (lines[i].isNotEmpty) {
                currentSpans.add(
                  pw.TextSpan(
                    text: _sanitizeText(lines[i]),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: weight,
                      fontStyle: style,
                      decoration: decoration,
                    ),
                  ),
                );
              }

              if (i < lines.length - 1) {
                if (currentSpans.isNotEmpty) {
                  widgets.add(
                    pw.RichText(
                      text: pw.TextSpan(children: List.from(currentSpans)),
                    ),
                  );
                  widgets.add(pw.SizedBox(height: 6));
                  currentSpans.clear();
                  orderedListCounter = 1;
                }
              }
            }
          }
        }
      }

      if (currentSpans.isNotEmpty) {
        widgets.add(pw.RichText(text: pw.TextSpan(children: currentSpans)));
      }
    } catch (e) {
      widgets.add(
        pw.Text("Error parsing text.", style: const pw.TextStyle(fontSize: 12)),
      );
    }

    return widgets;
  }

  static String _sanitizeText(String text) {
    return text
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('•', '-')
        .replaceAll('\u200B', '');
  }

  static Future<void> exportMemberListPDF({
    required BuildContext context,
    required List<dynamic> members,
    required bool includeSignature,
    required String universityName,
    required String? universityLogoUrl,
    required String loggedMemberName,
    required String loggedMemberRole,
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) async {
    final pdf = pw.Document();

    final ttf = await rootBundle.load('assets/CloisterBlack.ttf');
    final font = pw.Font.ttf(ttf);

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

    List<List<String>> rows = [];
    int index = 1;
    for (var member in members) {
      final name = capitalise(member['name']);
      final surname = capitalise(member['surname']);
      final studentNumber = member['student_number']?.toString() ?? '';
      final contact = member['phone'] ?? member['contact'] ?? '';
      rows.add([index.toString(), name, surname, studentNumber, contact]);
      index++;
    }

    pw.ImageProvider? uniLogo;
    if (universityLogoUrl != null && universityLogoUrl.isNotEmpty) {
      try {
        uniLogo = await networkImage(universityLogoUrl);
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          // ----- CHURCH HEADER (reused from overseer) -----
          content.add(_buildHeader(font, logoBytes));
          content.add(pw.SizedBox(height: 20));

          // ----- UNIVERSITY & TITLE -----
          content.add(
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    "TTACTSO ${universityName.toUpperCase()}",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "MEMBERS LIST",
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),
          );
          content.add(pw.SizedBox(height: 16));

          // ----- TABLE -----
          Map<int, pw.TableColumnWidth> columnWidths = {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
            if (includeSignature) 5: const pw.FixedColumnWidth(80),
          };

          List<String> headers = [
            'No.',
            'Name',
            'Surname',
            'Student No.',
            'Contact',
          ];
          if (includeSignature) headers.add('Signature');

          content.add(
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: columnWidths,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: headers.map((h) => _cell(h, bold: true)).toList(),
                ),
                ...rows.map((row) {
                  List<pw.Widget> rowCells = [
                    _cell(row[0]),
                    _cell(row[1]),
                    _cell(row[2]),
                    _cell(row[3]),
                    _cell(row[4]),
                  ];
                  if (includeSignature) {
                    rowCells.add(pw.Container(height: 25));
                  }
                  return pw.TableRow(children: rowCells);
                }),
              ],
            ),
          );

          // ----- FOOTER -----
          content.add(pw.SizedBox(height: 20));

          return content;
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName =
        'MemberList_${universityName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  // =========================================================================
  // SHARED DASHBOARD WIDGET (same as Overseer)
  // =========================================================================
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

  // =========================================================================
  // SHARED SUMMARY METRICS BOX
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

  // =========================================================================
  // ROLE SUMMARY TABLE
  // =========================================================================
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
  // CUSTOM BAR CHART
  // =========================================================================
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

  // =========================================================================
  // FOOTER
  // =========================================================================
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

  // =========================================================================
  // 1. DAILY REGISTER EXPORT (Design updated, content unchanged)
  // =========================================================================
  static Future<void> exportRegisterToPDF({
    required BuildContext context,
    required String filterType,
    required String universityName,
    required String? universityLogoUrl,
    required String? loggedMemberName,
    required String? loggedMemberRole,
    required List<dynamic> usersList,
    required int totalMembers,
    required int presentMembers,
    required int absentMembers,
    required int totalTestifies,
    required int readyTestifies,
    required int brothersPresent,
    required int brothersTotal,
    required int sistersPresent,
    required int sistersTotal,
    required Uint8List? signatureBytes,
  }) async {
    // --- Helper predicates (unchanged) ---
    bool isParent(dynamic u) =>
        u['visitor_category'] == 'Mother' || u['visitor_category'] == 'Father';
    bool isMale(dynamic g) => g != null && g.toString().toLowerCase() == 'male';
    bool isFemale(dynamic g) =>
        g != null && g.toString().toLowerCase() == 'female';
    bool isVis(dynamic u) => u['isVisitor'] == true || u['is_visitor'] == true;

    // --- Determine target list based on filter (unchanged) ---
    List<dynamic> targetList;
    String reportStatusLabel = "All Members";
    if (filterType == 'BrothersAndParents') {
      targetList = usersList
          .where((u) => isParent(u) || isMale(u['gender']))
          .toList();
      reportStatusLabel = "Brothers & Spiritual Parents";
    } else if (filterType == 'SistersAndParents') {
      targetList = usersList
          .where((u) => isParent(u) || isFemale(u['gender']))
          .toList();
      reportStatusLabel = "Sisters & Spiritual Parents";
    } else {
      targetList = usersList;
      reportStatusLabel = "All Members";
    }

    if (targetList.isEmpty) {
      Api().showMessage(
        context,
        "No members found in this category.",
        "Empty Register",
        Colors.orange,
      );
      return;
    }

    // --- Filter only present attendees (for the register) ---
    final presentUsers = targetList
        .where((u) => u['isPresent'] == true)
        .toList();

    // --- Category grouping (present only) – same as original ---
    final spiritualParents = presentUsers.where(isParent).toList();
    final regularMembers = presentUsers
        .where((u) => !isParent(u) && !isVis(u))
        .toList();
    final maleMembers = regularMembers
        .where((u) => isMale(u['gender']))
        .toList();
    final femaleMembers = regularMembers
        .where((u) => isFemale(u['gender']))
        .toList();
    final unassignedMembers = regularMembers
        .where((u) => !isMale(u['gender']) && !isFemale(u['gender']))
        .toList();
    final regularVisitors = presentUsers
        .where((u) => !isParent(u) && isVis(u))
        .toList();
    final maleTestifies = regularVisitors
        .where((u) => isMale(u['gender']))
        .toList();
    final femaleTestifies = regularVisitors
        .where((u) => isFemale(u['gender']))
        .toList();
    final unassignedTestifies = regularVisitors
        .where((u) => !isMale(u['gender']) && !isFemale(u['gender']))
        .toList();

    // --- Role counts for summary table ---
    Map<String, int> roleCounts = {};
    void addRole(String role) => roleCounts[role] = (roleCounts[role] ?? 0) + 1;
    for (var u in presentUsers) {
      if (isParent(u)) {
        String cat = u['visitor_category'] ?? 'Spiritual Parent';
        addRole(cat);
      } else if (isVis(u)) {
        addRole('Testify');
      } else {
        addRole('Member');
      }
    }

    // --- Load logos (unchanged) ---
    pw.MemoryImage? localLogoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    pw.ImageProvider? uniLogoImage;
    if (universityLogoUrl != null && universityLogoUrl.isNotEmpty) {
      try {
        uniLogoImage = await networkImage(universityLogoUrl);
      } catch (_) {}
    }

    final pdf = pw.Document();
    final String fullDate = DateFormat(
      'EEEE, dd MMMM yyyy',
    ).format(DateTime.now());
    final String timestamp = DateFormat('HH:mm').format(DateTime.now());
    final String recordedBy = loggedMemberName ?? 'Unknown User';
    final String recorderRole = loggedMemberRole ?? 'Authorized Officer';

    // --- Build PDF with MultiPage ---
    pdf.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context pdfContext) {
          List<pw.Widget> content = [];

          // ---- HEADER (same as overseer style) ----
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
                      "TTACTSO ${universityName.toUpperCase()}",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "OFFICIAL ATTENDANCE REGISTER",
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.blue900,
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
          );
          content.add(pw.SizedBox(height: 12));

          // ---- SERVICE / EVENT INFO (same as overseer) ----
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
                    "UNIVERSITY: ",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    universityName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Text(
                    "FILTER: ",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    reportStatusLabel.toUpperCase(),
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

          // ---- OVERALL SUMMARY METRICS BOX ----
          content.add(
            _buildSummaryMetricsBox(
              total: totalMembers,
              bros: brothersPresent,
              sis: sistersPresent,
              parents: spiritualParents.length,
              vis: totalTestifies,
              test: totalTestifies,
              ready: readyTestifies,
            ),
          );

          // ---- ROLE SUMMARY TABLE ----
          if (roleCounts.isNotEmpty) {
            content.add(pw.SizedBox(height: 12));
            content.add(_buildRoleSummaryTable(roleCounts));
          }

          // ---- DEMOGRAPHICS BAR CHART ----
          final Map<String, int> demChartData = {
            'Brothers': brothersPresent,
            'Sisters': sistersPresent,
            'Parents': spiritualParents.length,
            'Testifies': totalTestifies,
          };
          content.add(pw.SizedBox(height: 20));
          content.add(
            pw.Text(
              "DEMOGRAPHICS",
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
            _buildCustomBarChart(
              "Present by Category",
              demChartData,
              PdfColors.indigo600,
            ),
          );

          // ---- SPIRITUAL PARENTS TABLE (unchanged content, styled) ----
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

            List<List<dynamic>> rows = [];
            for (var p in spiritualParents) {
              String fullName = "${p['name'] ?? ''} ${p['surname'] ?? ''}"
                  .trim();
              String category = p['visitor_category'] ?? '';
              String role = p['visitor_role'] ?? '';
              String displayRole = role.isNotEmpty && role != 'None'
                  ? "$category ($role)"
                  : category;
              rows.add([
                pw.Text(fullName, style: const pw.TextStyle(fontSize: 9)),
                pw.Text(displayRole, style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                  p['district_elder_name'] ?? 'N/A',
                  style: const pw.TextStyle(fontSize: 9),
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

          // ---- CATEGORY TABLES (exactly as original, with new header colors) ----
          pw.Widget _buildCategoryTable(
            String title,
            List<dynamic> data,
            PdfColor headerColor,
          ) {
            if (data.isEmpty) return pw.SizedBox();
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
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerDecoration: pw.BoxDecoration(color: headerColor),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 4,
                  ),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    color: PdfColors.white,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headers: [
                    'First Name',
                    'Last Name & Rank',
                    'Contact No.',
                    'Status',
                  ],
                  data: data.map((user) {
                    String lastNameDisplay = user['surname'] ?? 'N/A';
                    if (isParent(user)) {
                      String role = user['visitor_role'] ?? '';
                      String cat = user['visitor_category'] ?? '';
                      if (role.isNotEmpty && role != 'None') {
                        lastNameDisplay += ' ($cat - $role)';
                      } else {
                        lastNameDisplay += ' ($cat)';
                      }
                    } else if (isVis(user) && !isParent(user)) {
                      bool isReady =
                          user['ready_for_membership'] == true ||
                          user['ready_for_membership'] == 'true';
                      if (isReady) {
                        lastNameDisplay += '\n(Awaiting Sealing)';
                      } else {
                        lastNameDisplay += '\n(Testify)';
                      }
                    }
                    return [
                      user['name'] ?? 'N/A',
                      pw.Text(
                        lastNameDisplay,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      user['phone'] ?? 'N/A',
                      (user['isPresent'] == true) ? 'PRESENT' : 'ABSENT',
                    ];
                  }).toList(),
                ),
              ],
            );
          }

          content.add(
            _buildCategoryTable(
              "BROTHERS (MEMBERS)",
              maleMembers,
              PdfColors.blue800,
            ),
          );
          content.add(
            _buildCategoryTable(
              "SISTERS (MEMBERS)",
              femaleMembers,
              PdfColors.pink700,
            ),
          );
          content.add(
            _buildCategoryTable(
              "MEMBERS (GENDER UNSPECIFIED)",
              unassignedMembers,
              PdfColors.blueGrey600,
            ),
          );
          content.add(
            _buildCategoryTable(
              "BROTHERS (TESTIFIES)",
              maleTestifies,
              PdfColors.lightBlue600,
            ),
          );
          content.add(
            _buildCategoryTable(
              "SISTERS (TESTIFIES)",
              femaleTestifies,
              PdfColors.pink400,
            ),
          );
          content.add(
            _buildCategoryTable(
              "TESTIFIES (GENDER UNSPECIFIED)",
              unassignedTestifies,
              PdfColors.grey600,
            ),
          );

          // ---- SIGNATURE & FOOTER (same as overseer) ----
          content.add(pw.SizedBox(height: 30));
          if (signatureBytes != null && recordedBy.isNotEmpty) {
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
                      recordedBy,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      recorderRole,
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
          'REGISTER_${universityName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }

  // =========================================================================
  // 2. MONTHLY LEDGER EXPORT (Design updated, content unchanged)
  // =========================================================================
  static Future<void> generateMonthlyReportPDF({
    required BuildContext context,
    required String universityName,
    required int month,
    required int year,
    required String? universityLogoUrl,
    required String? loggedMemberName,
    required String? loggedMemberRole,
    required Map<String, dynamic>? overseerData,
    required Map<String, dynamic>? districtData,
    required List<dynamic> usersList,
    required int totalMembers,
    required int presentMembers,
    required int absentMembers,
    required int totalTestifies,
    required int readyTestifies,
    required int brothersPresent,
    required int brothersTotal,
    required int sistersPresent,
    required int sistersTotal,
    required Uint8List? signatureBytes,
  }) async {
    Api().showMessage(
      context,
      "Fetching monthly ledger...",
      "Processing",
      Colors.blue,
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? "" : "";

      final res = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/monthly_attendance_report/?community_name=$universityName&month=$month&year=$year',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode != 200) {
        throw Exception("Failed to load data: ${res.body}");
      }

      final data = jsonDecode(res.body);
      final int numDays = data['num_days'];
      List<dynamic> members = data['data'];

      // --- Calculate active service days (unchanged) ---
      Set<int> activeDays = {};
      for (var m in members) {
        Map<String, dynamic> att = m['attendance'] ?? {};
        for (int d = 1; d <= numDays; d++) {
          if (att[d.toString()] == true) {
            activeDays.add(d);
          }
        }
      }

      // --- Compute present/absent counts per member (unchanged) ---
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

      // --- Categorisation (unchanged) ---
      bool isParent(dynamic u) =>
          u['visitor_category'] == 'Mother' ||
          u['visitor_category'] == 'Father';
      bool isMale(dynamic u) =>
          u['gender'] != null && u['gender'].toString().toLowerCase() == 'male';
      bool isFemale(dynamic u) =>
          u['gender'] != null &&
          u['gender'].toString().toLowerCase() == 'female';
      bool isTestify(dynamic u) => u['is_visitor'] == true && !isParent(u);

      final spiritualParents = members.where(isParent).toList();
      final brothersMembers = members
          .where((u) => !isParent(u) && !isTestify(u) && isMale(u))
          .toList();
      final sistersMembers = members
          .where((u) => !isParent(u) && !isTestify(u) && isFemale(u))
          .toList();
      final unassignedMembers = members
          .where(
            (u) => !isParent(u) && !isTestify(u) && !isMale(u) && !isFemale(u),
          )
          .toList();
      final brothersTestifies = members
          .where((u) => isTestify(u) && isMale(u))
          .toList();
      final sistersTestifies = members
          .where((u) => isTestify(u) && isFemale(u))
          .toList();
      final unassignedTestifies = members
          .where((u) => isTestify(u) && !isMale(u) && !isFemale(u))
          .toList();

      void sortList(List<dynamic> list) => list.sort(
        (a, b) => "${a['name']} ${a['surname']}".compareTo(
          "${b['name']} ${b['surname']}",
        ),
      );
      sortList(spiritualParents);
      sortList(brothersMembers);
      sortList(sistersMembers);
      sortList(unassignedMembers);
      sortList(brothersTestifies);
      sortList(sistersTestifies);
      sortList(unassignedTestifies);

      // --- Load logos (unchanged) ---
      pw.MemoryImage? localLogoImage;
      try {
        final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
        localLogoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {}

      pw.ImageProvider? uniLogoImage;
      if (universityLogoUrl != null && universityLogoUrl.isNotEmpty) {
        try {
          uniLogoImage = await networkImage(universityLogoUrl);
        } catch (_) {}
      }

      final pdf = pw.Document();
      final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));

      // --- Table headers (unchanged) ---
      List<String> tableHeaders = ['Member Names'];
      for (int i = 1; i <= numDays; i++) {
        String weekday = DateFormat('E').format(DateTime(year, month, i));
        tableHeaders.add("$i\n$weekday");
      }
      tableHeaders.addAll(['P', 'A', '%']);

      Map<int, pw.TableColumnWidth> columnWidths = {
        0: const pw.FlexColumnWidth(3.0),
      };
      for (int i = 1; i <= numDays; i++) {
        columnWidths[i] = const pw.FlexColumnWidth(1.1);
      }
      columnWidths[numDays + 1] = const pw.FlexColumnWidth(1.2);
      columnWidths[numDays + 2] = const pw.FlexColumnWidth(1.2);
      columnWidths[numDays + 3] = const pw.FlexColumnWidth(1.2);

      pw.Widget _buildLedgerSection(
        String title,
        List<dynamic> sectionMembers,
        PdfColor headerColor,
      ) {
        if (sectionMembers.isEmpty) return pw.SizedBox();
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
              data: sectionMembers.map((m) {
                String nameDisplay = "${m['name']} ${m['surname']}";
                bool isPar = isParent(m);
                bool isVis = m['is_visitor'] == true;

                if (isPar) {
                  String role =
                      m['visitor_role'] != null && m['visitor_role'] != 'None'
                      ? " - ${m['visitor_role']}"
                      : "";
                  nameDisplay += "\n[${m['visitor_category']}$role]";
                }

                List<pw.InlineSpan> spans = [
                  pw.TextSpan(
                    text: nameDisplay,
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: isPar
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: isPar ? PdfColors.purple800 : PdfColors.black,
                    ),
                  ),
                ];

                if (isVis && !isPar) {
                  bool isReady =
                      m['ready_for_membership'] == true ||
                      m['ready_for_membership'] == 'true';
                  if (isReady) {
                    spans.add(
                      pw.TextSpan(
                        text: "\n(Awaiting Sealing)",
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                    );
                  } else {
                    spans.add(
                      pw.TextSpan(
                        text: "\nTestify",
                        style: const pw.TextStyle(
                          fontSize: 6,
                          color: PdfColors.black,
                        ),
                      ),
                    );
                  }
                }

                List<dynamic> rowData = [];
                rowData.add(
                  pw.Container(
                    alignment: pw.Alignment.centerLeft,
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.RichText(text: pw.TextSpan(children: spans)),
                  ),
                );

                Map<String, dynamic> attendance = m['attendance'];
                for (int day = 1; day <= numDays; day++) {
                  bool isPresent = attendance[day.toString()] ?? false;
                  bool isServiceDay = activeDays.contains(day);
                  if (!isServiceDay) {
                    rowData.add(
                      pw.Text(
                        "-",
                        style: pw.TextStyle(
                          fontSize: 6,
                          color: PdfColors.grey500,
                        ),
                      ),
                    );
                  } else {
                    rowData.add(
                      pw.Text(
                        isPresent ? "P" : "A",
                        style: pw.TextStyle(
                          color: isPresent
                              ? PdfColors.green700
                              : PdfColors.red700,
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
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 6,
                    ),
                  ),
                );
                return rowData;
              }).toList(),
            ),
          ],
        );
      }

      // --- Build PDF ---
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          footer: (pw.Context context) => _buildFooter(context),
          build: (pw.Context pdfContext) {
            List<pw.Widget> pdfContent = [];

            // ---- HEADER (same as overseer style) ----
            pdfContent.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (localLogoImage != null)
                    pw.Image(localLogoImage, width: 45, height: 45)
                  else
                    pw.SizedBox(width: 45),

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
                      pw.Text(
                        "MONTHLY ATTENDANCE LEDGER: ${monthName.toUpperCase()}",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.blue900,
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
                  if (uniLogoImage != null)
                    pw.Image(uniLogoImage, width: 45, height: 45)
                  else
                    pw.SizedBox(width: 45),
                ],
              ),
            );
            pdfContent.add(pw.SizedBox(height: 10));
            pdfContent.add(pw.Divider(thickness: 1, color: PdfColors.grey300));
            pdfContent.add(pw.SizedBox(height: 6));

            // ---- INFO CONTAINER (same as overseer) ----
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
                          "OVERSEER: ${overseerData?['overseer_initials_surname'] ?? 'Unassigned'}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "DISTRICT: ${districtData?['district_elder_name'] ?? 'Unassigned'}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "RECORDER: ${loggedMemberName ?? 'Unknown'}",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "DESIGNATION: ${loggedMemberRole ?? 'Authorized Officer'}",
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            pdfContent.add(pw.SizedBox(height: 12));

            // ---- ACTIVE SERVICES INFO ----
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
                    color: PdfColors.blue900,
                  ),
                ),
              ),
            );

            // ---- DASHBOARD ----
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

            // ---- ROLE SUMMARY TABLE (new addition, but keeps all data) ----
            Map<String, int> roleCounts = {};
            for (var m in members) {
              if (isParent(m)) {
                String cat = m['visitor_category'] ?? 'Spiritual Parent';
                roleCounts[cat] = (roleCounts[cat] ?? 0) + 1;
              } else if (isTestify(m)) {
                roleCounts['Testify'] = (roleCounts['Testify'] ?? 0) + 1;
              } else {
                roleCounts['Member'] = (roleCounts['Member'] ?? 0) + 1;
              }
            }
            if (roleCounts.isNotEmpty) {
              pdfContent.add(_buildRoleSummaryTable(roleCounts));
            }

            // ---- LEDGER SECTIONS (unchanged content) ----
            pdfContent.add(
              _buildLedgerSection(
                "SPIRITUAL PARENTS (MOTHERS & FATHERS)",
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

            // ---- SIGNATURE ----
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
                        loggedMemberName ?? 'Unknown User',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        loggedMemberRole ?? 'Authorized Officer',
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
      final String fileName = 'MONTHLY_${universityName}_$year\_$month.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      debugPrint(e.toString());
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }

  // =========================================================================
  // Helper to fetch network image
  // =========================================================================
  static Future<pw.ImageProvider> networkImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return pw.MemoryImage(response.bodyBytes);
    } else {
      throw Exception('Failed to load image');
    }
  }
}
