// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_web_libraries_in_flutter, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';

import '../../Components/NeuDesign.dart';

// --- Platform Utilities ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// --- Data Models ---

class DistrictElderModel {
  final String name;
  final String subLoc;
  final double income;

  final double expenseRent;
  final double expenseWine;
  final double expensePower;
  final double expenseSundries;
  final double expenseCentral;
  final double expenseEquipment;
  final double expenseOther;

  final double bankedOverride;
  final String remarks;

  DistrictElderModel({
    required this.name,
    this.subLoc = '',
    this.income = 0.0,
    this.expenseRent = 0.0,
    this.expenseWine = 0.0,
    this.expensePower = 0.0,
    this.expenseSundries = 0.0,
    this.expenseCentral = 0.0,
    this.expenseEquipment = 0.0,
    this.expenseOther = 0.0,
    this.bankedOverride = 0.0,
    this.remarks = '',
  });

  double get totalExpenses =>
      expenseRent +
      expenseWine +
      expensePower +
      expenseSundries +
      expenseCentral +
      expenseEquipment +
      expenseOther;

  double get totalBanked =>
      bankedOverride != 0.0 ? bankedOverride : (income - totalExpenses);
}

class OverseerEntry {
  final String overseerName;
  final String code;
  final String region;
  final String province;
  final List<DistrictElderModel> elders;

  OverseerEntry({
    required this.overseerName,
    required this.code,
    required this.region,
    required this.province,
    required this.elders,
  });

  // ⭐️ FIX: Exclude the "D/E Total" sub-rows from the sum to prevent exactly doubling the amounts on the dashboard
  double get totalIncome => elders
      .where((e) => e.subLoc != "D/E Total")
      .fold(0, (sum, item) => sum + item.income);

  // ⭐️ FIX: Exclude the "D/E Total" sub-rows here as well
  double get totalBanked => elders
      .where((e) => e.subLoc != "D/E Total")
      .fold(0, (sum, item) => sum + item.totalBanked);
}

// --- Main Widget ---

