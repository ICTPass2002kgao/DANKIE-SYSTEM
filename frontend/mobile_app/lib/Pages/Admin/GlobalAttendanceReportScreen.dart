// FILE: global_attendance_report_screen.dart

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/Overseer/components/pdf_generator_register.dart';

class GlobalAttendanceReportScreen extends StatefulWidget {
  const GlobalAttendanceReportScreen({super.key});

  @override
  State<GlobalAttendanceReportScreen> createState() =>
      _GlobalAttendanceReportScreenState();
}

class _GlobalAttendanceReportScreenState
    extends State<GlobalAttendanceReportScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _allData = [];

  Map<String, List<Map<String, dynamic>>> _groupedByProvince = {};

  int _overallTotal = 0;
  int _overallBrothers = 0;
  int _overallSisters = 0;
  int _overallParents = 0;
  int _overallVisitors = 0;
  int _overallTestifies = 0;
  int _overallReadyTestifies = 0;

  Color get _primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Not logged in.";
      });
      return;
    }

    try {
      final token = await user.getIdToken();
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final response = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/global_attendance_summary/?date=$dateStr',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> rawList = data
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        Map<String, List<Map<String, dynamic>>> grouped = {};
        int tTotal = 0,
            tBrothers = 0,
            tSisters = 0,
            tParents = 0,
            tVisitors = 0,
            tTestifies = 0,
            tReady = 0;

        for (var item in rawList) {
          String province = item['province'] ?? 'Unknown';
          if (!grouped.containsKey(province)) {
            grouped[province] = [];
          }
          grouped[province]!.add(item);

          // Explicit casts to int because JSON numbers are num
          tTotal += (item['total_present'] as int?) ?? 0;
          tBrothers += (item['brothers_present'] as int?) ?? 0;
          tSisters += (item['sisters_present'] as int?) ?? 0;
          tParents += (item['parents_present'] as int?) ?? 0;
          tVisitors += (item['visitors_present'] as int?) ?? 0;
          tTestifies += (item['testifies_present'] as int?) ?? 0;
          tReady += (item['ready_testifies'] as int?) ?? 0;
        }

        setState(() {
          _allData = rawList;
          _groupedByProvince = grouped;
          _overallTotal = tTotal;
          _overallBrothers = tBrothers;
          _overallSisters = tSisters;
          _overallParents = tParents;
          _overallVisitors = tVisitors;
          _overallTestifies = tTestifies;
          _overallReadyTestifies = tReady;
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load summary (${response.statusCode})");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error: ${e.toString()}";
      });
    }
  }

  // ---- PDF DOWNLOAD ----
  Future<void> _downloadPdf() async {
    if (_allData.isEmpty) {
      Api().showMessage(context, "No data to export.", "Error", Colors.red);
      return;
    }
    OverseerPdfGenerator.generateGlobalAttendanceReportPDF(
      context: context,
      selectedDate: _selectedDate,
      overseerDataList: _allData,
      overallTotal: _overallTotal,
      overallBrothers: _overallBrothers,
      overallSisters: _overallSisters,
      overallParents: _overallParents,
      overallVisitors: _overallVisitors,
      overallTestifies: _overallTestifies,
      overallReadyTestifies: _overallReadyTestifies,
      signatureBytes: null, // Optionally add signature logic later
      loggerName: '',
      loggerRole: '',
    );
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final neumoBase = Api().neumoBaseColor(context);
    return Scaffold(
      backgroundColor: neumoBase,
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _errorMessage != null
                ? _buildError(neumoBase)
                : _buildBody(neumoBase),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Api().neumoBaseColor(context),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: Offset(3, 3),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 15,
              offset: Offset(-3, -3),
            ),
          ],
        ),
        child: Center(child: CircularProgressIndicator(color: _primaryColor)),
      ),
    );
  }

  Widget _buildError(Color neumoBase) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchReport, child: Text("Retry")),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Color neumoBase) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date picker
          Center(
            child: NeumorphicContainer(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 100),
              child: IconButton(
                onPressed: _downloadPdf,
                icon: Icon(Icons.download),
              ),
            ),
          ),
          SizedBox(height: 10),
          NeumorphicContainer(
            borderRadius: 12,
            padding: const EdgeInsets.all(16),
            color: neumoBase,
            child: InkWell(
              onTap: _pickDate,
              child: Row(
                children: [
                  Icon(CupertinoIcons.calendar, color: _primaryColor, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Attendance for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Overall metrics cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                "Total Present",
                _overallTotal,
                Colors.blueGrey,
                neumoBase,
              ),
              _metricCard("Brothers", _overallBrothers, Colors.blue, neumoBase),
              _metricCard("Sisters", _overallSisters, Colors.pink, neumoBase),
              _metricCard("Parents", _overallParents, Colors.purple, neumoBase),
              _metricCard(
                "Visitors",
                _overallVisitors,
                Colors.orange,
                neumoBase,
              ),
              _metricCard(
                "Ready Testifies",
                _overallReadyTestifies,
                Colors.green,
                neumoBase,
              ),
            ],
          ),
          SizedBox(height: 24),

          // Pie Chart
          _buildPieChart(neumoBase),
          SizedBox(height: 24),

          // By Province Sections
          ..._groupedByProvince.entries.map(
            (entry) => _buildProvinceSection(entry.key, entry.value, neumoBase),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, int value, Color color, Color neumoBase) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 12,
        padding: const EdgeInsets.all(16),
        color: neumoBase,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Color neumoBase) {
    if (_overallTotal == 0) return SizedBox.shrink();
    final sections = <PieChartSectionData>[];
    if (_overallBrothers > 0)
      sections.add(
        PieChartSectionData(
          color: Colors.blue,
          value: _overallBrothers.toDouble(),
          title: 'Brothers',
          radius: 40,
          titleStyle: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    if (_overallSisters > 0)
      sections.add(
        PieChartSectionData(
          color: Colors.pink,
          value: _overallSisters.toDouble(),
          title: 'Sisters',
          radius: 40,
          titleStyle: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    if (_overallParents > 0)
      sections.add(
        PieChartSectionData(
          color: Colors.purple,
          value: _overallParents.toDouble(),
          title: 'Parents',
          radius: 40,
          titleStyle: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    if (_overallVisitors > 0)
      sections.add(
        PieChartSectionData(
          color: Colors.orange,
          value: _overallVisitors.toDouble(),
          title: 'Visitors',
          radius: 40,
          titleStyle: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    if (sections.isEmpty) return SizedBox.shrink();

    return NeumorphicContainer(
      color: neumoBase,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            "Membership Distribution",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvinceSection(
    String province,
    List<Map<String, dynamic>> overseers,
    Color neumoBase,
  ) {
    int provTotal = 0;
    for (var o in overseers) provTotal += (o['total_present'] as int?) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeumorphicContainer(
        borderRadius: 16,
        color: neumoBase,
        padding: const EdgeInsets.all(16),
        child: ExpansionTile(
          title: Text(
            "$province (${overseers.length} overseers, $provTotal present)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          children: [...overseers.map((o) => _buildOverseerRow(o, neumoBase))],
        ),
      ),
    );
  }

  Widget _buildOverseerRow(Map<String, dynamic> data, Color neumoBase) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['overseer_name'] ?? 'Unknown',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Region: ${data['region'] ?? 'N/A'}",
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Total: ${data['total_present']}",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                "B:${data['brothers_present']} S:${data['sisters_present']} P:${data['parents_present']} V:${data['visitors_present']}",
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
