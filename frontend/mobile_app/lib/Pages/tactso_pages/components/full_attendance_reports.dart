import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class FullAttendanceReports extends StatefulWidget {
  final List<dynamic> usersList;
  final String universityName;
  final Color neumoColor;
  final Color primaryColor;
  final DateTime selectedDate;

  const FullAttendanceReports({
    Key? key,
    required this.usersList,
    required this.universityName,
    required this.neumoColor,
    required this.primaryColor,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<FullAttendanceReports> createState() => FullAttendanceReportsState();
}

class FullAttendanceReportsState extends State<FullAttendanceReports> {
  String _statusFilter = 'All';
  String _genderFilter = 'All';

  List<dynamic> get _filteredData {
    return widget.usersList.where((u) {
      if (_statusFilter == 'Present' && u['isPresent'] != true) return false;
      if (_statusFilter == 'Absent' && u['isPresent'] == true) return false;
      if (_genderFilter != 'All') {
        final g = (u['gender'] ?? '').toString().toLowerCase();
        if (_genderFilter == 'Male' && g != 'male') return false;
        if (_genderFilter == 'Female' && g != 'female') return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: widget.neumoColor,
      body: Column(
        children: [
          Api().buildAppBar(context, "Full Report - ${widget.universityName}")!,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeumorphicContainer(
                    borderRadius: 12,
                    padding: EdgeInsets.all(16),
                    color: widget.neumoColor,
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          color: widget.primaryColor,
                        ),
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
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildDropdown(
                        "Status",
                        ['All', 'Present', 'Absent'],
                        _statusFilter,
                        (v) => setState(() => _statusFilter = v!),
                      ),
                      _buildDropdown(
                        "Gender",
                        ['All', 'Male', 'Female'],
                        _genderFilter,
                        (v) => setState(() => _genderFilter = v!),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _metricTile(
                        "Total Queried",
                        tot.toString(),
                        CupertinoIcons.person_3_fill,
                        Colors.blueGrey,
                      ),
                      _metricTile(
                        "Present",
                        pres.toString(),
                        CupertinoIcons.check_mark_circled_solid,
                        Colors.green,
                      ),
                      _metricTile(
                        "Absent",
                        abs.toString(),
                        CupertinoIcons.xmark_circle_fill,
                        Colors.red,
                      ),
                      _metricTile(
                        "Brothers",
                        bros.toString(),
                        CupertinoIcons.person_solid,
                        Colors.blue,
                      ),
                      _metricTile(
                        "Sisters",
                        sises.toString(),
                        CupertinoIcons.person_solid,
                        Colors.pink,
                      ),
                      _metricTile(
                        "Total Visitors/Guests",
                        visitors.toString(),
                        CupertinoIcons.person_crop_circle_badge_exclam,
                        Colors.orange,
                      ),
                      _metricTile(
                        "Total Testifies",
                        testifies.toString(),
                        CupertinoIcons.book_fill,
                        Colors.purple,
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  ..._filteredData.map((u) {
                    final fullName = "${u['name'] ?? ''} ${u['surname'] ?? ''}"
                        .trim();
                    final isPresent = u['isPresent'] == true;
                    final type = u['isVisitor'] == true ? "Visitor" : "Member";
                    final comm = u['community_name'] ?? widget.universityName;
                    final gender = u['gender'] ?? 'Unknown';
                    return ListTile(
                      leading: Icon(
                        isPresent
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.xmark_circle_fill,
                        color: isPresent ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        fullName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("$comm | $gender | $type"),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String currentValue,
    Function(String?) onChanged,
  ) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width / 2) - 24,
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 12,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: widget.neumoColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: currentValue,
                dropdownColor: widget.neumoColor,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String title, String val, IconData icon, Color color) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width / 2) - 24,
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 16,
        padding: EdgeInsets.all(16),
        color: widget.neumoColor,
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
}
