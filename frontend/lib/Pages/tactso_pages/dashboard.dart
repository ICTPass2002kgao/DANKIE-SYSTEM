// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class DashboardTab extends StatefulWidget {
  final String branchId;
  final Color neumoColor;
  final String? universityName;
  final String? loggedMemberName;

  const DashboardTab({
    Key? key,
    required this.branchId,
    required this.neumoColor,
    this.universityName,
    this.loggedMemberName,
  }) : super(key: key);

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Future<List<dynamic>>? _applicationsFuture;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  void _fetchApplications() {
    _applicationsFuture = _getApplicationsData();
  }

  // ⭐️ FIX: Cleaned up Auth Token syntax for consistency and safe JSON parsing
  Future<List<dynamic>> _getApplicationsData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      // FIXED: Using clean String? syntax
      final String? token = await user?.getIdToken();

      final response = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/applications/?branch=${widget.branchId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        var decoded = json.decode(response.body);
        if (decoded is Map && decoded.containsKey('results')) {
          return decoded['results'];
        } else if (decoded is List) {
          return decoded;
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching applications: $e");
      return [];
    }
  }

  Color get _primaryColor => Theme.of(context).primaryColor;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _applicationsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CupertinoActivityIndicator());

        final docs = snapshot.data!;
        final total = docs.length;
        final newApps = docs.where((d) => d['status'] == 'New').length;
        final submitted = docs
            .where((d) => d['status'] == 'Application Submitted')
            .length;
        final rejected = docs.where((d) => d['status'] == 'Rejected').length;
        final reviewed = docs.where((d) => d['status'] == 'Reviewed').length;

        bool isSmallScreen = MediaQuery.of(context).size.width < 600;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeumorphicContainer(
                color: widget.neumoColor,
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                borderRadius: 16,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isSmallScreen ? 25 : 30,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      child: Icon(Icons.person, color: _primaryColor),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome Back,",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            widget.loggedMemberName ??
                                widget.universityName ??
                                "Administrator",
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: isSmallScreen ? 16 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              isSmallScreen
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildStatCard(
                            "Total Apps",
                            "$total",
                            Icons.folder_shared,
                            Colors.blueAccent,
                            double.infinity,
                          ),
                          SizedBox(height: 12),
                          _buildStatCard(
                            "Pending",
                            "$newApps",
                            Icons.fiber_new,
                            Colors.orange,
                            double.infinity,
                          ),
                          SizedBox(height: 12),
                          _buildStatCard(
                            "Completed",
                            "$submitted",
                            Icons.check_circle,
                            Colors.green,
                            double.infinity,
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        double cardWidth = (constraints.maxWidth - 20) / 4;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildStatCard(
                              "Total Apps",
                              "$total",
                              Icons.folder_shared,
                              Colors.blueAccent,
                              cardWidth,
                            ),
                            _buildStatCard(
                              "New / Pending",
                              "$newApps",
                              Icons.fiber_new,
                              Colors.orange,
                              cardWidth,
                            ),
                            _buildStatCard(
                              "Completed",
                              "$submitted",
                              Icons.check_circle,
                              Colors.green,
                              cardWidth,
                            ),
                          ],
                        );
                      },
                    ),

              SizedBox(height: 30),

              if (total > 0)
                NeumorphicContainer(
                  color: widget.neumoColor,
                  padding: EdgeInsets.all(20),
                  borderRadius: 16,
                  child: isSmallScreen
                      ? Column(
                          children: [
                            SizedBox(
                              height: 200,
                              child: _buildChart(
                                newApps,
                                reviewed,
                                submitted,
                                rejected,
                              ),
                            ),
                            SizedBox(height: 20),
                            _buildChartLegend(
                              newApps,
                              reviewed,
                              submitted,
                              rejected,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 300,
                                child: _buildChart(
                                  newApps,
                                  reviewed,
                                  submitted,
                                  rejected,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildChartLegend(
                                newApps,
                                reviewed,
                                submitted,
                                rejected,
                              ),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return NeumorphicContainer(
      color: widget.neumoColor,
      borderRadius: 16,
      padding: EdgeInsets.all(16),
      child: SizedBox(
        width: width - 32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: Colors.grey, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: TextStyle(
                color: _primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(int newApps, int reviewed, int submitted, int rejected) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: [
          _buildPieSection(newApps, Colors.orange),
          _buildPieSection(reviewed, Colors.blue),
          _buildPieSection(submitted, Colors.green),
          _buildPieSection(rejected, Colors.red),
        ],
      ),
    );
  }

  Widget _buildChartLegend(
    int newApps,
    int reviewed,
    int submitted,
    int rejected,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem("New", Colors.orange, newApps),
        _buildLegendItem("Reviewed", Colors.blue, reviewed),
        _buildLegendItem("Submitted", Colors.green, submitted),
        _buildLegendItem("Rejected", Colors.red, rejected),
      ],
    );
  }

  PieChartSectionData _buildPieSection(int count, Color color) {
    final double value = count.toDouble();
    return PieChartSectionData(
      color: color,
      value: value,
      title: value > 0 ? '${value.toInt()}' : '',
      radius: 40,
      titleStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: color),
          SizedBox(width: 8),
          Text(
            "$title ($count)",
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
