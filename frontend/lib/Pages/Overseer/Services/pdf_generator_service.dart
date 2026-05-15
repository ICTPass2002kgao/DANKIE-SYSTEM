// ignore_for_file: prefer_const_constructors, avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // Auth UID only
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:ttact/Components/API.dart'; // Ensure API is imported

/// A Data Transfer Object to pass data from the UI to the PDF Generator
class ReportPdfData {
  final String districtElder;
  final String communityName;
  final String province;
  final String overseerName;
  final String overseerCode; // <--- ADDED
  final String region; // <--- ADDED
  final int month;
  final int year;
  final Uint8List? logoBytes;
  final bool isViewingHistory;

  // Financials
  final double week1Sum;
  final double week2Sum;
  final double week3Sum;
  final double week4Sum;
  final double monthEnd;
  final double others;
  final double totalIncome;

  final double rent;
  final double wine;
  final double power;
  final double sundries;
  final double council;
  final double equipment;
  final double totalExpenditure;
  final double creditBalance;

  // Dates
  final DateTime? dateWeek1;
  final DateTime? dateWeek2;
  final DateTime? dateWeek3;
  final DateTime? dateWeek4;
  final DateTime? dateMonthEnd;
  final DateTime? dateOthers;
  final DateTime? dateRent;
  final DateTime? dateWine;
  final DateTime? datePower;
  final DateTime? dateSundries;
  final DateTime? dateCouncil;
  final DateTime? dateEquipment;

  ReportPdfData({
    required this.districtElder,
    required this.communityName,
    required this.province,
    required this.overseerName,
    required this.overseerCode, // <--- ADDED
    required this.region, // <--- ADDED
    required this.month,
    required this.year,
    this.logoBytes,
    required this.isViewingHistory,
    required this.week1Sum,
    required this.week2Sum,
    required this.week3Sum,
    required this.week4Sum,
    required this.monthEnd,
    required this.others,
    required this.totalIncome,
    required this.rent,
    required this.wine,
    required this.power,
    required this.sundries,
    required this.council,
    required this.equipment,
    required this.totalExpenditure,
    required this.creditBalance,
    this.dateWeek1,
    this.dateWeek2,
    this.dateWeek3,
    this.dateWeek4,
    this.dateMonthEnd,
    this.dateOthers,
    this.dateRent,
    this.dateWine,
    this.datePower,
    this.dateSundries,
    this.dateCouncil,
    this.dateEquipment,
  });
}

