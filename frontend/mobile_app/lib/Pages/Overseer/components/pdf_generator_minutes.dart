// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';

class MeetingMinutesPdfGenerator {
  /// Formats the raw minutes text into styled PDF widgets
  /// Automatically detects lists/numbering to format them properly.
  /// Formats the raw minutes text into styled PDF widgets
  /// Automatically detects lists/numbering to format them properly.
  static List<pw.Widget> _formatMinutesText(String text) {
    List<pw.Widget> widgets = [];

    // SANITIZE TEXT: Prevent crashes from unsupported symbols (bullets, smart quotes, etc.)
    final String sanitizedText = text
        .replaceAll('•', '-')
        .replaceAll('◦', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('–', '-') // en-dash
        .replaceAll('—', '-'); // em-dash

    final lines = sanitizedText.split('\n');

    // Updated regex to remove the unicode bullet, since we converted it to a hyphen
    final RegExp listPattern = RegExp(r'^(\d+\.|[a-zA-Z]\.|-)\s');

    for (var line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      bool isListItem = listPattern.hasMatch(line.trim());

      if (isListItem) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 20, bottom: 4),
            child: pw.Text(
              line.trim(),
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
            ),
          ),
        );
      } else {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              line.trim(),
              style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
              textAlign: pw.TextAlign.justify,
            ),
          ),
        );
      }
    }

    return widgets;
  }

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
                style: pw.TextStyle(
                  font: font,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
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

  static Future<void> generateMinutesPDF({
    required BuildContext context,
    required String title,
    required String date,
    required String overseerName,
    required String regionName,
    required String loggerName,
    required String loggerRole,
    required List<String> attendees,
    required String minutesText,
    Uint8List? signatureBytes,
  }) async {
    Api().showMessage(
      context,
      "Generating professional PDF...",
      "Processing",
      Colors.blue,
    );

    try {
      final pdf = pw.Document();
      final ttf = await rootBundle.load('assets/CloisterBlack.ttf');
      final font = pw.Font.ttf(ttf);
      // Load fonts & Logo

      Uint8List? logoBytes;
      try {
        final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
        logoBytes = bytes.buffer.asUint8List();
      } catch (_) {}

      // Add pages
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          footer: (pw.Context context) {
            return pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Generated by $loggerName ($loggerRole) on ${DateTime.now().toString().split(' ')[0]}",
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      "Page ${context.pageNumber} of ${context.pagesCount}",
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          build: (pw.Context pdfContext) {
            return [
              // 1. Header
              _buildHeader( font,logoBytes),
              pw.SizedBox(height: 24),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // 2. Meeting Meta Info
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  "OFFICIAL MEETING MINUTES",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.blueGrey200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          "Meeting Title: ",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Date: ",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          date,
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Overseer: ",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          overseerName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Text(
                          "Region: ",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          regionName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 3. Attendees Section
              pw.Text(
                "Members Present:",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.green),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: attendees.map((att) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        att,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 24),

              // 4. Minutes Content (Filtered for numbering and bullets)
              pw.Text(
                "Meeting Deliberations:",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              ..._formatMinutesText(minutesText),

              pw.SizedBox(height: 40),

              // 5. Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
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
                        pw.SizedBox(height: 40), // Empty space if no signature

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
                          fontSize: 10,
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
                ],
              ),
            ];
          },
        ),
      );

      // Share Document
      final Uint8List bytes = await pdf.save();
      final String fileName =
          'TACT_MEETING_MINUTES_${date.replaceAll('-', '')}.pdf';

      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Meeting Minutes PDF');
      } catch (shareErr) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } catch (e) {
      Api().showMessage(context, "Export Error: $e", "Error", Colors.red);
    }
  }
}
