// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http; // Add HTTP package
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:shared_preferences/shared_preferences.dart'; // REQUIRED FOR CACHING
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// YOUR PROJECT IMPORTS
import 'package:ttact/Components/API.dart'; // Ensure this points to your Django URL
import 'package:ttact/Components/BibleVerseRepository.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Components/bottomsheet.dart';

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  // Changed from QuerySnapshot to List of Maps for Django JSON
  Future<List<dynamic>>? _eventsFuture;

  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    "All",
    "Youth",
    "Awards",
    "Academic",
    "Gala",
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // --- NEW: FETCH FROM BOTH DJANGO APIs (EVENTS & DIARY), MERGE AND SORT ---
  void _loadEvents() {
    setState(() {
      _eventsFuture = _fetchEventsFromDjango();
    });
  }

  // Helper function to extract month numbers for chronological sorting
  int _parseMonth(String monthStr) {
    if (monthStr.isEmpty) return 12;
    final cleanStr = monthStr.split('-')[0].trim().toLowerCase();
    if (cleanStr.length < 3) return 12;
    final m = cleanStr.substring(0, 3);
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return months[m] ?? 12;
  }

  // Helper function to convert an event's string dates into a sortable DateTime
  DateTime _parseEventDate(dynamic event) {
    String dayStr = (event['day']?.toString() ?? '').toLowerCase();
    String monthStr = (event['month']?.toString() ?? '').toLowerCase();
    int year = event['year'] != null
        ? int.tryParse(event['year'].toString()) ?? DateTime.now().year
        : DateTime.now().year;

    // Push "To Be Communicated" events to the far future so they appear last
    if (dayStr.contains('communicated') || monthStr.contains('communicated')) {
      return DateTime(year + 1, 12, 31);
    }

    int day = int.tryParse(dayStr.split('-')[0].trim()) ?? 31;
    int month = _parseMonth(monthStr);

    return DateTime(year, month, day);
  }

  Future<List<dynamic>> _fetchEventsFromDjango() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Check for Cached Data FIRST
      String? cachedEvents = prefs.getString('saved_combined_events_data');
      if (cachedEvents != null) {
        print("⚡ Loading events instantly from Local Storage");
      }

      // 2. SECURE FIX: Get the current Firebase user and Token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Blocked: No user is currently logged in.");
        if (cachedEvents != null) {
          return json.decode(cachedEvents).take(3).toList();
        }
        return [];
      }

      String? token = await user.getIdToken();
      if (token == null) {
        print("❌ Blocked: Could not retrieve Firebase token.");
        if (cachedEvents != null) {
          return json.decode(cachedEvents).take(3).toList();
        }
        return [];
      }

      // 3. Build the URLs for BOTH tables
      final eventsUrl = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/events/');
      final diaryUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/event_diary/',
      );

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // 4. Fetch from both endpoints concurrently
      final responses = await Future.wait([
        http
            .get(eventsUrl, headers: headers)
            .timeout(const Duration(seconds: 10)),
        http
            .get(diaryUrl, headers: headers)
            .timeout(const Duration(seconds: 10)),
      ]);

      List<dynamic> combinedEvents = [];

      // Helper to extract JSON safely from DRF responses
      List<dynamic> extractData(http.Response res) {
        if (res.statusCode == 200) {
          final decoded = json.decode(res.body);
          if (decoded is Map<String, dynamic> &&
              decoded.containsKey('results')) {
            return decoded['results'];
          }
          if (decoded is List) return decoded;
        }
        return [];
      }

      // Merge data
      combinedEvents.addAll(extractData(responses[0])); // Data from /events/
      combinedEvents.addAll(
        extractData(responses[1]),
      ); // Data from /event_diary/

      // 5. Filter out past events and sort by nearest upcoming date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Keep only events occurring today or in the future
      combinedEvents = combinedEvents.where((event) {
        DateTime eventDate = _parseEventDate(event);
        return eventDate.isAfter(today.subtract(const Duration(days: 1)));
      }).toList();

      // Sort chronologically ascending (nearest first)
      combinedEvents.sort((a, b) {
        DateTime dateA = _parseEventDate(a);
        DateTime dateB = _parseEventDate(b);
        return dateA.compareTo(dateB);
      });

      // 6. SAVE THE FRESH SORTED DATA TO LOCAL STORAGE
      if (combinedEvents.isNotEmpty) {
        await prefs.setString(
          'saved_combined_events_data',
          json.encode(combinedEvents),
        );
        print("💾 Fresh merged events saved to Local Storage");
      }

      // 7. Return the top 3 nearest events
      return combinedEvents.take(3).toList();
    } catch (e) {
      print("Network Error: $e");
      // If the user has no internet, show them the saved data
      String? cachedEvents = prefs.getString('saved_combined_events_data');
      if (cachedEvents != null) {
        print("📴 No internet! Showing offline cached events.");
        return json.decode(cachedEvents).take(3).toList();
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dailyVerse = GreetingsQuoteRepository.getDailyQuote();

    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.05),
      theme.scaffoldBackgroundColor,
    );

    return Container(
      color: neumoBaseColor,
      child: RefreshIndicator(
        onRefresh: () async => _loadEvents(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          physics: const BouncingScrollPhysics(),
          children: [
            // DAILY VERSE
            _buildNeumorphicDailyVerse(theme, neumoBaseColor, dailyVerse),

            const SizedBox(height: 20),

            // OPPORTUNITY BANNER
            NeumorphicContainer(
              color: neumoBaseColor,
              isPressed: false,
              borderRadius: 25,
              padding: EdgeInsets.all(5),
              child: _buildOpportunityBanner(context),
            ),

            const SizedBox(height: 10),

            // CATEGORY FILTERS
            _buildNeumorphicFilters(theme, neumoBaseColor),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text(
                'Upcoming Events',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 5. EVENTS LIST (MERGED AND SORTED API DATA)
            FutureBuilder<List<dynamic>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: isIOSPlatform
                          ? CupertinoActivityIndicator()
                          : CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildNeumorphicEmptyState(theme, neumoBaseColor);
                }

                return _buildEventsList(theme, neumoBaseColor, snapshot.data!);
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // --- UPDATED LIST BUILDER ---
  Widget _buildEventsList(
    ThemeData theme,
    Color neumoBaseColor,
    List<dynamic> events,
  ) {
    return Column(
      children: events.asMap().entries.map((entry) {
        int index = entry.key;
        var event = entry.value;

        // Highlight the first event
        bool isNextUpcoming = index == 0;

        Color textColor = isNextUpcoming
            ? theme.primaryColor
            : theme.textTheme.bodyMedium!.color!;

        IconData statusIcon = isNextUpcoming
            ? Icons.play_arrow_rounded
            : Icons.calendar_today_rounded;

        Color iconColor = isNextUpcoming ? theme.primaryColor : theme.hintColor;

        String day = event['day']?.toString() ?? '';
        String month = event['month']?.toString() ?? '';
        String title = event['title'] ?? 'No Title';
        String description =
            event['description'] ?? 'Event details to be communicated.';
        // Check for 'poster_url' (Django default) OR 'posterUrl' (if camelCase configured)
        String posterUrl = event['poster_url'] ?? event['posterUrl'] ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 25.0),
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: neumoBaseColor,
                builder: (context) => EventDetailBottomSheet(
                  date: day,
                  eventMonth: month,
                  title: title,
                  description: description,
                  posterUrl: posterUrl,
                ),
              );
            },
            child: NeumorphicContainer(
              color: neumoBaseColor,
              isPressed: false,
              borderRadius: 20,
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT: DATE BUBBLE
                  NeumorphicContainer(
                    color: isNextUpcoming
                        ? theme.primaryColor.withOpacity(0.1)
                        : neumoBaseColor,
                    isPressed: true,
                    borderRadius: 15,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        day.toLowerCase().contains("communicated")
                            ? Icon(
                                Icons.pending_actions,
                                color: isNextUpcoming
                                    ? theme.primaryColor
                                    : textColor,
                              )
                            : Text(
                                day.split('-')[0].trim(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: isNextUpcoming
                                      ? theme.primaryColor
                                      : textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                        if (month.isNotEmpty &&
                            !month.toLowerCase().contains("communicated"))
                          Text(
                            month.split(' ')[0].toUpperCase(),
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

                  // MIDDLE: TITLE
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isNextUpcoming
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (day.contains('-') &&
                            !day.toLowerCase().contains("communicated"))
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Duration: $day",
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

                  // RIGHT: STATUS ICON
                  NeumorphicContainer(
                    color: neumoBaseColor,
                    isPressed: false,
                    padding: EdgeInsets.all(8),
                    child: Icon(statusIcon, color: iconColor, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- UI HELPERS ---

  Widget _buildNeumorphicEmptyState(ThemeData theme, Color baseColor) {
    return NeumorphicContainer(
      color: baseColor,
      isPressed: true,
      borderRadius: 25,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 60,
            color: theme.primaryColor.withOpacity(0.4),
          ),
          const SizedBox(height: 20),
          Text(
            "All Caught Up!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "No upcoming events right now.",
            style: TextStyle(color: theme.hintColor),
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: _loadEvents,
            child: NeumorphicContainer(
              color: baseColor,
              isPressed: false,
              borderRadius: 20,
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              child: Text(
                "Refresh",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicDailyVerse(
    ThemeData theme,
    Color baseColor,
    Map<String, String> verseData,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      isPressed: false,
      borderRadius: 25,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
              SizedBox(width: 12),
              Text(
                'Daily Verse',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor.withOpacity(0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '"${verseData['text']}"',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              height: 1.6,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: theme.primaryColor,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: NeumorphicContainer(
              color: theme.primaryColor,
              borderRadius: 12,
              isPressed: false,
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: Text(
                verseData['ref']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityBanner(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            "NEW OPPORTUNITIES",
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Bursaries & Internships",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Boost your career today!",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            "Check Now",
                            style: TextStyle(
                              color: Color(0xFF0D47A1),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicFilters(ThemeData theme, Color baseColor) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                  _loadEvents();
                });
              },
              child: NeumorphicContainer(
                color: isSelected ? theme.primaryColor : baseColor,
                isPressed: false,
                borderRadius: 30,
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Center(
                  child: Text(
                    _categories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.hintColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