class PdfGeneratorService {
  static Future<Uint8List> generatePdfDocument(
    PdfPageFormat format,
    ReportPdfData data,
  ) async {
    final pdf = pw.Document();

    // Load Font
    final ttf = await rootBundle.load('assets/CloisterBlack.ttf');
    final cloisterFont = pw.Font.ttf(ttf);

    // Fetch Balance Sheet Data (DJANGO)
    final balanceSheetRows = await _fetchBalanceSheetDataForPdf(
      data.districtElder,
      data.communityName,
      data.year,
      data.month,
      data.isViewingHistory,
    );

    final String currentMonth = _getMonthName(data.month);
    final String currentYear = data.year.toString();

    // --- PAGE 1: Income Statement ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 60, vertical: 30),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 10),
              _buildHeader(cloisterFont, data.logoBytes),
              pw.SizedBox(height: 20),
              _buildInfoTable(
                currentMonth,
                currentYear,
                data.overseerName,
                data.districtElder,
                data.communityName,
                data.province,
                data.overseerCode, // <--- Pass Code
                data.region, // <--- Pass Region
              ),
              pw.Expanded(child: _buildIncomeExpenditureTable(data)),
              pw.SizedBox(height: 10),
              _buildSignatures(data.overseerName, data.districtElder),
              pw.SizedBox(height: 10),
              pw.Text(
                "NB: Attach all receipts and Bank Deposit Slips with Neat and Clear Details",
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    // --- PAGE 2: Balance Sheet ---

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 60, vertical: 30),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              _buildHeader(cloisterFont, data.logoBytes),
              pw.SizedBox(height: 15),
              pw.Text(
                "Balance Sheet",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 10),
              balanceSheetRows,
              pw.Spacer(),
              _buildSignatures(data.overseerName, data.districtElder),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- Private Helper Methods ---

  static String _getMonthName(int month) {
    const m = [
      "",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return (month >= 1 && month <= 12) ? m[month] : "";
  }

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

  static pw.Widget _buildInfoTable(
    String m,
    String y,
    String o,
    String d,
    String c,
    String p,
    String code, // <--- Added Param
    String region, // <--- Added Param
  ) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      children: [
        pw.TableRow(
          children: [
            _cell("Income and Expenditure Statement for the Month:", m, true),
            _cell("Year:", y, true),
          ],
        ),
        pw.TableRow(
          children: [
            _cell("Overseer:", o, false),
            _cell("Code No:", code, false), // <--- Display Code
          ],
        ),
        pw.TableRow(
          children: [
            _cell("District Elder:", d, false),
            pw.Container(height: 15),
          ],
        ),
        pw.TableRow(
          children: [
            _cell("Community Elder:", "", false),
            pw.Container(height: 15),
          ],
        ),
        pw.TableRow(
          children: [
            _cell("Community Name:", c, false),
            pw.Container(height: 15),
          ],
        ),
        pw.TableRow(
          children: [
            _cell("Province:", p, false),
            _cell("Region:", region, false), // <--- Display Region
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(String t, String v, bool b) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Row(
        children: [
          pw.Text(
            t,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Text(v, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildIncomeExpenditureTable(ReportPdfData data) {
    String getR(double v) => v.toStringAsFixed(2).split('.')[0];
    String getC(double v) => v.toStringAsFixed(2).split('.')[1];
    String dateStr(DateTime? d) =>
        d != null ? "${d.year}-${d.month}-${d.day}" : "";

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(
                "Income / Receipts",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(
              child: _buildInnerTable([
                ["Tithe Offerings", "R", "c", true, null],
                [
                  "Week 1",
                  getR(data.week1Sum),
                  getC(data.week1Sum),
                  false,
                  dateStr(data.dateWeek1),
                ],
                [
                  "Week 2",
                  getR(data.week2Sum),
                  getC(data.week2Sum),
                  false,
                  dateStr(data.dateWeek2),
                ],
                [
                  "Week 3",
                  getR(data.week3Sum),
                  getC(data.week3Sum),
                  false,
                  dateStr(data.dateWeek3),
                ],
                [
                  "Week 4",
                  getR(data.week4Sum),
                  getC(data.week4Sum),
                  false,
                  dateStr(data.dateWeek4),
                ],
                [
                  "Month End",
                  getR(data.monthEnd),
                  getC(data.monthEnd),
                  false,
                  dateStr(data.dateMonthEnd),
                ],
                [
                  "Others",
                  getR(data.others),
                  getC(data.others),
                  false,
                  dateStr(data.dateOthers),
                ],
                [
                  "Total Income",
                  getR(data.totalIncome),
                  getC(data.totalIncome),
                  false,
                  null,
                  true,
                ],
              ]),
            ),
            pw.Container(
              child: _buildInnerTable([
                ["", "R", "c", true, null],
                [
                  "Rent Period",
                  getR(data.rent),
                  getC(data.rent),
                  false,
                  dateStr(data.dateRent),
                ],
                [
                  "Wine and Wafers",
                  getR(data.wine),
                  getC(data.wine),
                  false,
                  dateStr(data.dateWine),
                ],
                [
                  "Power and Lights",
                  getR(data.power),
                  getC(data.power),
                  false,
                  dateStr(data.datePower),
                ],
                [
                  "Sundries / Repairs",
                  getR(data.sundries),
                  getC(data.sundries),
                  false,
                  dateStr(data.dateSundries),
                ],
                [
                  "Central Council",
                  getR(data.council),
                  getC(data.council),
                  false,
                  dateStr(data.dateCouncil),
                ],
                [
                  "Equipment",
                  getR(data.equipment),
                  getC(data.equipment),
                  false,
                  dateStr(data.dateEquipment),
                ],
                [
                  "Total Expenditure",
                  getR(data.totalExpenditure),
                  getC(data.totalExpenditure),
                  false,
                  null,
                  true,
                ],
              ]),
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                "Please write your name and the name of your Community in the Deposit Slip Senders Details Column",
                style: pw.TextStyle(
                  fontSize: 8,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _bank("Bank Name", "Standard Bank"),
                _bank("Account Name", "The TACT"),
                _bank("Account No", "051074958"),
                _bank("Branch Name", "Kingsmead"),
                _bank("Branch Code", "040026"),
              ],
            ),
          ],
        ),
        pw.TableRow(
          children: [
            pw.Container(),
            pw.Container(
              padding: const pw.EdgeInsets.all(2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Credit Balance",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.Row(
                    children: [
                      pw.Text(
                        "R ${getR(data.creditBalance)}",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Text(
                        ". ${getC(data.creditBalance)}",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInnerTable(List<List<dynamic>> r) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(40),
        2: const pw.FixedColumnWidth(20),
      },
      children: r
          .map(
            (row) => pw.TableRow(
              decoration: row[3]
                  ? const pw.BoxDecoration(color: PdfColors.grey300)
                  : null,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        row[0],
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: (row[3] || (row.length > 5 && row[5]))
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                      if (row.length > 4 && row[4] != null && row[4].isNotEmpty)
                        pw.Text(
                          "Date: ${row[4]}",
                          style: const pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey700,
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(3),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(left: pw.BorderSide(width: 0.5)),
                  ),
                  child: pw.Text(
                    row[1],
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(3),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(left: pw.BorderSide(width: 0.5)),
                  ),
                  child: pw.Text(
                    row[2],
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _bank(String l, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 4, bottom: 1),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 8),
          children: [
            pw.TextSpan(
              text: "$l : ",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: v,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSignatures(String o, String e) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _sig("Overseer", o),
        _sig("District Elder", e),
        _sig("Treasurer", ""),
        _sig("Secretary", ""),
      ],
    );
  }

  static pw.Widget _sig(String l, String n) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 15),
        pw.Container(width: 80, height: 1, color: PdfColors.black),
        pw.Text("Signature", style: const pw.TextStyle(fontSize: 6)),
      ],
    );
  }

  // --- ⭐️ FETCH BALANCE SHEET DATA FROM DJANGO ---
  static Future<pw.Widget> _fetchBalanceSheetDataForPdf(
    String districtElder,
    String communityName,
    int year,
    int month,
    bool isViewingHistory,
  ) async {
    List<List<String>> data = [];
    double grandTotal = 0.0;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Determine correct endpoint
      String endpoint = isViewingHistory ? 'contribution_history' : 'users';

      // URL: /api/ENDPOINT/?overseer_uid=UID&district=D&community=C
      String urlStr =
          '${Api().BACKEND_BASE_URL_DEBUG}/$endpoint/?overseer_uid=$uid&district_elder_name=$districtElder&community_name=$communityName';

      if (isViewingHistory) {
        urlStr += '&year=$year&month=$month';
      }

      final response = await http.get(Uri.parse(urlStr));

      if (response.statusCode == 200) {
        final List records = json.decode(response.body);

        for (var d in records) {
          String name = "${d['name'] ?? ''} ${d['surname'] ?? ''}";
          double w1 = double.tryParse(d['week1']?.toString() ?? '0') ?? 0.0;
          double w2 = double.tryParse(d['week2']?.toString() ?? '0') ?? 0.0;
          double w3 = double.tryParse(d['week3']?.toString() ?? '0') ?? 0.0;
          double w4 = double.tryParse(d['week4']?.toString() ?? '0') ?? 0.0;

          double total = w1 + w2 + w3 + w4;
          grandTotal += total;

          data.add([
            name,
            w1 == 0 ? "-" : w1.toStringAsFixed(2),
            w2 == 0 ? "-" : w2.toStringAsFixed(2),
            w3 == 0 ? "-" : w3.toStringAsFixed(2),
            w4 == 0 ? "-" : w4.toStringAsFixed(2),
            total.toStringAsFixed(2),
          ]);
        }
      }
    } catch (e) {
      print("PDF Data Fetch Error: $e");
    }

    // Fill empty rows to maintain layout height
    while (data.length < 15) {
      data.add(["", "", "", "", "", ""]);
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children:
              [
                    "Members Name and Surname",
                    "WEEK 1",
                    "WEEK 2",
                    "WEEK 3",
                    "WEEK 4",
                    "MONTHLY",
                  ]
                  .map(
                    (e) => pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        e,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 7,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  )
                  .toList(),
        ),
        ...data
            .map(
              (row) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(
                      row[0],
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  ...row
                      .sublist(1)
                      .map(
                        (e) => pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(
                            e,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ),
                ],
              ),
            )
            .toList(),
        pw.TableRow(
          children: [
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                "GRAND TOTAL",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
            pw.Container(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.Container(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.Container(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.Container(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                "R ${grandTotal.toStringAsFixed(2)}",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
