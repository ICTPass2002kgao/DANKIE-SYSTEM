// ignore_for_file: prefer_const_constructors, unused_field, unnecessary_null_comparison

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/API.dart';
// If using Firebase Auth for the token, uncomment the line below:
// import 'package:firebase_auth/firebase_auth.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 800.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 800;
// --------------------------

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<dynamic> upcomingEvents = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // If your API requires the Firebase Token, fetch it here:
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/event_diary/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          upcomingEvents = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load events. Code: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching events: $e");
      setState(() {
        errorMessage = 'Network error occurred while fetching events.';
        isLoading = false;
      });
    }
  }

  DateTime? _parseEventDate(Map<String, dynamic> event) {
    final now = DateTime.now();
    final year = event['year'] ?? now.year;
    String? day = event['day']?.toString();
    String? month = event['month']?.toString();

    if (day == null || day.toLowerCase().contains('confirmed')) return null;

    try {
      if (month != null && month.isNotEmpty) {
        final dayPart = day.split('-').first.trim();
        return DateFormat('dd MMM yyyy').parse('$dayPart $month $year');
      }
      if (day.contains('-') && (month == null || month.isEmpty)) {
        final startMonth = day.split('-').first.trim();
        return DateFormat('MMM yyyy').parse('$startMonth $year');
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);

    // ⭐️ NEUMORPHIC TINT
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    int? firstUpcomingIndex;
    if (!isLoading && upcomingEvents.isNotEmpty) {
      for (int i = 0; i < upcomingEvents.length; i++) {
        final eventDate = _parseEventDate(upcomingEvents[i]);
        if (eventDate != null && eventDate.isAfter(now)) {
          firstUpcomingIndex = i;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: neumoBaseColor, // Set background

      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
                child: _buildBodyContent(
                  theme,
                  neumoBaseColor,
                  now,
                  firstUpcomingIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(
    ThemeData theme,
    Color neumoBaseColor,
    DateTime now,
    int? firstUpcomingIndex,
  ) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            errorMessage,
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (upcomingEvents.isEmpty) {
      return Center(
        child: Text(
          "No events found in the diary.",
          style: TextStyle(color: theme.hintColor, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: upcomingEvents.length,
      itemBuilder: (context, index) {
        final event = upcomingEvents[index];
        final eventDate = _parseEventDate(event);

        bool isPast = eventDate != null && eventDate.isBefore(now);
        bool isNextUpcoming = index == firstUpcomingIndex;
        bool isConfirmed =
            event['day']?.toString().toLowerCase().contains('confirmed') ==
            false;

        // Styles based on state
        Color textColor = theme.primaryColor;
        Color iconColor = theme.hintColor;
        IconData statusIcon = Icons.event_available_rounded;

        if (!isConfirmed) {
          iconColor = Colors.orange;
          statusIcon = Icons.hourglass_empty_rounded;
        } else if (isPast) {
          textColor = theme.hintColor.withOpacity(0.6);
          iconColor = theme.hintColor.withOpacity(0.3);
          statusIcon = Icons.check_circle_outline;
        } else if (isNextUpcoming) {
          iconColor = theme.primaryColor;
          statusIcon = Icons.star_rounded;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: NeumorphicContainer(
            // ⭐️ The Card Container
            color: neumoBaseColor,
            isPressed: false, // Pop out
            borderRadius: 20,
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ⭐️ LEFT: DATE BUBBLE (Sunken/Pressed)
                NeumorphicContainer(
                  color: isNextUpcoming
                      ? theme.primaryColor.withOpacity(0.1)
                      : neumoBaseColor,
                  isPressed: true, // Sunken look for date
                  borderRadius: 15,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event['day']?.toString().split('-')[0].trim() ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: isNextUpcoming
                              ? theme.primaryColor
                              : textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (event['month'] != null &&
                          event['month'].toString().isNotEmpty)
                        Text(
                          event['month'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isNextUpcoming
                                ? theme.primaryColor
                                : theme.hintColor,
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(width: 16),

                // ⭐️ MIDDLE: TITLE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isNextUpcoming
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (event['day'].toString().contains('-'))
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Duration: ${event['day']}",
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(width: 10),

                // ⭐️ RIGHT: STATUS ICON (Small Convex Button)
                NeumorphicContainer(
                  color: neumoBaseColor,
                  isPressed: false,
                  padding: EdgeInsets.all(8),
                  child: Icon(statusIcon, color: iconColor, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
