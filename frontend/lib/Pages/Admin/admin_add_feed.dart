// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print, unused_import, unnecessary_null_comparison

import 'dart:convert'; // Added for JSON
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'dart:io' as io show File;
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Added for API
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ttact/Components/API.dart';

// ⭐️ IMPORTS
import 'package:ttact/Components/BibleVerseRepository.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 700.0;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class PortalAddFeed extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const PortalAddFeed({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<PortalAddFeed> createState() => _PortalAddFeedState();
}

class _PortalAddFeedState extends State<PortalAddFeed>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _isWeb = kIsWeb;

  // Controllers for Add Event Form
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  XFile? _pickedPoster;
  String? _selectedProvince;
  String? _selectedCategoryForAdd;

  // Controllers for EDIT Event Sheet
  final TextEditingController _editDescriptionController =
      TextEditingController();
  final TextEditingController _liveStreamLinkController =
      TextEditingController();
  XFile? _editPickedPoster;
  String? _selectedCategoryForEdit;

  final List<String> _southAfricanProvinces = [
    'Eastern Cape',
    'Free State',
    'Gauteng',
    'KwaZulu-Natal',
    'Limpopo',
    'Mpumalanga',
    'Northern Cape',
    'North West',
    'Western Cape',
  ];

  final List<String> _eventCategories = [
    "Youth",
    "Worship",
    "Outreach",
    "Academic",
    "Gala",
    "General",
  ];

  List<Map<String, dynamic>> _allFetchedEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoadingEvents = true;

  int _currentSegment = 0;
  int _selectedCategoryFilterIndex = 0;
  List<String> get _filterCategories => ["All", ..._eventCategories];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchAndFilterEvents();
  }

  void _handleTabSelection() {
    setState(() {
      _currentSegment = _tabController.index;
    });
    if (_tabController.index == 0) {
      _fetchAndFilterEvents();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _editDescriptionController.dispose();
    _liveStreamLinkController.dispose();
    super.dispose();
  }

  // --- CORE FUNCTIONALITY (DJANGO API) ---

  // 1. FETCH EVENTS
  Future<void> _fetchAndFilterEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/events/');
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Map Django Data to App Logic
        List<Map<String, dynamic>> fetchedEvents = data.map((e) {
          return {
            'id': e['id'].toString(), // Ensure ID is string
            'title': e['title'],
            'description': e['description'],
            'day': e['day'],
            'month': e['month'],
            'year': e['year'],
            'parsedDate': e['parsed_date'], // ISO String from Django
            'posterUrl': e['poster_image'], // Django returns full URL here
            'province': e['province'],
            'category': e['category'],
            'liveStreamLink': e['live_stream_link'],
          };
        }).toList();

        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);

        // Client-side Date Filtering (Future events only)
        _allFetchedEvents = fetchedEvents.where((event) {
          final DateTime? eventDate = _parseEventStartDate(event);
          if (eventDate == null) {
            return event['day']?.toLowerCase()?.contains('to be confirmed') ??
                false;
          }
          final DateTime eventDay = DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
          );
          return eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today);
        }).toList();

        _applyCategoryFilter();
      } else {
        throw Exception("Failed to load: ${response.statusCode}");
      }
    } catch (e) {
      print('Error fetching events: $e');
      if (mounted) {
        Api().showMessage(
          context,
          "Failed to load events",
          '',
          Theme.of(context).primaryColorDark,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  void _applyCategoryFilter() {
    String selectedCategory = _filterCategories[_selectedCategoryFilterIndex];

    setState(() {
      if (selectedCategory == "All") {
        _filteredEvents = List.from(_allFetchedEvents);
      } else {
        _filteredEvents = _allFetchedEvents.where((event) {
          String? eventCat = event['category'];
          return eventCat == selectedCategory;
        }).toList();
      }

      _filteredEvents.sort((a, b) {
        final DateTime? dateA = _parseEventStartDate(a);
        final DateTime? dateB = _parseEventStartDate(b);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });
    });
  }

  // 2. ADD EVENT (MULTIPART POST)
  Future<void> _addEvent() async {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDate == null ||
        _selectedProvince == null ||
        _selectedCategoryForAdd == null) {
      Api().showMessage(
        context,
        "Please fill all fields",
        '',
        Theme.of(context).colorScheme.error,
      );
      return;
    }

    Api().showLoading(context);

    try {
      var uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/events/');
      var request = http.MultipartRequest('POST', uri);

      // Add Text Fields (Snake Case for Django)
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();

      // Formatting Date parts for display logic
      request.fields['day'] = DateFormat('dd').format(_selectedDate!);
      request.fields['month'] = DateFormat('MMM').format(_selectedDate!);
      request.fields['year'] = DateFormat('yyyy').format(_selectedDate!);

      // ISO Date for sorting/querying
      request.fields['parsed_date'] = _selectedDate!.toIso8601String().split(
        'T',
      )[0];

      request.fields['province'] = _selectedProvince!;
      request.fields['category'] = _selectedCategoryForAdd!;
      request.fields['live_stream_link'] = ''; // Optional initially

      // Add File
      if (_pickedPoster != null) {
        if (_isWeb) {
          var bytes = await _pickedPoster!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'poster_image', // Key matches Django model
              bytes,
              filename: _pickedPoster!.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'poster_image',
              _pickedPoster!.path,
            ),
          );
        }
      }

        String token = await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
        request.headers['Authorization'] = 'Bearer $token';
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); // Close loading

      if (response.statusCode == 201) {
        Api().showMessage(
          context,
          "Event added successfully!",
          '',
          Theme.of(context).splashColor,
        );
        _clearForm();
        if (isIOSPlatform) {
          setState(() => _currentSegment = 0);
          _tabController.animateTo(0);
        } else {
          _tabController.animateTo(0);
        }
      } else {
        Api().showMessage(
          context,
          "Failed: ${response.body}",
          '',
          Theme.of(context).primaryColorDark,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        "Error: ${e.toString()}",
        '',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedDate = null;
      _pickedPoster = null;
      _selectedProvince = null;
      _selectedCategoryForAdd = null;
    });
  }

  // 3. UPDATE EVENT (MULTIPART PATCH)
  Future<void> _updateEventDetails({
    required String documentId,
    required String newDescription,
    required String newLink,
    required String? newCategory,
    required XFile? newPosterFile,
    required String? currentPosterUrl,
  }) async {
    Api().showLoading(context);

    try {
      var uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/events/$documentId/',
      );
      var request = http.MultipartRequest(
        'PATCH',
        uri,
      ); // PATCH for partial update

        String token = await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
        request.headers['Authorization'] = 'Bearer $token';
      request.fields['description'] = newDescription.trim();
      request.fields['live_stream_link'] = newLink.trim();
      if (newCategory != null) {
        request.fields['category'] = newCategory;
      }

      if (newPosterFile != null) {
        if (_isWeb) {
          var bytes = await newPosterFile.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'poster_image',
              bytes,
              filename: newPosterFile.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'poster_image',
              newPosterFile.path,
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); // Close Loading

      if (response.statusCode == 200) {
        Navigator.pop(context); // Close Sheet
        Api().showMessage(
          context,
          "Event updated!",
          '',
          Theme.of(context).splashColor,
        );
        _fetchAndFilterEvents();
      } else {
        Api().showMessage(
          context,
          "Update Failed: ${response.statusCode}",
          '',
          Theme.of(context).primaryColorDark,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        "Error: ${e.toString()}",
        '',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  // --- EDIT SHEET ---
  void _showEditEventSheet(Map<String, dynamic> event) {
    final String documentId = event['id'];
    final String currentPosterUrl = event['posterUrl'] ?? '';
    final String currentTitle = event['title'] ?? 'N/A';

    _editDescriptionController.text = event['description'] ?? '';
    _liveStreamLinkController.text = event['liveStreamLink'] ?? '';

    String? currentCat = event['category'];
    _selectedCategoryForEdit =
        (currentCat != null && _eventCategories.contains(currentCat))
        ? currentCat
        : _eventCategories.last;

    _editPickedPoster = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isIOSPlatform ? Colors.transparent : null,
      builder: (context) {
        final color = Theme.of(context);
        final childContent = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                    top: 20,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isIOSPlatform)
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        Text(
                          'Edit: $currentTitle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color.primaryColor,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildPlatformTextField(
                          controller: _editDescriptionController,
                          label: 'Update Description',
                          maxLines: 5,
                          minLines: 3,
                          keyboardType: TextInputType.multiline,
                        ),
                        const SizedBox(height: 16),
                        _buildPlatformDropdown(
                          value: _selectedCategoryForEdit,
                          items: _eventCategories,
                          hint: "Event Category",
                          onChanged: (val) {
                            setModalState(() => _selectedCategoryForEdit = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildPlatformTextField(
                          controller: _liveStreamLinkController,
                          label: 'Live Stream/URL Link',
                          prefixIcon: isIOSPlatform
                              ? CupertinoIcons.link
                              : Icons.link,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPlatformButton(
                                onPressed: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (image != null)
                                    setModalState(
                                      () => _editPickedPoster = image,
                                    );
                                },
                                text: _editPickedPoster == null
                                    ? 'Change Poster'
                                    : 'New Selected',
                                icon: isIOSPlatform
                                    ? CupertinoIcons.photo
                                    : Icons.image,
                                color: color.splashColor,
                              ),
                            ),
                            if (currentPosterUrl.isNotEmpty ||
                                _editPickedPoster != null) ...[
                              const SizedBox(width: 8),
                              isIOSPlatform
                                  ? CupertinoButton(
                                      child: const Text('Clear'),
                                      onPressed: () => setModalState(
                                        () => _editPickedPoster = null,
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: () => setModalState(
                                        () => _editPickedPoster = null,
                                      ),
                                      child: const Text('Clear'),
                                    ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_editPickedPoster != null)
                          _buildImagePreview(
                            _editPickedPoster!,
                            150,
                            setModalState,
                          )
                        else if (currentPosterUrl.isNotEmpty)
                          _buildNetworkImagePreview(currentPosterUrl),
                        const SizedBox(height: 24),
                        _buildPlatformButton(
                          onPressed: () {
                            if (_editDescriptionController.text.isEmpty) {
                              Api().showMessage(
                                context,
                                "Description required.",
                                '',
                                Theme.of(context).colorScheme.error,
                              );
                              return;
                            }
                            _updateEventDetails(
                              documentId: documentId,
                              newDescription: _editDescriptionController.text,
                              newLink: _liveStreamLinkController.text,
                              newCategory: _selectedCategoryForEdit,
                              newPosterFile: _editPickedPoster,
                              currentPosterUrl: currentPosterUrl,
                            );
                          },
                          text: 'Save Updates',
                          icon: isIOSPlatform
                              ? CupertinoIcons.floppy_disk
                              : Icons.save,
                        ),
                        const SizedBox(height: 8),
                        if (isIOSPlatform)
                          CupertinoButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );

        if (isIOSPlatform) {
          return Container(
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: childContent,
          );
        } else {
          return childContent;
        }
      },
    );
  }

  // --- UI WIDGETS ---
  // (Verse Card, Banner, Filters, Empty State, Platform Builders)
  // Kept mostly identical to your design, logic updated inside methods

  Widget _buildDailyVerseCard(ThemeData color, Map<String, String> verseData) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.primaryColor, color.primaryColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              color: color.scaffoldBackgroundColor,
            ),
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Verse',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color.primaryColor,
                  ),
                ),
                Divider(
                  height: 25,
                  thickness: 1,
                  color: color.primaryColor.withOpacity(0.2),
                ),
                Text(
                  '"${verseData['text']}"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '- ${verseData['ref']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color.primaryColor.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpportunityBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "NEW OPPORTUNITIES",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Bursaries & Internships",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Boost your career today!",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 15),
                      InkWell(
                        onTap: () {
                          Api().showMessage(
                            context,
                            "Navigating to Opportunities...",
                            '',
                            Colors.blue,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
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
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: Colors.white.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(ThemeData color) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterCategories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryFilterIndex = index;
                  _applyCategoryFilter();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? color.primaryColor
                        : Colors.grey.withOpacity(0.3),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    _filterCategories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  Widget _buildInteractiveEmptyState(ThemeData color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        margin: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          color: color.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_note,
              size: 60,
              color: color.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "No Events Found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Try clearing the filter or add one!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryFilterIndex = 0;
                      _applyCategoryFilter();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text("Clear Filter"),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _currentSegment = 1);
                    _tabController.animateTo(1);
                  },
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text(
                    "Add Event",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- PLATFORM HELPERS (Unchanged visual logic) ---
  Widget _buildPlatformLoader() => Center(
    child: isIOSPlatform
        ? const CupertinoActivityIndicator()
        : const CircularProgressIndicator(),
  );

  Widget _buildPlatformButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    Color? color,
    Color? textColor,
  }) {
    if (isIOSPlatform) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: onPressed,
          disabledColor: CupertinoColors.quaternarySystemFill,
          borderRadius: BorderRadius.circular(10),
          padding: const EdgeInsets.symmetric(vertical: 14),
          minSize: 45,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: textColor ?? Colors.white),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: color ?? Theme.of(context).primaryColor,
          foregroundColor: textColor ?? Colors.white,
        ),
      );
    }
  }

  Widget _buildPlatformTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    int? minLines,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
  }) {
    if (isIOSPlatform) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
            child: Text(
              label,
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoTextField(
            controller: controller,
            placeholder: 'Enter $label',
            maxLines: maxLines,
            minLines: minLines,
            keyboardType: keyboardType,
            padding: const EdgeInsets.all(12),
            prefix: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(prefixIcon, color: CupertinoColors.systemGrey),
                  )
                : null,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      );
    } else {
      return TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          border: OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
      );
    }
  }

  Future<void> _handleDateSelection() async {
    final now = DateTime.now();
    if (isIOSPlatform) {
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate ?? now,
                  minimumDate: now,
                  maximumDate: DateTime(now.year + 5),
                  onDateTimeChanged: (newDate) =>
                      setState(() => _selectedDate = newDate),
                ),
              ),
              CupertinoButton(
                child: const Text('Done'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    } else {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? now,
        firstDate: now,
        lastDate: DateTime(now.year + 5),
      );
      if (picked != null && picked != _selectedDate)
        setState(() => _selectedDate = picked);
    }
  }

  Widget _buildPlatformDatePickerSelector() {
    final text = _selectedDate == null
        ? 'Select Date'
        : DateFormat('dd MMM yyyy').format(_selectedDate!);
    final icon = isIOSPlatform ? CupertinoIcons.calendar : Icons.calendar_today;
    if (isIOSPlatform) {
      return GestureDetector(
        onTap: _handleDateSelection,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4),
            borderRadius: BorderRadius.circular(8),
            color: CupertinoColors.systemBackground,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: _selectedDate == null
                      ? CupertinoColors.placeholderText
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
              Icon(icon, color: CupertinoColors.systemGrey),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: _handleDateSelection,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Select Date',
            border: OutlineInputBorder(),
            suffixIcon: Icon(icon),
          ),
          child: Text(
            text,
            style: _selectedDate == null
                ? const TextStyle(color: Colors.grey)
                : null,
          ),
        ),
      );
    }
  }

  Widget _buildPlatformDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    if (isIOSPlatform) {
      return GestureDetector(
        onTap: () {
          showCupertinoModalPopup(
            context: context,
            builder: (ctx) => Container(
              height: 250,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: CupertinoPicker(
                      itemExtent: 32,
                      onSelectedItemChanged: (int index) =>
                          onChanged(items[index]),
                      children: items
                          .map((e) => Center(child: Text(e)))
                          .toList(),
                    ),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          );
          if (value == null && items.isNotEmpty) onChanged(items[0]);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4),
            borderRadius: BorderRadius.circular(8),
            color: CupertinoColors.systemBackground,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value ?? hint,
                style: TextStyle(
                  color: value == null
                      ? CupertinoColors.placeholderText
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_down,
                size: 16,
                color: CupertinoColors.systemGrey,
              ),
            ],
          ),
        ),
      );
    } else {
      return DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(),
        ),
        hint: Text(hint),
        items: items
            .map(
              (String item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
      );
    }
  }

  Widget _buildImagePreview(
    XFile file,
    double height,
    StateSetter setModalState,
  ) {
    if (_isWeb)
      return Container(
        height: height,
        color: Colors.grey.shade200,
        child: const Center(
          child: Text(
            "Web Preview Unavailable",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.file(
        io.File(file.path),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildNetworkImagePreview(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.network(
        url,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 150,
              width: double.infinity,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: 150,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEventsTab() {
    final dailyVerse = BibleVerseRepository.getDailyVerse();
    final color = Theme.of(context);
    if (_isLoadingEvents) return _buildPlatformLoader();

    return RefreshIndicator(
      onRefresh: _fetchAndFilterEvents,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDailyVerseCard(color, dailyVerse),
          const SizedBox(height: 25),
          _buildOpportunityBanner(context),
          const SizedBox(height: 25),
          _buildCategoryFilters(color),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: color.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Manage Events',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_filteredEvents.isEmpty)
            _buildInteractiveEmptyState(color)
          else
            Column(
              children: _filteredEvents.map((event) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: GestureDetector(
                    onTap: () => _showEditEventSheet(event),
                    child: UpcomingEventsCard(
                      posterUrl:
                          (event['posterUrl'] != null &&
                              event['posterUrl'].toString().isNotEmpty)
                          ? event['posterUrl']
                          : null,
                      date: event['day'] ?? '',
                      eventMonth: event['month'] ?? '',
                      eventTitle: event['title'] ?? '',
                      eventDescription: event['description'] ?? '',
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildAddEventTab() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add New Event',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  decoration: TextDecoration.none,
                ),
              ),
              const Divider(height: 20),
              _buildPlatformTextField(
                controller: _titleController,
                label: 'Event Name',
              ),
              const SizedBox(height: 16),
              _buildPlatformTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 5,
                minLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16),
              _buildPlatformDatePickerSelector(),
              const SizedBox(height: 16),
              _buildPlatformDropdown(
                value: _selectedProvince,
                items: _southAfricanProvinces,
                hint: "Select Province",
                onChanged: (val) => setState(() => _selectedProvince = val),
              ),
              const SizedBox(height: 16),
              _buildPlatformDropdown(
                value: _selectedCategoryForAdd,
                items: _eventCategories,
                hint: "Select Category",
                onChanged: (val) =>
                    setState(() => _selectedCategoryForAdd = val),
              ),
              const SizedBox(height: 16),
              _buildPlatformButton(
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) setState(() => _pickedPoster = image);
                },
                text: _pickedPoster == null
                    ? 'Pick Poster (Optional)'
                    : 'Poster Selected',
                icon: isIOSPlatform ? CupertinoIcons.photo : Icons.image,
                color: Theme.of(context).scaffoldBackgroundColor,
                textColor: Theme.of(context).primaryColor,
              ),
              if (_pickedPoster != null) ...[
                const SizedBox(height: 10),
                _buildImagePreview(_pickedPoster!, 150, (_) {}),
                const SizedBox(height: 10),
                isIOSPlatform
                    ? CupertinoButton(
                        onPressed: () => setState(() => _pickedPoster = null),
                        child: const Text('Remove Poster'),
                      )
                    : TextButton(
                        onPressed: () => setState(() => _pickedPoster = null),
                        child: const Text('Remove Poster'),
                      ),
              ],
              const SizedBox(height: 24),
              _buildPlatformButton(
                onPressed: _addEvent,
                text: 'Add Event',
                icon: isIOSPlatform ? CupertinoIcons.add : Icons.add,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isIOSPlatform) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSegmentedControl<int>(
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text("Upcoming Events"),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text("Add Event"),
                  ),
                },
                onValueChanged: (int val) {
                  setState(() {
                    _currentSegment = val;
                    _tabController.animateTo(val);
                  });
                  if (val == 0) _fetchAndFilterEvents();
                },
                groupValue: _currentSegment,
                borderColor: Theme.of(context).primaryColor,
                selectedColor: Theme.of(context).primaryColor,
                pressedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            ),
          ),
          Expanded(
            child: _currentSegment == 0
                ? _buildUpcomingEventsTab()
                : _buildAddEventTab(),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Upcoming Events', icon: Icon(Icons.event)),
              Tab(text: 'Add Event', icon: Icon(Icons.add_circle)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildUpcomingEventsTab(), _buildAddEventTab()],
            ),
          ),
        ],
      );
    }
  }

  static DateTime? _parseEventStartDate(Map<String, dynamic> event) {
    if (event.containsKey('parsedDate') && event['parsedDate'] != null) {
      return DateTime.tryParse(event['parsedDate']);
    }
    return null;
  }
}
