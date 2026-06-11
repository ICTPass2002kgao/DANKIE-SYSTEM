// ignore_for_file: prefer_const_constructors
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/NeuDesign.dart';

Widget buildSectionHeader(String title, IconData icon, Color primaryColor) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      const SizedBox(width: 12),
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: Colors.blueGrey[900],
        ),
      ),
    ],
  );
}

Widget buildResponsiveLeadershipCards(
  double maxWidth,
  Color neumoColor,
  Color primaryColor,
  String overseerName,
  String regionName,
) {
  bool isWide = maxWidth > 600;
  return Flex(
    direction: isWide ? Axis.horizontal : Axis.vertical,
    children: [
      Expanded(
        flex: isWide ? 1 : 0,
        child: buildLeadershipCard(
          "Lead Overseer",
          overseerName,
          CupertinoIcons.person_crop_circle_fill_badge_checkmark,
          neumoColor,
          primaryColor,
        ),
      ),
      SizedBox(height: isWide ? 0 : 16, width: isWide ? 16 : 0),
      Expanded(
        flex: isWide ? 1 : 0,
        child: buildLeadershipCard(
          "Region",
          regionName,
          CupertinoIcons.building_2_fill,
          neumoColor,
          primaryColor,
        ),
      ),
    ],
  );
}

Widget buildLeadershipCard(
  String title,
  String name,
  IconData icon,
  Color neumoColor,
  Color primaryColor,
) {
  return NeumorphicContainer(
    color: neumoColor,
    borderRadius: 20,
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 10,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Icon(icon, color: primaryColor, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildStatRow(String label, String value, Color color) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Colors.blueGrey[900],
        ),
      ),
    ],
  );
}

Widget buildGenderBar(String label, int present, int total, Color color) {
  double pct = total == 0 ? 0.0 : present / total;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
            ),
          ),
          Text(
            "$present / $total",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.grey.shade200,
          color: color,
          minHeight: 6,
        ),
      ),
    ],
  );
}

Widget buildNeuInput(
  String hint,
  TextEditingController controller,
  Color neumoColor,
  Color primaryColor, [
  IconData? icon,
]) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: NeumorphicContainer(
      color: neumoColor,
      borderRadius: 12,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey[800],
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          icon: icon != null
              ? Icon(icon, color: primaryColor, size: 20)
              : null,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    ),
  );
}