class OverseerBalancesheetGlobal extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const OverseerBalancesheetGlobal({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<OverseerBalancesheetGlobal> createState() =>
      _OverseerBalancesheetGlobalState();
}

class _OverseerBalancesheetGlobalState
    extends State<OverseerBalancesheetGlobal> {
  bool _isLoading = true;
  List<OverseerEntry> _allOverseers = [];
  List<OverseerEntry> _filteredOverseers = [];

  // Filters
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedProvince = 'All';
  final List<String> _provinces = [
    'All',
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];

  String _selectedMonth = 'All';
  String _selectedYear = 'All';

  final List<String> _months = [
    'All',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<String> _years =
      ['All'] + List.generate(10, (index) => (2024 + index).toString());

  final currencyFormat = NumberFormat.currency(locale: 'en_ZA', symbol: 'R');
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _fetchDataOptimized();
    _loadLogoBytes();
  }

  int monthStringToInt(String m) {
    return _months.indexOf(m);
  }

  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String placeholder,
    required Color baseColor,
    IconData? prefixIcon,
    Function(String)? onChanged,
    Widget? suffixIcon,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    return NeumorphicContainer(
      isPressed: true,
      color: baseColor,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: theme.primaryColor)
              : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 10.0,
          ),
        ),
      ),
    );
  }

  Future<void> _fetchDataOptimized() async {
    setState(() => _isLoading = true);
    try {
      String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      Map<String, String> headers = {};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      String queryParams = "";
      if (_selectedProvince != 'All')
        queryParams += "&province=$_selectedProvince";

      final results = await Future.wait([
        http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?limit=3000$queryParams',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/districts/?limit=3000$queryParams',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/?limit=10000'),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/overseer_expenses_reports/?limit=5000$queryParams',
          ),
          headers: headers,
        ),
      ]);

      if (results[0].statusCode != 200) {
        throw Exception("Failed to fetch Overseers");
      }

      final List overseerDocs = json.decode(results[0].body);
      final List districtDocs = results[1].statusCode == 200
          ? json.decode(results[1].body)
          : [];
      final List userDocs = results[2].statusCode == 200
          ? json.decode(results[2].body)
          : [];
      final List expenseDocs = results[3].statusCode == 200
          ? json.decode(results[3].body)
          : [];

      double safeParse(dynamic val) {
        if (val == null) return 0.0;
        if (val is num) return val.toDouble();
        if (val is String) {
          return double.tryParse(val) ?? 0.0;
        }
        return 0.0;
      }

      Map<String, List<dynamic>> districtsByOverseer = {};
      for (var dist in districtDocs) {
        final oUid = dist['overseer_uid'] ?? dist['overseerUid'];
        if (oUid != null) {
          if (!districtsByOverseer.containsKey(oUid))
            districtsByOverseer[oUid] = [];
          districtsByOverseer[oUid]!.add(dist);
        }
      }

      Map<String, List<dynamic>> usersByOverseer = {};
      for (var userData in userDocs) {
        final uid = userData['overseer_uid'] ?? userData['overseerUid'];
        final bool isArchived = userData['archived'] ?? false;
        if (uid != null && !isArchived) {
          if (!usersByOverseer.containsKey(uid)) usersByOverseer[uid] = [];
          usersByOverseer[uid]!.add(userData);
        }
      }

      Map<String, dynamic> uniqueExpDocs = {};
      for (var data in expenseDocs) {
        String oUid = data['overseer_uid'] ?? data['overseerUid'] ?? '';
        String dName =
            data['district_elder_name'] ??
            data['districtElderName'] ??
            'Direct';
        String cName =
            data['community_name'] ?? data['communityName'] ?? 'Main';
        String year = (data['year'] ?? '').toString();
        String month = (data['month'] ?? '').toString();
        String uniqueKey = "${oUid}_${dName}_${cName}_${year}_${month}";
        uniqueExpDocs[uniqueKey] = data;
      }

      Map<String, Map<String, Map<String, Map<String, double>>>> expensesMap =
          {};
      int selectedMonthInt = monthStringToInt(_selectedMonth);

      for (var data in uniqueExpDocs.values) {
        if (_selectedMonth != 'All') {
          final rMonth =
              int.tryParse((data['month'] ?? '').toString().trim()) ?? 0;
          if (rMonth != selectedMonthInt) continue;
        }
        if (_selectedYear != 'All') {
          final rYear = (data['year'] ?? '').toString().trim();
          if (rYear != _selectedYear) continue;
        }

        final String oUid = data['overseer_uid'] ?? data['overseerUid'] ?? '';
        final String dName =
            data['district_elder_name'] ??
            data['districtElderName'] ??
            'Direct';
        final String cName =
            data['community_name'] ?? data['communityName'] ?? 'Main';

        if (oUid.isEmpty) continue;

        if (!expensesMap.containsKey(oUid)) expensesMap[oUid] = {};
        if (!expensesMap[oUid]!.containsKey(dName))
          expensesMap[oUid]![dName] = {};
        if (!expensesMap[oUid]![dName]!.containsKey(cName)) {
          expensesMap[oUid]![dName]![cName] = {
            'income': 0.0,
            'rent': 0.0,
            'wine': 0.0,
            'power': 0.0,
            'sundries': 0.0,
            'central': 0.0,
            'equipment': 0.0,
            'other': 0.0,
            'banked': 0.0,
          };
        }

        var current = expensesMap[oUid]![dName]![cName]!;

        current['income'] =
            current['income']! +
            safeParse(data['total_income'] ?? data['totalIncome']);
        current['rent'] =
            current['rent']! +
            safeParse(data['expense_rent'] ?? data['expenseRent']);
        current['wine'] =
            current['wine']! +
            safeParse(data['expense_wine'] ?? data['expenseWine']);
        current['power'] =
            current['power']! + safeParse(data['expense_power'] ?? 0.0);
        current['sundries'] =
            current['sundries']! + safeParse(data['expense_sundries'] ?? 0.0);
        current['equipment'] =
            current['equipment']! + safeParse(data['expense_equipment'] ?? 0.0);
        current['central'] =
            current['central']! +
            safeParse(data['expense_central'] ?? data['expenseCentral']);
        current['other'] =
            current['other']! +
            safeParse(data['expense_other'] ?? data['expenseOther']);
        current['banked'] =
            current['banked']! +
            safeParse(data['total_banked'] ?? data['totalBanked']);
      }

      List<OverseerEntry> tempOverseers = [];

      for (var data in overseerDocs) {
        final String uid = data['uid'] ?? '';
        final String name =
            data['overseer_initials_surname'] ??
            data['overseerInitialsAndSurname'] ??
            'Unknown';
        final String code = data['code'] ?? '';
        final String region = data['region'] ?? 'Unknown';
        final String province = data['province'] ?? 'Unknown';

        final myDistricts = districtsByOverseer[uid] ?? [];
        final myUsers = usersByOverseer[uid] ?? [];

        Map<String, Map<String, double>> aggregatedIncome = {};

        for (var dist in myDistricts) {
          String dName = (dist['district_elder_name'] ?? '').trim();
          if (dName.isEmpty) continue;
          if (!aggregatedIncome.containsKey(dName))
            aggregatedIncome[dName] = {};

          List<dynamic> communities = dist['communities'] ?? [];
          for (var comm in communities) {
            String cName = (comm['community_name'] ?? '').trim();
            if (cName.isNotEmpty) {
              aggregatedIncome[dName]![cName] = 0.0;
            }
          }
        }

        if (_selectedMonth == 'All') {
          for (var userData in myUsers) {
            String dName =
                (userData['district_elder_name'] ??
                        userData['districtElderName'] ??
                        '')
                    .trim();
            if (dName.isEmpty) dName = "Direct";

            String cName =
                (userData['community_name'] ??
                        userData['communityName'] ??
                        'Main')
                    .trim();

            final double w1 = safeParse(userData['week1']);
            final double w2 = safeParse(userData['week2']);
            final double w3 = safeParse(userData['week3']);
            final double w4 = safeParse(userData['week4']);
            final double total = w1 + w2 + w3 + w4;

            if (!aggregatedIncome.containsKey(dName))
              aggregatedIncome[dName] = {};
            if (!aggregatedIncome[dName]!.containsKey(cName)) {
              aggregatedIncome[dName]![cName] = 0.0;
            }
            aggregatedIncome[dName]![cName] =
                aggregatedIncome[dName]![cName]! + total;
          }
        }

        if (expensesMap.containsKey(uid)) {
          expensesMap[uid]!.forEach((dName, comms) {
            if (!aggregatedIncome.containsKey(dName))
              aggregatedIncome[dName] = {};
            comms.forEach((cName, val) {
              if (!aggregatedIncome[dName]!.containsKey(cName)) {
                aggregatedIncome[dName]![cName] = 0.0;
              }
            });
          });
        }

        List<DistrictElderModel> elderEntries = [];
        aggregatedIncome.forEach((elderName, communities) {
          bool isFirst = true;
          double groupTotalIncome = 0;
          double groupTotalBanked = 0;
          bool isDirectGroup = elderName == "Direct";

          if (communities.isEmpty) {
            elderEntries.add(
              DistrictElderModel(name: elderName, subLoc: "No Activity"),
            );
          }

          communities.forEach((communityName, liveIncome) {
            double exRent = 0,
                exWine = 0,
                exPower = 0,
                exSundries = 0,
                exCentral = 0,
                exEquipment = 0,
                exOther = 0;
            double archivedIncome = 0, archivedBanked = 0;

            if (expensesMap.containsKey(uid) &&
                expensesMap[uid]!.containsKey(elderName) &&
                expensesMap[uid]![elderName]!.containsKey(communityName)) {
              var exData = expensesMap[uid]![elderName]![communityName]!;
              exRent = exData['rent']!;
              exWine = exData['wine']!;
              exPower = exData['power']!;
              exSundries = exData['sundries']!;
              exCentral = exData['central']!;
              exEquipment = exData['equipment']!;
              exOther = exData['other']!;
              archivedIncome = exData['income']!;
              archivedBanked = exData['banked']!;
            }

            double combinedIncome = liveIncome + archivedIncome;

            var model = DistrictElderModel(
              name: isDirectGroup ? "" : (isFirst ? elderName : ""),
              subLoc: communityName,
              income: combinedIncome,
              expenseRent: exRent,
              expenseWine: exWine,
              expensePower: exPower,
              expenseSundries: exSundries,
              expenseCentral: exCentral,
              expenseEquipment: exEquipment,
              expenseOther: exOther,
              bankedOverride: archivedBanked > 0 ? archivedBanked : 0.0,
            );

            elderEntries.add(model);
            isFirst = false;

            groupTotalIncome += combinedIncome;
            groupTotalBanked += model.totalBanked;
          });

          if (!isDirectGroup && communities.length > 1) {
            elderEntries.add(
              DistrictElderModel(
                name: "",
                subLoc: "D/E Total",
                income: groupTotalIncome,
                bankedOverride: groupTotalBanked,
                expenseRent: 0,
              ),
            );
          }
        });

        if (elderEntries.isEmpty) {
          elderEntries.add(
            DistrictElderModel(name: "-", subLoc: "No Activity"),
          );
        }

        tempOverseers.add(
          OverseerEntry(
            overseerName: name,
            code: code,
            region: region,
            province: province,
            elders: elderEntries,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allOverseers = tempOverseers;
          _isLoading = false;
        });
        _filterData();
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterData() {
    setState(() {
      var temp = _allOverseers;

      if (_selectedProvince != 'All') {
        temp = temp.where((o) => o.province == _selectedProvince).toList();
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        temp = temp.where((o) {
          final matchOverseer = o.overseerName.toLowerCase().contains(q);
          final matchDistrict = o.elders.any(
            (e) => e.name.toLowerCase().contains(q),
          );
          final matchCode = o.code.toLowerCase().contains(q);
          return matchOverseer || matchDistrict || matchCode;
        }).toList();
      }

      _filteredOverseers = temp;
    });
  }

  Future<void> _loadLogoBytes() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      setState(() => _logoBytes = bytes.buffer.asUint8List());
    } catch (e) {
      print("Error loading logo: $e");
    }
  }

  Future<void> _generatePdfReport() async {
    try {
      isIOSPlatform
          ? Api().showIosLoading(context)
          : Api().showLoading(context);
      if (_filteredOverseers.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("No data to print")));
        Navigator.of(context).pop();
        return;
      }

      final pdf = pw.Document();
      final font = pw.Font.helvetica();
      final boldFont = pw.Font.helveticaBold();

      final ttf = await rootBundle.load('assets/CloisterBlack.ttf');
      final cloisterFont = pw.Font.ttf(ttf);

      final regions = _getRegionStats();
      final topIncome = _getTopOverseers(10, true);
      final topBanked = _getTopOverseers(10, false);
      final totalIncome = _filteredOverseers.fold(
        0.0,
        (sum, o) => sum + o.totalIncome,
      );
      final totalBanked = _filteredOverseers.fold(
        0.0,
        (sum, o) => sum + o.totalBanked,
      );

      final List<List<String>> tableData = [];
      for (var o in _filteredOverseers) {
        for (var i = 0; i < o.elders.length; i++) {
          final e = o.elders[i];
          final isFirst = i == 0;
          String f(double v) => v == 0 ? "-" : currencyFormat.format(v);
          tableData.add([
            isFirst ? o.overseerName : "",
            isFirst ? o.region : "",
            e.name,
            e.subLoc,
            f(e.income),
            f(e.expenseRent),
            f(e.expenseWine),
            f(e.expensePower),
            f(e.expenseSundries),
            f(e.expenseCentral),
            f(e.expenseEquipment),
            f(e.totalExpenses),
            f(e.totalBanked),
          ]);
        }
        tableData.add(["", "", "", "", "", "", "", "", "", "", "", "", ""]);
      }

      pw.Widget buildPdfPieChart(String title, List<PieData> data) {
        if (data.isEmpty || data.every((e) => e.value == 0)) {
          return pw.Container(
            height: 100,
            width: 100,
            child: pw.Center(child: pw.Text("No Data")),
          );
        }
        data.sort((a, b) => b.value.compareTo(a.value));
        final chartData = data.take(8).toList();

        final colors = [
          PdfColors.blue,
          PdfColors.red,
          PdfColors.green,
          PdfColors.orange,
          PdfColors.purple,
          PdfColors.cyan,
          PdfColors.brown,
          PdfColors.pink,
        ];

        return pw.Column(
          children: [
            pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 10)),
            pw.SizedBox(height: 5),
            pw.SizedBox(
              height: 120,
              width: 120,
              child: pw.Chart(
                title: pw.Text(title),
                grid: pw.PieGrid(),
                datasets: List.generate(chartData.length, (index) {
                  return pw.PieDataSet(
                    legend: chartData[index].name,
                    value: chartData[index].value,
                    color: colors[index % colors.length],
                    legendStyle: pw.TextStyle(fontSize: 8),
                  );
                }),
              ),
            ),
          ],
        );
      }

      pw.Widget buildPdfTopTable(
        String title,
        List<OverseerEntry> list,
        bool isIncome,
      ) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 10)),
            pw.Table.fromTextArray(
              headers: ['#', 'Name', 'Region', 'Amount'],
              data: list
                  .asMap()
                  .entries
                  .map(
                    (e) => [
                      (e.key + 1).toString(),
                      e.value.overseerName,
                      e.value.region,
                      currencyFormat.format(
                        isIncome ? e.value.totalIncome : e.value.totalBanked,
                      ),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontSize: 8,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
            ),
          ],
        );
      }

      pw.Widget _buildHeader(pw.Font font, Uint8List? logo) {
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            if (logo != null)
              pw.Container(
                width: 160,
                height: 160,
                margin: const pw.EdgeInsets.only(right: 15),
                child: pw.Image(pw.MemoryImage(logo)),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  "The Twelve Apostles Church in Trinity",
                  style: pw.TextStyle(font: font, fontSize: 35),
                ),
                pw.Text(
                  "P. O. Box 40376, Red Hill, 4071",
                  style: pw.TextStyle(fontSize: 18, font: font),
                ),
                pw.Text(
                  "Tel. / Fax No's: (031) 569 6164",
                  style: pw.TextStyle(fontSize: 18, font: font),
                ),
                pw.Text(
                  "Email: thetacc@telkomsa.net",
                  style: const pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.blue,
                  ),
                ),
              ],
            ),
          ],
        );
      }

      pdf.addPage(
        pw.MultiPage(
          maxPages: 1000,
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            _buildHeader(cloisterFont, _logoBytes),
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "$_selectedProvince Summary Balance Sheet - $_selectedMonth $_selectedYear",
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                  pw.Text(
                    "Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                  ),
                ],
              ),
            ),
            pw.Text(
              "Filter: $_selectedProvince | Search: ${_searchQuery.isEmpty ? 'None' : _searchQuery}",
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              "Provincial Summary",
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 5),
            pw.Table.fromTextArray(
              headers: ['Region', 'Income', 'Banked', '% Banked'],
              data: [
                ...regions.entries.map((e) {
                  final income = e.value['income']!;
                  final banked = e.value['banked']!;
                  final pct = income > 0
                      ? (banked / income * 100).toStringAsFixed(0)
                      : "0";
                  return [
                    e.key,
                    currencyFormat.format(income),
                    currencyFormat.format(banked),
                    "$pct%",
                  ];
                }),
                [
                  'TOTAL',
                  currencyFormat.format(totalIncome),
                  currencyFormat.format(totalBanked),
                  totalIncome > 0
                      ? "${(totalBanked / totalIncome * 100).toStringAsFixed(0)}%"
                      : "0%",
                ],
              ],
              headerStyle: pw.TextStyle(
                font: boldFont,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 15),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                buildPdfPieChart(
                  "Income by Region",
                  regions.entries
                      .map((e) => PieData(e.key, e.value['income']!))
                      .toList(),
                ),
                buildPdfPieChart(
                  "Top 10 Income",
                  topIncome
                      .map((e) => PieData(e.overseerName, e.totalIncome))
                      .toList(),
                ),
                buildPdfPieChart(
                  "Top 10 Banked",
                  topBanked
                      .map((e) => PieData(e.overseerName, e.totalBanked))
                      .toList(),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: buildPdfTopTable("Top 10 Income", topIncome, true),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: buildPdfTopTable("Top 10 Banked", topBanked, false),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              "Regional Top 3 Performers",
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: regions.keys.map((region) {
                final tops = _getTopOverseersByRegion(region, 3, true);
                if (tops.isEmpty || tops.every((t) => t.totalIncome == 0))
                  return pw.SizedBox();
                return pw.Container(
                  width: 150,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        region,
                        style: pw.TextStyle(font: boldFont, fontSize: 9),
                      ),
                      ...tops.map(
                        (o) => pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                o.overseerName,
                                style: pw.TextStyle(fontSize: 8),
                                overflow: pw.TextOverflow.clip,
                              ),
                            ),
                            pw.Text(
                              currencyFormat.format(o.totalIncome),
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              "Detailed Breakdown",
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 5),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              headers: [
                'Overseer',
                'Region',
                'District',
                'Community',
                'Income',
                'Rent',
                'Wine',
                'Power',
                'Sundries',
                'Central',
                'Equip',
                'Exp Total',
                'Banked',
              ],
              data: tableData,
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontSize: 6.5,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 6.5),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
                7: pw.Alignment.centerRight,
                8: pw.Alignment.centerRight,
                9: pw.Alignment.centerRight,
                10: pw.Alignment.centerRight,
                11: pw.Alignment.centerRight,
                12: pw.Alignment.centerRight,
              },
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop();
      debugPrint("PDF Gen Error: $e");
      Api().showMessage(context, "Error message: $e", "Error", Colors.red);
    }
  }

  Map<String, Map<String, double>> _getRegionStats() {
    Map<String, Map<String, double>> stats = {};
    for (var o in _filteredOverseers) {
      String reg = o.region.trim().isEmpty ? 'Unknown' : o.region.trim();
      if (!stats.containsKey(reg)) stats[reg] = {'income': 0.0, 'banked': 0.0};
      stats[reg]!['income'] = stats[reg]!['income']! + o.totalIncome;
      stats[reg]!['banked'] = stats[reg]!['banked']! + o.totalBanked;
    }
    return stats;
  }

  List<OverseerEntry> _getTopOverseers(int count, bool byIncome) {
    List<OverseerEntry> list = List.from(_filteredOverseers);
    list.sort(
      (a, b) => byIncome
          ? b.totalIncome.compareTo(a.totalIncome)
          : b.totalBanked.compareTo(a.totalBanked),
    );
    var active = list
        .where((o) => byIncome ? o.totalIncome > 0 : o.totalBanked > 0)
        .toList();
    return active.take(count).toList();
  }

  List<OverseerEntry> _getTopOverseersByRegion(
    String region,
    int count,
    bool byIncome,
  ) {
    List<OverseerEntry> list = _filteredOverseers
        .where((o) => o.region.trim() == region)
        .toList();
    list.sort(
      (a, b) => byIncome
          ? b.totalIncome.compareTo(a.totalIncome)
          : b.totalBanked.compareTo(a.totalBanked),
    );
    var active = list
        .where((o) => byIncome ? o.totalIncome > 0 : o.totalBanked > 0)
        .toList();
    return active.take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Column(
        children: [
          _buildControls(isMobile, neumoBaseColor),
          SizedBox(height: 5),
          Expanded(
            child: _isLoading
                ? Api().isIOSPlatform
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoActivityIndicator(),
                              Text('  Loading data...'),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              Text('  Loading data...'),
                            ],
                          ),
                        )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildSummaryDashboard(isMobile, neumoBaseColor),
                        const SizedBox(height: 25),
                        _buildChartsSection(isMobile, neumoBaseColor),
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Detailed Breakdown",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 15),
                              NeumorphicContainer(
                                color: neumoBaseColor,
                                borderRadius: 15,
                                padding: EdgeInsets.all(15),
                                child: _buildDetailedTable(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 50),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isMobile, Color baseColor) {
    return NeumorphicContainer(
      color: baseColor,
      borderRadius: 0,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildNeumorphicDropdown<String>(
                      baseColor: baseColor,
                      label: "Month",
                      value: _selectedMonth,
                      items: _months,
                      onChanged: (val) {
                        setState(() {
                          _selectedMonth = val!;
                        });
                        _fetchDataOptimized();
                      },
                    ),
                    _buildNeumorphicDropdown<String>(
                      baseColor: baseColor,
                      label: "Year",
                      value: _selectedYear,
                      items: _years,
                      onChanged: (val) {
                        setState(() {
                          _selectedYear = val!;
                        });
                        _fetchDataOptimized();
                      },
                    ),
                    _buildNeumorphicDropdown<String>(
                      baseColor: baseColor,
                      label: "Province",
                      value: _selectedProvince,
                      items: _provinces,
                      onChanged: (val) {
                        setState(() {
                          _selectedProvince = val!;
                          _filterData();
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                GestureDetector(
                  onTap: _generatePdfReport,
                  child: NeumorphicContainer(
                    color: Colors.green.shade600,
                    borderRadius: 10,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Save PDF",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          _buildNeumorphicTextField(
            context: context,
            baseColor: baseColor,
            controller: _searchController,
            placeholder: "Search Overseer Name, Code, or District Name...",
            prefixIcon: Icons.search,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _filterData();
                    },
                  )
                : null,
            onChanged: (val) {
              setState(() => _searchQuery = val);
              _filterData();
            },
          ),
          if (isMobile) ...[
            const SizedBox(height: 15),
            GestureDetector(
              onTap: _generatePdfReport,
              child: NeumorphicContainer(
                color: Colors.red.shade600,
                borderRadius: 10,
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Export PDF",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNeumorphicDropdown<T>({
    required Color baseColor,
    required String label,
    required T value,
    required List<T> items,
    required Function(T?) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$label: ",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).primaryColor,
          ),
        ),
        NeumorphicContainer(
          isPressed: false,
          color: baseColor,
          borderRadius: 8,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              dropdownColor: baseColor,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w500,
              ),
              items: items
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v, child: Text(v.toString())),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDashboard(bool isMobile, Color baseColor) {
    final regions = _getRegionStats();
    final topIncome = _getTopOverseers(10, true);
    final topBanked = _getTopOverseers(10, false);
    final totalIncome = _filteredOverseers.fold(
      0.0,
      (sum, o) => sum + o.totalIncome,
    );
    final totalBanked = _filteredOverseers.fold(
      0.0,
      (sum, o) => sum + o.totalBanked,
    );

    return NeumorphicContainer(
      color: baseColor,
      borderRadius: 15,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "$_selectedProvince Summary",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              Spacer(),
              NeumorphicContainer(
                isPressed: true,
                color: baseColor,
                borderRadius: 20,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  _selectedMonth == 'All'
                      ? "ALL TIME"
                      : "$_selectedMonth $_selectedYear",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _selectedMonth == 'All'
                        ? Colors.blue[800]
                        : Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: isMobile ? double.infinity : 600,
            child: Table(
              border: TableBorder.all(color: Colors.grey.withOpacity(0.2)),
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                _tableHeader(['Region', 'Income', 'Banked', '% Banked']),
                ...regions.entries.map((e) {
                  final inc = e.value['income']!;
                  final bnk = e.value['banked']!;
                  return _tableRow([
                    e.key,
                    currencyFormat.format(inc),
                    currencyFormat.format(bnk),
                    inc > 0 ? "${(bnk / inc * 100).toStringAsFixed(0)}%" : "0%",
                  ]);
                }),
                _tableRow(
                  [
                    'TOTAL',
                    currencyFormat.format(totalIncome),
                    currencyFormat.format(totalBanked),
                    totalIncome > 0
                        ? "${(totalBanked / totalIncome * 100).toStringAsFixed(0)}%"
                        : "0%",
                  ],
                  isBold: true,
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          isMobile
              ? Column(
                  children: [
                    _buildTopListTable("Top 10 Income", topIncome, true),
                    SizedBox(height: 20),
                    _buildTopListTable("Top 10 Banked", topBanked, false),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTopListTable(
                        "Top 10 Income",
                        topIncome,
                        true,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTopListTable(
                        "Top 10 Banked",
                        topBanked,
                        false,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 30),
          Text(
            "Regional Top 3 Performers (Income)",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.start,
            children: regions.keys.map((region) {
              final tops = _getTopOverseersByRegion(region, 3, true);
              if (tops.isEmpty || tops.every((t) => t.totalIncome == 0))
                return const SizedBox();

              return NeumorphicContainer(
                color: baseColor,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                child: Container(
                  width: isMobile ? double.infinity : 300,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          "$region Top 3",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ...tops
                          .map(
                            (o) => Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    o.overseerName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    currencyFormat.format(o.totalIncome),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopListTable(
    String title,
    List<OverseerEntry> data,
    bool isIncome,
  ) {
    if (data.isEmpty) return SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(30),
                2: FixedColumnWidth(100),
              },
              children: [
                _tableHeader(['#', 'Name', 'Region', 'Amount']),
                ...data.asMap().entries.map(
                  (e) => _tableRow([
                    (e.key + 1).toString(),
                    e.value.overseerName,
                    e.value.region,
                    currencyFormat.format(
                      isIncome ? e.value.totalIncome : e.value.totalBanked,
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection(bool isMobile, Color baseColor) {
    final regions = _getRegionStats();
    final topIncome = _getTopOverseers(10, true);
    final topBanked = _getTopOverseers(10, false);

    List<Widget> charts = [
      _buildPieChart(
        "Income by Region",
        regions.entries.map((e) => PieData(e.key, e.value['income']!)).toList(),
      ),
      _buildPieChart(
        "Top 10 Income",
        topIncome.map((e) => PieData(e.overseerName, e.totalIncome)).toList(),
      ),
      _buildPieChart(
        "Top 10 Banked",
        topBanked.map((e) => PieData(e.overseerName, e.totalBanked)).toList(),
      ),
    ];

    if (isMobile) {
      return Column(
        children: charts
            .map(
              (chart) => NeumorphicContainer(
                color: baseColor,
                borderRadius: 15,
                padding: EdgeInsets.all(16),
                child: Container(height: 250, child: chart),
              ),
            )
            .toList(),
      );
    } else {
      return NeumorphicContainer(
        color: baseColor,
        borderRadius: 15,
        padding: const EdgeInsets.all(20),
        child: Container(
          height: 300,
          child: Row(
            children: charts.map((chart) => Expanded(child: chart)).toList(),
          ),
        ),
      );
    }
  }

  Widget _buildPieChart(String title, List<PieData> data) {
    if (data.isEmpty || data.every((e) => e.value == 0)) {
      return const Center(child: Text("No Data"));
    }

    data.sort((a, b) => b.value.compareTo(a.value));
    final chartData = data.take(8).toList();

    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: chartData.asMap().entries.map((e) {
                final color = Colors.primaries[e.key % Colors.primaries.length];
                return PieChartSectionData(
                  color: color,
                  value: e.value.value,
                  title: '',
                  radius: 40,
                );
              }).toList(),
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: chartData.asMap().entries.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  color: Colors.primaries[e.key % Colors.primaries.length],
                ),
                const SizedBox(width: 4),
                Text(e.value.name, style: const TextStyle(fontSize: 10)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDetailedTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
        columnWidths: const {
          0: FixedColumnWidth(70),
          1: FixedColumnWidth(30),
          2: FixedColumnWidth(60),
          3: FixedColumnWidth(140),
          4: FixedColumnWidth(130),
          5: FixedColumnWidth(100),
          6: FixedColumnWidth(70),
          7: FixedColumnWidth(70),
          8: FixedColumnWidth(70),
          9: FixedColumnWidth(70),
          10: FixedColumnWidth(70),
          11: FixedColumnWidth(70),
          12: FixedColumnWidth(60),
          13: FixedColumnWidth(90),
          14: FixedColumnWidth(90),
          15: FixedColumnWidth(100),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            children:
                [
                      'OVERSEER',
                      'CODE',
                      'REGION',
                      'DISTRICT',
                      'COMMUNITY',
                      'INCOME',
                      'RENT',
                      'WINE',
                      'POWER',
                      'SUNDRIES',
                      'CENTRAL',
                      'EQUIP',
                      'OTHER',
                      'EXP TOTAL',
                      'BANKED',
                      'REMARKS',
                    ]
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    .toList(),
          ),
          ..._filteredOverseers.expand((o) {
            return o.elders.asMap().entries.map((entry) {
              final e = entry.value;
              final isFirst = entry.key == 0;
              final isTotal = e.subLoc == "D/E Total";
              String valOrDash(double val) =>
                  val == 0 ? "-" : currencyFormat.format(val);

              return TableRow(
                decoration: BoxDecoration(
                  color: isTotal
                      ? Theme.of(context).primaryColor.withOpacity(0.05)
                      : Colors.transparent,
                ),
                children: [
                  _DataCell(isFirst ? o.overseerName : "", isBold: true),
                  _DataCell(isFirst ? o.code : ""),
                  _DataCell(isFirst ? o.region : ""),
                  _DataCell(e.name, isBold: true),
                  _DataCell(e.subLoc, isBold: isTotal),
                  _DataCell(
                    valOrDash(e.income),
                    align: TextAlign.right,
                    isBold: isTotal,
                  ),
                  _DataCell(valOrDash(e.expenseRent), align: TextAlign.right),
                  _DataCell(valOrDash(e.expenseWine), align: TextAlign.right),
                  _DataCell(valOrDash(e.expensePower), align: TextAlign.right),
                  _DataCell(
                    valOrDash(e.expenseSundries),
                    align: TextAlign.right,
                  ),
                  _DataCell(
                    valOrDash(e.expenseCentral),
                    align: TextAlign.right,
                  ),
                  _DataCell(
                    valOrDash(e.expenseEquipment),
                    align: TextAlign.right,
                  ),
                  _DataCell(valOrDash(e.expenseOther), align: TextAlign.right),
                  _DataCell(
                    valOrDash(e.totalExpenses),
                    align: TextAlign.right,
                    isBold: isTotal,
                  ),
                  _DataCell(
                    valOrDash(e.totalBanked),
                    align: TextAlign.right,
                    isBold: isTotal,
                  ),
                  _DataCell(e.remarks),
                ],
              );
            });
          }),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> texts) {
    return TableRow(
      decoration: BoxDecoration(color: Theme.of(context).primaryColor),
      children: texts
          .map(
            (t) => Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                t,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _tableRow(List<String> texts, {bool isBold = false, Color? color}) {
    return TableRow(
      decoration: BoxDecoration(color: color ?? Colors.transparent),
      children: texts
          .map(
            (t) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                t,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final TextAlign align;
  const _DataCell(
    this.text, {
    this.isBold = false,
    this.align = TextAlign.left,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 10,
        ),
        textAlign: align,
      ),
    );
  }
}

class PieData {
  final String name;
  final double value;
  PieData(this.name, this.value);
}
