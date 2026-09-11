// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/BibleVerseRepository.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Components/bottomsheet.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/main_menu.dart'
    hide isLargeScreen;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<List<dynamic>>? _eventsFuture;
  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    "All",
    "Youth",
    "Awards",
    "Academic",
    "Gala",
  ];

  Timer? _musicTimer;
  List<dynamic> _songsList = [];
  Map<String, dynamic>? _currentSong;

  List<dynamic> _notices = [];
  bool _noticesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadSongs();
    _loadNotices();
  }

  @override
  void dispose() {
    _musicTimer?.cancel();
    super.dispose();
  }

  void _loadEvents() {
    setState(() {
      _eventsFuture = _fetchEventsFromDjango();
    });
  }

  Future<void> _loadNotices() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _noticesLoaded = true);
        return;
      }

      String token = await user.getIdToken() ?? '';
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final userResp = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${user.uid}'),
        headers: headers,
      );
      if (userResp.statusCode != 200) {
        setState(() => _noticesLoaded = true);
        return;
      }
      final userData = json.decode(userResp.body);
      if (userData is! List || userData.isEmpty) {
        setState(() => _noticesLoaded = true);
        return;
      }
      final overseerUid = userData[0]['overseer_uid'];
      if (overseerUid == null || overseerUid.isEmpty) {
        setState(() => _noticesLoaded = true);
        return;
      }

      final commResp = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/overseer_communications/?overseer_uid=$overseerUid&is_published=true',
        ),
        headers: headers,
      );
      if (commResp.statusCode != 200) {
        setState(() => _noticesLoaded = true);
        return;
      }
      final commData = json.decode(commResp.body);
      if (commData is List) {
        commData.sort((a, b) {
          final aDate =
              DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
          final bDate =
              DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });
        setState(() {
          _notices = commData.take(3).toList();
          _noticesLoaded = true;
        });
      } else {
        setState(() => _noticesLoaded = true);
      }
    } catch (e) {
      print('Error loading notices: $e');
      setState(() => _noticesLoaded = true);
    }
  }

  Future<void> _loadSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      User? user = FirebaseAuth.instance.currentUser;
      String token = user != null ? await user.getIdToken() ?? '' : '';

      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/songs/');
      final headers = {'Content-Type': 'application/json'};
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> fetchedSongs = [];

        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          fetchedSongs = decoded['results'];
        } else if (decoded is List) {
          fetchedSongs = decoded;
        }

        if (fetchedSongs.isNotEmpty) {
          setState(() {
            _songsList = fetchedSongs;
            _currentSong = _songsList[Random().nextInt(_songsList.length)];
          });

          _musicTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
            if (mounted && _songsList.isNotEmpty) {
              setState(() {
                _currentSong = _songsList[Random().nextInt(_songsList.length)];
              });
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching songs: $e");
    }
  }

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

  DateTime _parseEventDate(dynamic event) {
    if (event.containsKey('event_date') && event['event_date'] != null) {
      return DateTime.parse(event['event_date']);
    }
    String dayStr = (event['day']?.toString() ?? '').toLowerCase();
    String monthStr = (event['month']?.toString() ?? '').toLowerCase();
    int year = event['year'] != null
        ? int.tryParse(event['year'].toString()) ?? DateTime.now().year
        : DateTime.now().year;

    if (dayStr.contains('communicated') || monthStr.contains('communicated')) {
      return DateTime(year + 1, 12, 31);
    }

    int day = int.tryParse(dayStr.split('-')[0].trim()) ?? 31;
    int month = _parseMonth(monthStr);

    return DateTime(year, month, day);
  }

  Future<List<dynamic>> _fetchEventsFromDjango() async {
    final prefs = await SharedPreferences.getInstance();
    User? user = FirebaseAuth.instance.currentUser;

    // [PRODUCTION FIX]: Wait a moment for Firebase Auth to restore the session
    if (user == null) {
      try {
        await FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {}
    }

    // If user still null, fallback to cache
    if (user == null) {
      final cached = prefs.getString('saved_combined_events_data');
      return cached != null ? json.decode(cached).take(3).toList() : [];
    }

    try {
      final token = await user.getIdToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Fetch user's profile to get their overseer_uid
      String? overseerUid;
      final userResp = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${user.uid}'),
        headers: headers,
      );
      if (userResp.statusCode == 200) {
        final userData = json.decode(userResp.body);
        if (userData is List && userData.isNotEmpty) {
          overseerUid = userData[0]['overseer_uid'];
        }
      }

      // Build the filtered URL for the overseer-specific events
      String overseerDiaryUrl =
          '${Api().BACKEND_BASE_URL_DEBUG}/overseer_diary_events/';
      if (overseerUid != null && overseerUid.isNotEmpty) {
        overseerDiaryUrl += '?overseer_uid=$overseerUid';
      }

      final responses = await Future.wait([
        http.get(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/events/'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/event_diary/'),
          headers: headers,
        ),
        http.get(Uri.parse(overseerDiaryUrl), headers: headers),
      ]);

      List<dynamic> combined = [];
      for (var res in responses) {
        if (res.statusCode == 200) {
          final body = json.decode(res.body);
          if (body is List)
            combined.addAll(body);
          else if (body is Map && body.containsKey('results'))
            combined.addAll(body['results']);
        }
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      combined = combined.where((event) {
        DateTime eventDate = _parseEventDate(event);
        return eventDate.isAfter(today.subtract(const Duration(days: 1)));
      }).toList();

      combined.sort((a, b) {
        final dateA = _parseEventDate(a);
        final dateB = _parseEventDate(b);
        return dateA.compareTo(dateB);
      });

      await prefs.setString(
        'saved_combined_events_data',
        json.encode(combined),
      );

      return combined.take(3).toList();
    } catch (e) {
      final cached = prefs.getString('saved_combined_events_data');
      return cached != null ? json.decode(cached).take(3).toList() : [];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.05),
      theme.scaffoldBackgroundColor,
    );

    return Container(
      color: neumoBaseColor,
      child: RefreshIndicator(
        onRefresh: () async {
          _loadEvents();
          _loadSongs();
          _loadNotices();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildImportantNotices(theme, neumoBaseColor),
            const SizedBox(height: 20),

            if (_currentSong != null) ...[
              NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: false,
                borderRadius: 25,
                padding: EdgeInsets.all(5),
                child: _buildMusicBanner(context),
              ),
              const SizedBox(height: 10),
            ],

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

  Widget _buildImportantNotices(ThemeData theme, Color baseColor) {
    if (!_noticesLoaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: isIOSPlatform
              ? CupertinoActivityIndicator()
              : CircularProgressIndicator(),
        ),
      );
    }
    if (_notices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.campaign, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Text(
              'Important Notices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.red.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._notices.map((notice) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: NeumorphicContainer(
              color: baseColor,
              isPressed: false,
              borderRadius: 16,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice['subject'] ?? 'Announcement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notice['message_body'] ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notice['created_at'] != null
                        ? DateTime.parse(
                            notice['created_at'],
                          ).toLocal().toString().split(' ')[0]
                        : '',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildEventsList(
    ThemeData theme,
    Color neumoBaseColor,
    List<dynamic> events,
  ) {
    return Column(
      children: events.asMap().entries.map((entry) {
        int index = entry.key;
        var event = entry.value;

        // Parse date properly from event_date field
        String day = event['day']?.toString() ?? '';
        String month = event['month']?.toString() ?? '';

        if (event.containsKey('event_date') && event['event_date'] != null) {
          try {
            DateTime dt = DateTime.parse(event['event_date']);
            day = DateFormat('dd').format(dt);
            month = DateFormat('MMM').format(dt);
          } catch (_) {}
        }

        bool isNextUpcoming = index == 0;
        Color textColor = isNextUpcoming
            ? theme.primaryColor
            : theme.textTheme.bodyMedium!.color!;
        Color iconColor = isNextUpcoming ? theme.primaryColor : theme.hintColor;

        String title = event['title'] ?? 'No Title';
        String description =
            event['description'] ?? 'Event details to be communicated.';
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
                  // --- 🔥 LEFT: SQUARE DATE BOX ---
                  NeumorphicContainer(
                    color: isNextUpcoming
                        ? theme.primaryColor.withOpacity(0.1)
                        : neumoBaseColor,
                    isPressed: true,
                    borderRadius: 8, // Makes it a square box
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        day.toLowerCase().contains("communicated")
                            ? Icon(
                                Icons.pending_actions,
                                color: isNextUpcoming
                                    ? theme.primaryColor
                                    : textColor,
                                size: 20,
                              )
                            : Column(
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
                                  if (month.isNotEmpty &&
                                      !month.toLowerCase().contains(
                                        "communicated",
                                      ))
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
                      ],
                    ),
                  ),

                  SizedBox(width: 16),

                  // --- MIDDLE: TITLE & DURATION ---
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

                  // --- 🔥 RIGHT: POSTER THUMBNAIL (Replaces Play Icon) ---
                  NeumorphicContainer(
                    isPressed: true,
                    borderRadius: 8,
                    padding: EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: posterUrl.isNotEmpty
                          ? Image.network(
                              posterUrl,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 55,
                                    height: 55,
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                                  ),
                            )
                          : Container(
                              width: 55,
                              height: 55,
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.image_not_supported,
                                size: 24,
                                color: Colors.grey[500],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

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

  Widget _buildMusicBanner(BuildContext context) {
    if (_currentSong == null) return const SizedBox.shrink();

    String title = _currentSong!['song_name'] ?? 'Unknown Title';
    String artist =
        _currentSong!['artist']?.toString().toUpperCase() ?? 'UNKNOWN ARTIST';
    String songId =
        _currentSong!['uid']?.toString() ??
        _currentSong!['id']?.toString() ??
        '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 3000),
        child: Container(
          key: ValueKey<String>(songId),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8E24AA), Color(0xFF1E88E5)],
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
              Positioned(
                right: 20,
                bottom: 20,
                child: Icon(
                  Icons.music_note,
                  size: 80,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15.0),
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
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              "FEATURED MUSIC",
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              if (songId.isNotEmpty) {
                                MotherPage.deepLinkSongIdNotifier.value =
                                    songId;
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_circle_fill,
                                    color: Color(0xFF8E24AA),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Listen Now",
                                    style: TextStyle(
                                      color: Color(0xFF8E24AA),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
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
