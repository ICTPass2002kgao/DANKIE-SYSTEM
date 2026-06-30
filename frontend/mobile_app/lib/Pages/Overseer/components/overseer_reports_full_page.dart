// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/Overseer/components/overseer_dialog.dart';
import 'package:ttact/Pages/Overseer/components/overseer_utilities.dart';
import 'package:ttact/Pages/Overseer/components/pdf_generator_register.dart';

class OverseerFullReportsPage extends StatefulWidget {
  final List<dynamic> usersList;
  final Map<String, List<String>> hierarchy;
  final DateTime selectedDate;
  final Color neumoColor;
  final Color primaryColor;

  const OverseerFullReportsPage({
    Key? key,
    required this.usersList,
    required this.hierarchy,
    required this.selectedDate,
    required this.neumoColor,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<OverseerFullReportsPage> createState() =>
      _OverseerFullReportsPageState();
}

class _OverseerFullReportsPageState extends State<OverseerFullReportsPage> {
  String _statusFilter = 'All';
  String _genderFilter = 'All';
  String _districtFilter = 'All';
  String _communityFilter = 'All';

  List<dynamic> get _filteredData {
    return widget.usersList.where((u) {
      // 1. Status Check
      if (_statusFilter == 'Present' && u['isPresent'] != true) return false;
      if (_statusFilter == 'Absent' && u['isPresent'] == true) return false;

      // 2. Gender Check
      if (_genderFilter != 'All') {
        final g = (u['gender'] ?? '').toString().toLowerCase();
        if (_genderFilter == 'Male' && g != 'male') return false;
        if (_genderFilter == 'Female' && g != 'female') return false;
      }

      // 3. District Check
      if (_districtFilter != 'All') {
        final d = u['district_elder_name'] ?? u['districtElderName'] ?? '';
        if (d != _districtFilter) return false;
      }

      // 4. Community Check
      if (_communityFilter != 'All') {
        final c = u['community_name'] ?? u['communityName'] ?? '';
        if (c != _communityFilter) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final neumoBase = Api().neumoBaseColor(context);
    return Scaffold(
      backgroundColor: neumoBase,
      body: Column(
        children: [
          Api().buildAppBar(context, "Full Attendance Reports")!,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateCard(neumoBase),
                  SizedBox(height: 16),
                  _buildFilters(neumoBase),
                  SizedBox(height: 24),
                  _buildMetricCards(neumoBase),
                  SizedBox(height: 24),
                  _buildNativeBarChart(neumoBase),
                  SizedBox(height: 24),
                  _buildCategorizedList(neumoBase),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(Color neumoBase) {
    return NeumorphicContainer(
      borderRadius: 12,
      padding: EdgeInsets.all(16),
      color: neumoBase,
      child: Row(
        children: [
          Icon(CupertinoIcons.calendar, color: widget.primaryColor),
          SizedBox(width: 12),
          Text(
            "Report For: ${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Color neumoBase) {
    List<String> distOptions = ['All', ...widget.hierarchy.keys];
    List<String> commOptions = ['All'];

    if (_districtFilter != 'All' &&
        widget.hierarchy.containsKey(_districtFilter)) {
      commOptions.addAll(widget.hierarchy[_districtFilter]!);
    } else {
      for (var list in widget.hierarchy.values) {
        commOptions.addAll(list);
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildDropdown(
          "Status",
          ['All', 'Present', 'Absent'],
          _statusFilter,
          (v) => setState(() => _statusFilter = v!),
          neumoBase,
        ),
        _buildDropdown(
          "Gender",
          ['All', 'Male', 'Female'],
          _genderFilter,
          (v) => setState(() => _genderFilter = v!),
          neumoBase,
        ),
        _buildDropdown(
          "District",
          distOptions.toSet().toList(),
          _districtFilter,
          (v) {
            setState(() {
              _districtFilter = v!;
              _communityFilter = 'All';
            });
          },
          neumoBase,
        ),
        _buildDropdown(
          "Community",
          commOptions.toSet().toList(),
          _communityFilter,
          (v) => setState(() => _communityFilter = v!),
          neumoBase,
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String currentValue,
    Function(String?) onChanged,
    Color neumoBase,
  ) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width / 2) - 24,
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 12,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: neumoBase,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: currentValue,
                dropdownColor: neumoBase,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                items: items
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(e, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCards(Color neumoBase) {
    final fd = _filteredData;
    int tot = fd.length;
    int pres = fd.where((e) => e['isPresent'] == true).length;
    int abs = tot - pres;
    int bros = fd
        .where((e) => (e['gender'] ?? '').toString().toLowerCase() == 'male')
        .length;
    int sises = fd
        .where((e) => (e['gender'] ?? '').toString().toLowerCase() == 'female')
        .length;
    int visitors = fd.where((e) => e['isVisitor'] == true).length;
    int testifies = fd
        .where(
          (e) =>
              e['isVisitor'] == true &&
              e['visitor_category'] != 'Mother' &&
              e['visitor_category'] != 'Father',
        )
        .length;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _metricTile(
          "Total Queried",
          tot.toString(),
          CupertinoIcons.person_3_fill,
          Colors.blueGrey,
          neumoBase,
        ),
        _metricTile(
          "Present",
          pres.toString(),
          CupertinoIcons.check_mark_circled_solid,
          Colors.green,
          neumoBase,
        ),
        _metricTile(
          "Absent",
          abs.toString(),
          CupertinoIcons.xmark_circle_fill,
          Colors.red,
          neumoBase,
        ),
        _metricTile(
          "Brothers",
          bros.toString(),
          CupertinoIcons.person_solid,
          Colors.blue,
          neumoBase,
        ),
        _metricTile(
          "Sisters",
          sises.toString(),
          CupertinoIcons.person_solid,
          Colors.pink,
          neumoBase,
        ),
        _metricTile(
          "Total Visitors/Guests",
          visitors.toString(),
          CupertinoIcons.person_crop_circle_badge_exclam,
          Colors.orange,
          neumoBase,
        ),
        _metricTile(
          "Total Testifies",
          testifies.toString(),
          CupertinoIcons.book_fill,
          Colors.purple,
          neumoBase,
        ),
      ],
    );
  }

  Widget _metricTile(
    String title,
    String val,
    IconData icon,
    Color color,
    Color neumoBase,
  ) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width / 2) - 24,
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 16,
        padding: EdgeInsets.all(16),
        color: neumoBase,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(
              val,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeBarChart(Color neumoBase) {
    Map<String, int> distTotals = {};
    Map<String, int> distPresent = {};

    for (var u in _filteredData) {
      String d =
          u['district_elder_name'] ?? u['districtElderName'] ?? 'Unassigned';
      distTotals[d] = (distTotals[d] ?? 0) + 1;
      if (u['isPresent'] == true) {
        distPresent[d] = (distPresent[d] ?? 0) + 1;
      }
    }

    if (distTotals.isEmpty) return SizedBox.shrink();

    return NeumorphicContainer(
      borderRadius: 16,
      padding: EdgeInsets.all(20),
      color: neumoBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "District Attendance Progress",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          ...distTotals.entries.map((e) {
            String dist = e.key;
            int tot = e.value;
            int pres = distPresent[dist] ?? 0;
            double pct = tot == 0 ? 0 : pres / tot;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dist,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        "$pres / $tot (${(pct * 100).toStringAsFixed(0)}%)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: widget.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: widget.primaryColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategorizedList(Color neumoBase) {
    Map<String, List<dynamic>> groupedByDist = {};
    for (var u in _filteredData) {
      String d =
          u['district_elder_name'] ?? u['districtElderName'] ?? 'Unassigned';
      if (!groupedByDist.containsKey(d)) groupedByDist[d] = [];
      groupedByDist[d]!.add(u);
    }

    if (groupedByDist.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "No records match filters.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedByDist.entries.map((entry) {
        String dist = entry.key;
        List<dynamic> users = entry.value;
        int pres = users.where((u) => u['isPresent'] == true).length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: NeumorphicContainer(
            borderRadius: 16,
            padding: EdgeInsets.zero,
            color: neumoBase,
            child: ExpansionTile(
              title: Text(
                "Elder: $dist",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
              ),
              subtitle: Text(
                "Total: ${users.length} | Present: $pres | Absent: ${users.length - pres}",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              children: users.map((u) {
                final fullName = "${u['name'] ?? ''} ${u['surname'] ?? ''}"
                    .trim();
                final isPresent = u['isPresent'] ?? false;
                final comm = u['community_name'] ?? 'Unknown Comm';
                final gender = u['gender'] ?? 'Unknown';
                final type = (u['isVisitor'] == true) ? "Visitor" : "Member";

                return ListTile(
                  leading: Icon(
                    isPresent
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.xmark_circle_fill,
                    color: isPresent ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    fullName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    "$comm | $gender | $type",
                    style: TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }
}
