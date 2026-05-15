// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // ADDED
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class ProfessionalDashboard extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const ProfessionalDashboard({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<ProfessionalDashboard> createState() => _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  final Color _baseColor = const Color(0xFFEFF4F9);
  bool _isLoading = true;

  List<dynamic> _allOverseers = [];
  List<dynamic> _filteredOverseers = [];
  List<dynamic> _allUsers = [];
  List<dynamic> _allBranches = [];
  List<dynamic> _allProducts = [];
  List<dynamic> _allMusic = [];
  List<dynamic> _auditLogs = [];

  Map<String, int> _overseerMemberCounts = {};
  Map<String, int> _provinceCounts = {
    'Eastern Cape': 0,
    'Free State': 0,
    'Gauteng': 0,
    'KwaZulu-Natal': 0,
    'Limpopo': 0,
    'Mpumalanga': 0,
    'Northern Cape': 0,
    'North West': 0,
    'Western Cape': 0,
    'Unknown': 0,
  };

  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = ['All Regions'];
  String _selectedFilter = 'All Regions';
  final List<String> _provinceFilterOptions = ['All Provinces'];
  String _selectedProvinceFilter = 'All Provinces';

  int _pageSize = 20;
  int _currentPage = 0;
  int _userPageSize = 10;
  int _usersCurrentPage = 0;

  final Map<String, Color> _provinceColors = {
    'Eastern Cape': Colors.blue,
    'Free State': Colors.orange,
    'Gauteng': Colors.purple,
    'KwaZulu-Natal': Colors.green,
    'Limpopo': Colors.red,
    'Mpumalanga': Colors.yellow.shade700,
    'Northern Cape': Colors.teal,
    'North West': Colors.pink,
    'Western Cape': Colors.indigo,
    'Unknown': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _fetchAllData();
    _searchController.addListener(_runFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_runFilters);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final baseUrl = Api().BACKEND_BASE_URL_DEBUG;
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String token = await user.getIdToken() ?? '';
      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/overseers/'), headers: headers),
        http.get(Uri.parse('$baseUrl/users/'), headers: headers),
        http.get(Uri.parse('$baseUrl/tactso_branches/'), headers: headers),
        http.get(Uri.parse('$baseUrl/products/'), headers: headers),
        http.get(Uri.parse('$baseUrl/songs/'), headers: headers),
        http.get(Uri.parse('$baseUrl/audit_logs/'), headers: headers),
      ]);

      setState(() {
        _allOverseers = _parseJson(responses[0]);
        _allUsers = _parseJson(responses[1]);
        _allBranches = _parseJson(responses[2]);
        _allProducts = _parseJson(responses[3]);
        _allMusic = _parseJson(responses[4]);
        _auditLogs = _parseJson(responses[5]);

        _processUserStats();
        _processOverseerStats();
        _isLoading = false;
        _filteredOverseers = List.from(_allOverseers);
        _initFilterOptions();
      });
    } catch (e) {
      print("Network Error: $e");
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _parseJson(http.Response response) {
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded.containsKey('results'))
        return decoded['results'] as List;
      if (decoded is List) return decoded;
    }
    return [];
  }

  void _processUserStats() {
    _provinceCounts = _provinceCounts.map((key, value) => MapEntry(key, 0));
    _overseerMemberCounts.clear();
    for (var user in _allUsers) {
      final address = (user['address'] ?? '').toString().toLowerCase();
      final province = (user['province'] ?? '').toString();
      bool found = false;
      if (_provinceCounts.containsKey(province)) {
        _provinceCounts[province] = (_provinceCounts[province] ?? 0) + 1;
        found = true;
      } else {
        for (String pKey in _provinceCounts.keys) {
          if (pKey == 'Unknown') continue;
          if (address.contains(pKey.toLowerCase())) {
            _provinceCounts[pKey] = (_provinceCounts[pKey] ?? 0) + 1;
            found = true;
            break;
          }
        }
      }
      if (!found)
        _provinceCounts['Unknown'] = (_provinceCounts['Unknown'] ?? 0) + 1;
      final overseerUid = user['overseer_uid'];
      if (overseerUid != null)
        _overseerMemberCounts[overseerUid] =
            (_overseerMemberCounts[overseerUid] ?? 0) + 1;
    }
  }

  void _processOverseerStats() {
    _allOverseers.sort((a, b) {
      final aLen = (a['districts'] as List? ?? []).length;
      final bLen = (b['districts'] as List? ?? []).length;
      return bLen.compareTo(aLen);
    });
  }

  void _initFilterOptions() {
    final Set<String> regions = {'All Regions'};
    final Set<String> provinces = {'All Provinces'};
    for (var overseer in _allOverseers) {
      if (overseer['region'] != null) regions.add(overseer['region']);
      if (overseer['province'] != null) provinces.add(overseer['province']);
    }
    _filterOptions.clear();
    _filterOptions.addAll(regions.toList()..sort());
    _provinceFilterOptions.clear();
    _provinceFilterOptions.addAll(provinces.toList()..sort());
  }

  void _runFilters() {
    List<dynamic> temp = _allOverseers;
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      temp = temp.where((doc) {
        final name = (doc['overseer_initials_surname'] ?? doc['name'] ?? '')
            .toLowerCase();
        final region = (doc['region'] ?? '').toLowerCase();
        final code = (doc['code'] ?? '').toLowerCase();
        return name.contains(query) ||
            region.contains(query) ||
            code.contains(query);
      }).toList();
    }
    if (_selectedFilter != 'All Regions')
      temp = temp.where((doc) => doc['region'] == _selectedFilter).toList();
    if (_selectedProvinceFilter != 'All Provinces')
      temp = temp
          .where((doc) => doc['province'] == _selectedProvinceFilter)
          .toList();
    setState(() {
      _filteredOverseers = temp;
      _currentPage = 0;
    });
  }

  List<PieChartSectionData> _generateUserRoleSections() {
    int members = 0, sellers = 0, admins = 0;
    for (var user in _allUsers) {
      final role = (user['role'] ?? 'Member').toString();
      if (role == 'Seller')
        sellers++;
      else if (role == 'Admin')
        admins++;
      else
        members++;
    }
    int overseers = _allOverseers.length;
    int total = members + sellers + admins + overseers;
    if (total == 0) return [];
    double percent(int val) => (val / total) * 100;
    return [
      _pieSection(
        Colors.blue,
        members,
        '${percent(members).toStringAsFixed(0)}%',
      ),
      _pieSection(
        Colors.orange,
        sellers,
        '${percent(sellers).toStringAsFixed(0)}%',
      ),
      _pieSection(
        Colors.purple,
        overseers,
        '${percent(overseers).toStringAsFixed(0)}%',
      ),
      _pieSection(
        Colors.green,
        admins,
        '${percent(admins).toStringAsFixed(0)}%',
      ),
    ];
  }

  PieChartSectionData _pieSection(Color color, int value, String title) {
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: title,
      radius: 45,
      titleStyle: TextStyle(
        fontSize: 10,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  List<FlSpot> _generateActivityLineData() {
    if (_auditLogs.isEmpty)
      return List.generate(7, (i) => FlSpot(i.toDouble(), 0));
    Map<int, int> dailyCounts = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    DateTime now = DateTime.now();
    DateTime sevenDaysAgo = now.subtract(Duration(days: 7));
    for (var log in _auditLogs) {
      if (log['timestamp'] != null) {
        DateTime date = DateTime.tryParse(log['timestamp']) ?? DateTime.now();
        if (date.isAfter(sevenDaysAgo)) {
          int dayIndex = date.weekday - 1;
          dailyCounts[dayIndex] = (dailyCounts[dayIndex] ?? 0) + 1;
        }
      }
    }
    List<FlSpot> spots = [];
    dailyCounts.forEach(
      (key, value) => spots.add(FlSpot(key.toDouble(), value.toDouble())),
    );
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  Widget _buildPremiumCard({
    required Widget child,
    Color? accentColor,
    double padding = 20.0,
  }) {
    return NeumorphicContainer(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      color: _baseColor,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor ?? Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(padding: EdgeInsets.all(padding), child: child),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalItems = _filteredOverseers.length;
    final int totalPages = (totalItems / _pageSize).ceil();
    final int startIndex = _currentPage * _pageSize;
    final int endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : startIndex + _pageSize;
    final List<dynamic> pagedOverseers = (totalItems > 0)
        ? _filteredOverseers.sublist(startIndex, endIndex)
        : [];

    return Scaffold(
      backgroundColor: _baseColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dashboard Overview",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                  SizedBox(height: 25),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 1300
                          ? 5
                          : constraints.maxWidth > 800
                          ? 3
                          : 1;
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        childAspectRatio: constraints.maxWidth > 800
                            ? 2.9
                            : 3.9,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 16,
                        children: [
                          _buildStaticSummaryCard(
                            "Total Users",
                            _allUsers.length.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                          _buildStaticSummaryCard(
                            "Branches",
                            _allBranches.length.toString(),
                            Icons.business,
                            Colors.orange,
                          ),
                          _buildStaticSummaryCard(
                            "Overseers",
                            _allOverseers.length.toString(),
                            Icons.people_alt,
                            Colors.purple,
                          ),
                          _buildStaticSummaryCard(
                            "Products",
                            _allProducts.length.toString(),
                            Icons.shopping_cart,
                            Colors.green,
                          ),
                          _buildStaticSummaryCard(
                            "Music",
                            _allMusic.length.toString(),
                            Icons.music_note,
                            Colors.indigo,
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 30),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 1000)
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildLineChartSection()),
                            SizedBox(width: 20),
                            Expanded(flex: 1, child: _buildPieChartSection()),
                          ],
                        );
                      return Column(
                        children: [
                          _buildLineChartSection(),
                          SizedBox(height: 20),
                          _buildPieChartSection(),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 30),
                  _buildProvinceChartSection(),
                  SizedBox(height: 40),
                  _buildOverseerHeader(),
                  SizedBox(height: 20),
                  NeumorphicContainer(
                    isPressed: true,
                    borderRadius: 12,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: _baseColor,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        icon: Icon(Icons.search, color: Colors.grey),
                        hintText: "Search Overseer, Region or Code...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildPremiumCard(
                    accentColor: Theme.of(context).primaryColor,
                    padding: 10,
                    child: Column(
                      children: [
                        Table(
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            5: FixedColumnWidth(50),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                _buildHeaderCell('Name'),
                                _buildHeaderCell('Region'),
                                _buildHeaderCell('Code'),
                                _buildHeaderCell('Districts'),
                                _buildHeaderCell('Members'),
                                _buildHeaderCell(''),
                              ],
                            ),
                            ...pagedOverseers.map((data) {
                              final uid = data['uid'] ?? data['id'].toString();
                              return TableRow(
                                children: [
                                  _buildTableCell(
                                    data['overseer_initials_surname'] ??
                                        data['name'] ??
                                        'N/A',
                                    isBold: true,
                                  ),
                                  _buildTableCell(data['region'] ?? '-'),
                                  _buildTableCell(data['code'] ?? '-'),
                                  Center(
                                    child: Text(
                                      (data['districts'] as List?)?.length
                                              .toString() ??
                                          '0',
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      (_overseerMemberCounts[uid] ?? 0)
                                          .toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.grey),
                                    onPressed: () {},
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left),
                              onPressed: _currentPage == 0
                                  ? null
                                  : () => setState(() => _currentPage--),
                            ),
                            Text(
                              "Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}",
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right),
                              onPressed: _currentPage >= totalPages - 1
                                  ? null
                                  : () => setState(() => _currentPage++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  _buildUsersTableSection(),
                  SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildStaticSummaryCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return _buildPremiumCard(
      accentColor: color,
      padding: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 5),
              Text(
                count,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          NeumorphicContainer(
            isPressed: true,
            borderRadius: 12,
            padding: EdgeInsets.all(10),
            color: _baseColor,
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTableSection() {
    final int totalUserItems = _allUsers.length;
    final int totalUserPages = (totalUserItems / _userPageSize).ceil();
    final int startUserIndex = _usersCurrentPage * _userPageSize;
    final int endUserIndex = (startUserIndex + _userPageSize > totalUserItems)
        ? totalUserItems
        : startUserIndex + _userPageSize;
    final List<dynamic> actualPagedUsers = (totalUserItems > 0)
        ? _allUsers.sublist(startUserIndex, endUserIndex)
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Users',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            NeumorphicContainer(
              borderRadius: 50,
              padding: EdgeInsets.all(8),
              color: _baseColor,
              child: Icon(Icons.group, color: Theme.of(context).primaryColor),
            ),
          ],
        ),
        SizedBox(height: 15),
        _buildPremiumCard(
          accentColor: Colors.teal,
          padding: 16,
          child: Column(
            children: [
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2.5),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      _buildHeaderCell('Name & Surname'),
                      _buildHeaderCell('Address'),
                      _buildHeaderCell('Email'),
                      _buildHeaderCell('Role'),
                    ],
                  ),
                  ...actualPagedUsers
                      .map(
                        (data) => TableRow(
                          children: [
                            _buildTableCell(
                              '${data['name']} ${data['surname']}',
                              isBold: true,
                            ),
                            _buildTableCell(data['address'] ?? 'N/A'),
                            _buildTableCell(data['email'] ?? 'N/A'),
                            _buildTableCell(data['role'] ?? 'User'),
                          ],
                        ),
                      )
                      .toList(),
                ],
              ),
              if (totalUserPages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left),
                      onPressed: _usersCurrentPage == 0
                          ? null
                          : () => setState(() => _usersCurrentPage--),
                    ),
                    Text("Page ${_usersCurrentPage + 1} of $totalUserPages"),
                    IconButton(
                      icon: Icon(Icons.chevron_right),
                      onPressed: _usersCurrentPage >= totalUserPages - 1
                          ? null
                          : () => setState(() => _usersCurrentPage++),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineChartSection() {
    return SizedBox(
      height: 350,
      child: _buildPremiumCard(
        accentColor: Theme.of(context).primaryColor,
        padding: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Activity Analytics (Last 7 Days)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: _bottomTitleWidgets,
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateActivityLineData(),
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection() {
    final sections = _generateUserRoleSections();
    return SizedBox(
      height: 350,
      child: _buildPremiumCard(
        accentColor: Colors.purpleAccent,
        padding: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "User Roles",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: sections.isEmpty
                  ? Center(child: Text("No Data"))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: sections,
                      ),
                    ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _indicator(Colors.blue, "Members"),
                _indicator(Colors.orange, "Sellers"),
                _indicator(Colors.purple, "Overseers"),
                _indicator(Colors.green, "Admins"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvinceChartSection() {
    return _buildPremiumCard(
      accentColor: Colors.orangeAccent,
      padding: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "User Distribution",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 300,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _generateProvincePieSections(),
                    ),
                  ),
                ),
              ),
              Expanded(flex: 1, child: _buildProvinceLegend()),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateProvincePieSections() {
    final activeProvinces = _provinceCounts.entries
        .where((e) => e.value > 0)
        .toList();
    int total = activeProvinces.fold(0, (sum, item) => sum + item.value);
    return activeProvinces.map((entry) {
      final percentage = total == 0 ? 0.0 : (entry.value / total * 100);
      return PieChartSectionData(
        color: _provinceColors[entry.key] ?? Colors.grey,
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildProvinceLegend() {
    final activeProvinces = _provinceCounts.entries
        .where((e) => e.value > 0)
        .toList();
    activeProvinces.sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: activeProvinces
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _provinceColors[entry.key] ?? Colors.grey,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[800],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildOverseerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Overseer Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[800],
          ),
        ),
        if (MediaQuery.of(context).size.width > 700)
          Row(
            children: [
              _buildNeumorphicDropdown(
                _filterOptions,
                _selectedFilter,
                (v) => setState(() {
                  _selectedFilter = v!;
                  _runFilters();
                }),
              ),
              SizedBox(width: 15),
              _buildNeumorphicDropdown(
                _provinceFilterOptions,
                _selectedProvinceFilter,
                (v) => setState(() {
                  _selectedProvinceFilter = v!;
                  _runFilters();
                }),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildNeumorphicDropdown(
    List<String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return NeumorphicContainer(
      borderRadius: 12,
      color: _baseColor,
      isPressed: true,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) => Padding(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
      ),
    ),
  );
  Widget _buildTableCell(String text, {bool isBold = false}) => Padding(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
  );
  Widget _indicator(Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
    ],
  );

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (value.toInt() >= 0 && value.toInt() < 7)
      return SideTitleWidget(
        meta: meta,
        child: Text(days[value.toInt()], style: style),
      );
    return SideTitleWidget(
      meta: meta,
      child: Text('', style: style),
    );
  }
}
