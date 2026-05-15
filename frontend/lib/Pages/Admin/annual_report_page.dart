// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

const double _desktopContentMaxWidth = 800.0;

class AnnualReportPage extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;

  const AnnualReportPage({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  List<dynamic> eventReports = [];
  bool isLoading = true;
  bool _isGeneratingPdf = false;
  String errorMessage = '';

  // --- AGGREGATED DATA FOR PDF CHARTS ---
  List<MapEntry<String, double>> topRegions = [];
  List<MapEntry<String, double>> topOverseers = [];
  double maxRegionAmount = 1.0;
  double maxOverseerAmount = 1.0;

  // --- YEAR SELECTION STATE ---
  late String _selectedYear;
  final List<String> _availableYears = [
    (DateTime.now().year - 1).toString(),
    DateTime.now().year.toString(),
    (DateTime.now().year + 1).toString(),
    (DateTime.now().year + 2).toString(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year.toString();
    fetchAnnualReport();
  }

  Future<void> fetchAnnualReport() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      final response = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/event_diary/?year=$_selectedYear',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() {
          eventReports = decodedData;
          _processChartData();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load report. Code: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error occurred.';
        isLoading = false;
      });
    }
  }

  // --- AGGREGATE DATA FOR PDF ---
  void _processChartData() {
    Map<String, double> regionTotals = {};
    Map<String, double> overseerTotals = {};

    for (var event in eventReports) {
      final contributions = event['contributions'] ?? [];
      for (var c in contributions) {
        if (c['has_contributed'] == true) {
          double amt = double.tryParse(c['amount'].toString()) ?? 0.0;
          String region = c['region'] ?? 'Unknown';
          String overseer = c['overseer_name'] ?? 'Unknown';

          regionTotals[region] = (regionTotals[region] ?? 0) + amt;
          overseerTotals[overseer] = (overseerTotals[overseer] ?? 0) + amt;
        }
      }
    }

    var sortedRegions = regionTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topRegions = sortedRegions.take(3).toList();

    if (topRegions.isNotEmpty && topRegions.first.value > 0) {
      maxRegionAmount = topRegions.first.value;
    } else {
      maxRegionAmount = 1.0;
    }

    var sortedOverseers = overseerTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topOverseers = sortedOverseers.take(10).toList();

    if (topOverseers.isNotEmpty && topOverseers.first.value > 0) {
      maxOverseerAmount = topOverseers.first.value;
    } else {
      maxOverseerAmount = 1.0;
    }
  }

  // --- ⭐️ GENERATE & DOWNLOAD PDF WITH LOADING ---
  Future<void> _generateAndDownloadPDF() async {
    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final pdf = pw.Document();
      double grandTotal = 0.0;
      pw.MemoryImage? logoImage;
      try {
        final ByteData imageBytes = await rootBundle.load(
          'assets/tact_logo.PNG',
        );
        final Uint8List logoData = imageBytes.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoData);
      } catch (e) {
        debugPrint("Warning: Could not load tact_logo.PNG.");
      }

      final PdfColor primaryColor = PdfColor.fromHex('#1E3A8A');
      final PdfColor secondaryColor = PdfColor.fromHex('#3B82F6');
      final PdfColor headerColor = PdfColor.fromHex('#F8FAFC');
      final PdfColor borderColor = PdfColor.fromHex('#E2E8F0');

      pw.Widget _buildHorizontalBar(
        String label,
        double value,
        double maxVal,
        PdfColor color,
      ) {
        double fraction = maxVal > 0 ? (value / maxVal) : 0;
        if (fraction > 1.0) fraction = 1.0;
        if (fraction < 0.01 && value > 0) fraction = 0.01;

        int flexFilled = (fraction * 1000).toInt();
        int flexEmpty = ((1.0 - fraction) * 1000).toInt();

        if (flexFilled <= 0) flexFilled = 1;
        if (flexEmpty <= 0) flexEmpty = 1;

        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 100,
                child: pw.Text(
                  label.length > 18 ? "${label.substring(0, 16)}..." : label,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.black,
                  ),
                  maxLines: 1,
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  height: 12,
                  child: pw.Row(
                    children: [
                      if (fraction > 0)
                        pw.Expanded(
                          flex: flexFilled,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              color: color,
                              borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      if (fraction < 1.0)
                        pw.Expanded(
                          flex: flexEmpty,
                          child: pw.Container(
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  "R ${value.toStringAsFixed(0)}",
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            List<pw.Widget> content = [];

            // --- HEADER SECTION ---
            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 30),
                padding: const pw.EdgeInsets.only(bottom: 15),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: primaryColor, width: 0.6),
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 80,
                        height: 80,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.Text(
                        "DANKIE",
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "ANNUAL OVERSEER CONTRIBUTION REPORT",
                          style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            letterSpacing: 1,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Contribution Year $_selectedYear",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Generated: ${DateTime.now().toString().split('.')[0]}",
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            // --- CUSTOM CHARTS ---
            if (topRegions.isNotEmpty || topOverseers.isNotEmpty) {
              content.add(
                pw.Text(
                  "LEADERBOARD SUMMARY",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              );
              content.add(pw.SizedBox(height: 15));

              if (topRegions.isNotEmpty) {
                content.add(
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "TOP 3 REGIONS BY CONTRIBUTION",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        ...topRegions.map(
                          (e) => _buildHorizontalBar(
                            e.key,
                            e.value,
                            maxRegionAmount,
                            primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                content.add(pw.SizedBox(height: 20));
              }

              if (topOverseers.isNotEmpty) {
                content.add(
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "TOP 10 OVERSEERS BY CONTRIBUTION",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        ...topOverseers.map(
                          (e) => _buildHorizontalBar(
                            e.key,
                            e.value,
                            maxOverseerAmount,
                            secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                content.add(pw.SizedBox(height: 30));
              }
            }

            // --- ITERATE THROUGH EVENTS ---
            content.add(
              pw.Text(
                "DETAILED EVENT BREAKDOWN",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            );
            content.add(pw.SizedBox(height: 15));

            for (var event in eventReports) {
              double eventTotal = 0.0;
              final contributions =
                  (event['contributions'] as List?)
                      ?.where((c) => c['has_contributed'] == true)
                      .toList() ??
                  [];

              if (contributions.isEmpty) continue;

              List<List<String>> tableData = [
                ['Overseer', 'Region', 'Contributed Amount'],
              ];

              for (var c in contributions) {
                double amt = double.tryParse(c['amount'].toString()) ?? 0.0;
                eventTotal += amt;
                grandTotal += amt;

                tableData.add([
                  c['overseer_name']?.toString() ?? 'Unknown',
                  "${c['region']} - ${c['province']}",
                  "R ${amt.toStringAsFixed(2)}",
                ]);
              }

              content.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 30),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: pw.BoxDecoration(
                          color: headerColor,
                          border: pw.Border(
                            left: pw.BorderSide(color: primaryColor, width: 4),
                          ),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  event['title'] ?? 'Unknown Event',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  "Date: ${event['day']} ${event['month'] ?? ''} ${event['year']}",
                                  style: const pw.TextStyle(
                                    fontSize: 10,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ),
                            pw.Text(
                              "Total: R ${eventTotal.toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 10),

                      pw.TableHelper.fromTextArray(
                        headers: tableData.first,
                        data: tableData.sublist(1),
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                        headerDecoration: pw.BoxDecoration(color: primaryColor),
                        cellHeight: 24,
                        cellAlignments: {
                          0: pw.Alignment.centerLeft,
                          1: pw.Alignment.centerLeft,
                          2: pw.Alignment.centerRight,
                        },
                        cellStyle: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.black,
                        ),
                        oddRowDecoration: const pw.BoxDecoration(
                          color: PdfColors.grey100,
                        ),
                        border: pw.TableBorder(
                          horizontalInside: pw.BorderSide(
                            color: borderColor,
                            width: 0.5,
                          ),
                          bottom: pw.BorderSide(
                            color: primaryColor,
                            width: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // --- GRAND TOTAL FOOTER ---
            content.add(pw.SizedBox(height: 10));
            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: primaryColor, width: 2.0),
                    bottom: pw.BorderSide(color: primaryColor, width: 2.0),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "TOTAL VERIFIED CONTRIBUTIONS",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.Text(
                      "R ${grandTotal.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );

            content.add(pw.SizedBox(height: 40));
            content.add(
              pw.Center(
                child: pw.Text(
                  "*** END OF REPORT ***",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            );

            return content;
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Dankie_Annual_Report_$_selectedYear.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to generate PDF: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      appBar: AppBar(
        title: Text(
          "Annual Report",
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: neumoBaseColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryColor),
      ),

      floatingActionButton: isLoading || errorMessage.isNotEmpty
          ? null
          : GestureDetector(
              onTap: _isGeneratingPdf ? null : _generateAndDownloadPDF,
              child: NeumorphicContainer(
                color: theme.primaryColor,
                borderRadius: 30,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGeneratingPdf)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(Icons.download_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      _isGeneratingPdf ? "Generating..." : "Download PDF",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Text(
                  "Select Year:",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: NeumorphicContainer(
                    isPressed: true,
                    borderRadius: 12,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedYear,
                        isExpanded: true,
                        icon: Icon(
                          Icons.calendar_month,
                          color: theme.primaryColor,
                        ),
                        items: _availableYears.map((String year) {
                          return DropdownMenuItem<String>(
                            value: year,
                            child: Text(
                              year,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null &&
                              newValue != _selectedYear &&
                              !_isGeneratingPdf) {
                            setState(() {
                              _selectedYear = newValue;
                            });
                            fetchAnnualReport();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  )
                : errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                : eventReports.isEmpty
                ? Center(
                    child: Text(
                      "No events found for $_selectedYear.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: _desktopContentMaxWidth,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 10,
                          bottom: 100,
                        ),
                        itemCount: eventReports.length,
                        itemBuilder: (context, index) {
                          final event = eventReports[index];
                          final List contributions =
                              event['contributions'] ?? [];

                          double totalAmount = 0;
                          for (var c in contributions) {
                            if (c['has_contributed'] == true) {
                              totalAmount +=
                                  double.tryParse(c['amount'].toString()) ??
                                  0.0;
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: NeumorphicContainer(
                              color: neumoBaseColor,
                              isPressed: false,
                              borderRadius: 20,
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['title'] ?? 'Unknown Event',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    "Total Verified: R ${totalAmount.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 15),
                                  Divider(
                                    color: theme.primaryColor.withOpacity(0.2),
                                  ),
                                  SizedBox(height: 10),
                                  contributions.isEmpty
                                      ? Text(
                                          "No contributions recorded yet.",
                                          style: TextStyle(
                                            color: theme.hintColor,
                                          ),
                                        )
                                      : Column(
                                          children: contributions
                                              .where(
                                                (c) =>
                                                    c['has_contributed'] ==
                                                    true,
                                              )
                                              .map<Widget>((contrib) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 12.0,
                                                      ),
                                                  child: NeumorphicContainer(
                                                    color: neumoBaseColor,
                                                    isPressed: true,
                                                    borderRadius: 12,
                                                    padding: EdgeInsets.all(12),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                contrib['overseer_name'] ??
                                                                    'Unknown',
                                                                style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: theme
                                                                      .primaryColor,
                                                                ),
                                                              ),
                                                              Text(
                                                                "${contrib['region']} - ${contrib['province']}",
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: theme
                                                                      .hintColor,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Text(
                                                          "R ${double.parse(contrib['amount'].toString()).toStringAsFixed(2)}",
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: theme
                                                                .primaryColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              })
                                              .toList(),
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
