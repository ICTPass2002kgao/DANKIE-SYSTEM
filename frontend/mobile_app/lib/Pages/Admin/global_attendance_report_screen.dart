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
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _attendeeSearchController =
      TextEditingController();

  List<Map<String, dynamic>> _allData = [];
  Map<String, List<Map<String, dynamic>>> _groupedByProvince = {};

  int _overallTotal = 0;
  int _overallBrothers = 0;
  int _overallSisters = 0;
  int _overallParents = 0;
  int _overallVisitors = 0;
  int _overallTestifies = 0;
  int _overallReadyTestifies = 0;

  String _topProvince = "N/A";
  int _topProvinceCount = 0;
  String _topRegion = "N/A";
  int _topRegionCount = 0;
  Map<String, int> _provinceTotals = {};

  List<Map<String, dynamic>> _spiritualParents = [];

  // Export toggle
  bool _includeAttendees = true;

  // Search filter for attendees
  String _attendeeSearchQuery = '';

  Color get _primaryColor => Theme.of(context).primaryColor;

  final List<String> _spiritualRoleOrder = [
    'Apostle',
    'Overseer',
    'District Elder',
    'Community Elder',
    'Priest',
    'Deacon',
  ];

  final Map<String, Color> _roleColors = {
    'Apostle': Colors.blue,
    'Overseer': Colors.white,
    'District Elder': const Color(0xFF800000),
    'Community Elder': Colors.red,
    'Priest': Colors.green,
    'Deacon': Colors.yellow,
  };

  @override
  void initState() {
    super.initState();
    _fetchReport();
    _attendeeSearchController.addListener(() {
      setState(() {
        _attendeeSearchQuery = _attendeeSearchController.text
            .trim()
            .toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _attendeeSearchController.dispose();
    super.dispose();
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
        Map<String, int> provTotals = {};
        Map<String, int> regTotals = {};

        int tTotal = 0,
            tBrothers = 0,
            tSisters = 0,
            tParents = 0,
            tVisitors = 0,
            tTestifies = 0,
            tReady = 0;

        List<Map<String, dynamic>> allSpiritualParents = [];

        for (var item in rawList) {
          String province = item['province'] ?? 'Unknown';
          String region = item['region'] ?? 'Unknown';

          if (!grouped.containsKey(province)) {
            grouped[province] = [];
          }
          grouped[province]!.add(item);

          int currentTotal = (item['total_present'] as int?) ?? 0;
          tTotal += currentTotal;
          tBrothers += (item['brothers_present'] as int?) ?? 0;
          tSisters += (item['sisters_present'] as int?) ?? 0;
          tParents += (item['parents_present'] as int?) ?? 0;
          tVisitors += (item['visitors_present'] as int?) ?? 0;
          tTestifies += (item['testifies_present'] as int?) ?? 0;
          tReady += (item['ready_testifies'] as int?) ?? 0;

          provTotals[province] = (provTotals[province] ?? 0) + currentTotal;
          regTotals[region] = (regTotals[region] ?? 0) + currentTotal;

          List<dynamic> attendees = item['attendees'] ?? [];
          for (var a in attendees) {
            String role = a['role'] ?? '';
            if (_spiritualRoleOrder.contains(role)) {
              a['overseer_name'] = item['overseer_name'] ?? 'Unknown';
              allSpiritualParents.add(Map<String, dynamic>.from(a));
            }
          }
        }

        allSpiritualParents.sort((a, b) {
          int indexA = _spiritualRoleOrder.indexOf(a['role']);
          int indexB = _spiritualRoleOrder.indexOf(b['role']);
          if (indexA == -1) indexA = 999;
          if (indexB == -1) indexB = 999;
          return indexA.compareTo(indexB);
        });

        String topProv = "N/A";
        int topProvMax = 0;
        provTotals.forEach((key, value) {
          if (value > topProvMax) {
            topProvMax = value;
            topProv = key;
          }
        });

        String topReg = "N/A";
        int topRegMax = 0;
        regTotals.forEach((key, value) {
          if (value > topRegMax) {
            topRegMax = value;
            topReg = key;
          }
        });

        setState(() {
          _allData = rawList;
          _groupedByProvince = grouped;
          _provinceTotals = provTotals;
          _overallTotal = tTotal;
          _overallBrothers = tBrothers;
          _overallSisters = tSisters;
          _overallParents = tParents;
          _overallVisitors = tVisitors;
          _overallTestifies = tTestifies;
          _overallReadyTestifies = tReady;
          _topProvince = topProv;
          _topProvinceCount = topProvMax;
          _topRegion = topReg;
          _topRegionCount = topRegMax;
          _spiritualParents = allSpiritualParents;
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

  Future<void> _downloadPdf() async {
    if (_allData.isEmpty) {
      Api().showMessage(context, "No data to export.", "Error", Colors.red);
      return;
    }

    if (_serviceNameController.text.trim().isEmpty) {
      Api().showMessage(
        context,
        "Please specify a Service/Event name first.",
        "Required Fields",
        Colors.orange,
      );
      return;
    }

    Map<String, int> overallRoleCounts = {};
    for (var item in _allData) {
      var roles = item['role_counts'] as Map<String, dynamic>?;
      if (roles != null) {
        roles.forEach((key, value) {
          overallRoleCounts[key] =
              (overallRoleCounts[key] ?? 0) + (value as int);
        });
      }
    }

    List<Map<String, dynamic>> globalAttendees = [];
    for (var item in _allData) {
      List<dynamic> attendees = item['attendees'] ?? [];
      for (var a in attendees) {
        globalAttendees.add(Map<String, dynamic>.from(a));
      }
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
      overallRoleCounts: overallRoleCounts,
      globalAttendees: globalAttendees,
      includeAttendees: _includeAttendees, // Pass the toggle
      signatureBytes: null,
      loggerName: _serviceNameController.text.trim(),
      loggerRole: 'Global Report System',
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
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : _errorMessage != null
            ? _buildError(neumoBase)
            : _buildBody(neumoBase),
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
              offset: const Offset(3, 3),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 15,
              offset: const Offset(-3, -3),
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
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchReport,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry Connection"),
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Color neumoBase) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Config Section
          NeumorphicContainer(
            borderRadius: 14,
            padding: const EdgeInsets.all(16),
            color: neumoBase,
            child: InkWell(
              onTap: _pickDate,
              child: Row(
                children: [
                  Icon(CupertinoIcons.calendar, color: _primaryColor, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Target Analytical Date",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Premium Regional Insights Panel
          _buildInsightsPanel(neumoBase),
          const SizedBox(height: 20),

          // Core Metrics Summary Title
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                "Core Attendance Metrics",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                "Total Present",
                _overallTotal,
                Colors.blueGrey,
                neumoBase,
                Icons.people,
              ),
              _metricCard(
                "Brothers",
                _overallBrothers,
                Colors.blue,
                neumoBase,
                Icons.male,
              ),
              _metricCard(
                "Sisters",
                _overallSisters,
                Colors.pink,
                neumoBase,
                Icons.female,
              ),
              _metricCard(
                "Parents",
                _overallParents,
                Colors.purple,
                neumoBase,
                Icons.family_restroom,
              ),
              _metricCard(
                "Visitors",
                _overallVisitors,
                Colors.orange,
                neumoBase,
                Icons.card_membership,
              ),
              _metricCard(
                "Ready Testifies",
                _overallReadyTestifies,
                Colors.green,
                neumoBase,
                Icons.assignment_turned_in,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Visual Charts Section
          _buildVisualizations(neumoBase),
          const SizedBox(height: 24),

          // Spiritual Parents Table
          if (_spiritualParents.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Spiritual Parents",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NeumorphicContainer(
              color: neumoBase,
              borderRadius: 16,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text("Name", style: _tableHeaderStyle()),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("Role", style: _tableHeaderStyle()),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("Overseer", style: _tableHeaderStyle()),
                      ),
                    ],
                  ),
                  Divider(color: Colors.grey[300]),
                  ..._spiritualParents.map((p) {
                    String fullName = "${p['name'] ?? ''} ${p['surname'] ?? ''}"
                        .trim();
                    String role = p['role'] ?? '';
                    Color roleColor = _roleColors[role] ?? Colors.grey;
                    String overseerName = p['overseer_name'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor == Colors.white
                                    ? Colors.grey[200]
                                    : roleColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: roleColor == Colors.white
                                      ? Colors.grey[400]!
                                      : roleColor,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                role,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: roleColor == Colors.white
                                      ? Colors.black
                                      : roleColor,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              overseerName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Attendee Search Bar
          if (_allData.isNotEmpty) ...[
            NeumorphicContainer(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: neumoBase,
              child: TextField(
                controller: _attendeeSearchController,
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: _primaryColor),
                  hintText: "Search for an attendee...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // By Province Breakdowns (filtered by attendee search)
          Row(
            children: [
              Icon(Icons.map_outlined, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                "Provincial & Regional Segments",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._groupedByProvince.entries.map(
            (entry) => _buildProvinceSection(entry.key, entry.value, neumoBase),
          ),
          const SizedBox(height: 20),

          // Action Export Management Panel
          _buildExportPanel(neumoBase),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: Colors.grey[500],
      letterSpacing: 0.5,
    );
  }

  // ----- HELPER: Filter overseers by attendee search -----
  List<Map<String, dynamic>> _filterOverseers(
    List<Map<String, dynamic>> overseers,
  ) {
    if (_attendeeSearchQuery.isEmpty) return overseers;
    return overseers.where((o) {
      if ((o['overseer_name'] ?? '').toLowerCase().contains(
        _attendeeSearchQuery,
      ))
        return true;
      if ((o['region'] ?? '').toLowerCase().contains(_attendeeSearchQuery))
        return true;
      List<dynamic> attendees = o['attendees'] ?? [];
      for (var a in attendees) {
        String fullName = "${a['name'] ?? ''} ${a['surname'] ?? ''}"
            .toLowerCase();
        if (fullName.contains(_attendeeSearchQuery)) return true;
      }
      return false;
    }).toList();
  }

  Widget _buildInsightsPanel(Color neumoBase) {
    return NeumorphicContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      color: neumoBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars, color: Colors.amber[700], size: 20),
              const SizedBox(width: 8),
              Text(
                "Top Attendance Insights",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _insightSubRow(
                  label: "Top Province",
                  value: _topProvince,
                  count: _topProvinceCount,
                  icon: Icons.location_city,
                  iconColor: Colors.blue,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              Expanded(
                child: _insightSubRow(
                  label: "Top Region",
                  value: _topRegion,
                  count: _topRegionCount,
                  icon: Icons.explore,
                  iconColor: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightSubRow({
    required String label,
    required String value,
    required int count,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.1),
            radius: 18,
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  "$count Attendees",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    String title,
    int value,
    Color color,
    Color neumoBase,
    IconData icon,
  ) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 12,
        padding: const EdgeInsets.all(16),
        color: neumoBase,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, color: color.withOpacity(0.6), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizations(Color neumoBase) {
    if (_overallTotal == 0) return const SizedBox.shrink();

    return Column(
      children: [
        _buildPieChart(neumoBase),
        const SizedBox(height: 20),
        if (_provinceTotals.isNotEmpty) ...[
          NeumorphicContainer(
            color: neumoBase,
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Provincial Headcount Scale",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < _provinceTotals.keys.length) {
                                String provName = _provinceTotals.keys
                                    .elementAt(value.toInt());
                                return SideTitleWidget(
                                  meta: TitleMeta(
                                    axisSide: meta.axisSide,
                                    min: meta.min,
                                    max: meta.max,
                                    parentAxisSize: meta.parentAxisSize,
                                    axisPosition: meta.axisPosition,
                                    appliedInterval: meta.appliedInterval,
                                    sideTitles: meta.sideTitles,
                                    formattedValue: meta.formattedValue,
                                    rotationQuarterTurns:
                                        meta.rotationQuarterTurns,
                                  ),
                                  child: Text(
                                    provName.length > 4
                                        ? provName.substring(0, 3)
                                        : provName,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      barGroups: _provinceTotals.entries.map((entry) {
                        int index = _provinceTotals.keys.toList().indexOf(
                          entry.key,
                        );
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              color: _primaryColor,
                              width: 18,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPieChart(Color neumoBase) {
    final sections = <PieChartSectionData>[];
    if (_overallBrothers > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.blue,
          value: _overallBrothers.toDouble(),
          title: 'B',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (_overallSisters > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.pink,
          value: _overallSisters.toDouble(),
          title: 'S',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (_overallParents > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.purple,
          value: _overallParents.toDouble(),
          title: 'P',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (_overallVisitors > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.orange,
          value: _overallVisitors.toDouble(),
          title: 'V',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    return NeumorphicContainer(
      color: neumoBase,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            "Membership Composition Breakdown",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 35,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem("Brothers", Colors.blue),
                    _legendItem("Sisters", Colors.pink),
                    _legendItem("Parents", Colors.purple),
                    _legendItem("Visitors", Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
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
    final filteredOverseers = _filterOverseers(overseers);
    if (filteredOverseers.isEmpty) return const SizedBox.shrink();

    int provTotal = filteredOverseers.fold(
      0,
      (sum, o) => sum + (o['total_present'] as int? ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicContainer(
        borderRadius: 14,
        color: neumoBase,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ExpansionTile(
          iconColor: _primaryColor,
          collapsedIconColor: Colors.grey[600],
          title: Text(
            province,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            "${filteredOverseers.length} Overseers • $provTotal Present",
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          leading: Icon(Icons.location_on, color: _primaryColor, size: 20),
          children: filteredOverseers
              .map((o) => _buildOverseerRow(o, neumoBase))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildOverseerRow(Map<String, dynamic> data, Color neumoBase) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neumoBase.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _primaryColor.withOpacity(0.1),
            radius: 16,
            child: Icon(Icons.person, color: _primaryColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['overseer_name'] ?? 'Unknown Overseer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  "Region: ${data['region'] ?? 'N/A'}",
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Total: ${data['total_present']}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "B:${data['brothers_present']} S:${data['sisters_present']} P:${data['parents_present']} V:${data['visitors_present']}",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportPanel(Color neumoBase) {
    return NeumorphicContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      color: neumoBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red[600], size: 20),
              const SizedBox(width: 8),
              Text(
                "Official Report Export",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Provide the service or event name below to contextualize and stamp the official document.",
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _serviceNameController,
            decoration: InputDecoration(
              labelText: "Service / Event Name",
              hintText: "e.g., Sunday Divine Service",
              prefixIcon: Icon(Icons.edit_note, color: _primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Toggle for including attendees
          Row(
            children: [
              Switch(
                value: _includeAttendees,
                onChanged: (val) => setState(() => _includeAttendees = val),
                activeColor: _primaryColor,
              ),
              const SizedBox(width: 12),
              Text(
                "Include Attendees List",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.cloud_download),
              label: const Text("Generate and Download PDF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
