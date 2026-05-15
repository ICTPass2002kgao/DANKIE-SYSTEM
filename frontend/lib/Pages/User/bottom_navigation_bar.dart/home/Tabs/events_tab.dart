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

  // --- NEW: FETCH FROM DJANGO API (SECURED & CACHED) ---
  void _loadEvents() {
    setState(() {
      _eventsFuture = _fetchEventsFromDjango();
    });
  }

  Future<List<dynamic>> _fetchEventsFromDjango() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Check for Cached Data FIRST
      String? cachedEvents = prefs.getString('saved_events_data');
      if (cachedEvents != null) {
        print("⚡ Loading events instantly from Local Storage");
        // We don't return here! We just show it fast, but keep going
        // to fetch fresh data from Django in the background.
      }

      // 2. SECURE FIX: Get the current Firebase user and Token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Blocked: No user is currently logged in.");
        // Fallback to offline data if not logged in
        if (cachedEvents != null)
          return json.decode(cachedEvents).take(3).toList();
        return [];
      }

      String? token = await user.getIdToken();
      if (token == null) {
        print("❌ Blocked: Could not retrieve Firebase token.");
        if (cachedEvents != null)
          return json.decode(cachedEvents).take(3).toList();
        return [];
      }

      // 3. Build the URL
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/events/');

      print("Fetching events from: $url");

      // 4. Make the GET Request WITH the Authorization Header
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token', // Injecting the key
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10)); // Added timeout

      if (response.statusCode == 200) {
        // 5. SAVE THE FRESH DATA TO LOCAL STORAGE
        await prefs.setString('saved_events_data', response.body);
        print("💾 Fresh events saved to Local Storage");

        List<dynamic> data = json.decode(response.body);

        // 6. Return data
        return data.take(3).toList(); // Limit to 3 as requested
      } else {
        print("Server Error: ${response.statusCode} - ${response.body}");
        // If Django fails (e.g., 500 error), try to show cached data
        if (cachedEvents != null) {
          return json.decode(cachedEvents).take(3).toList();
        }
        return [];
      }
    } catch (e) {
      print("Network Error: $e");
      // If the user has no internet, show them the saved data!
      String? cachedEvents = prefs.getString('saved_events_data');
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
    final dailyVerse = BibleVerseRepository.getDailyVerse();

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

            // 5. EVENTS LIST (UPDATED FOR API)
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

        // NOTE: Django Serializers typically return snake_case (e.g., poster_url)
        // Adjust these keys based on your actual Django API response
        String day = event['day']?.toString() ?? '';
        String month = event['month']?.toString() ?? '';
        String title = event['title'] ?? 'No Title';
        String description = event['description'] ?? 'No Description';
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
                        Text(
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
                        if (month.isNotEmpty)
                          Text(
                            month.toUpperCase(),
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
                        if (day.contains('-'))
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

  // --- UI HELPERS (Unchanged logic, just keeping structure) ---

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
