// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class AdminAddEventDiaryPage extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const AdminAddEventDiaryPage({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<AdminAddEventDiaryPage> createState() => _AdminAddEventDiaryPageState();
}

class _AdminAddEventDiaryPageState extends State<AdminAddEventDiaryPage> {
  // --- TABS STATE ---
  int _currentTabIndex = 0; // 0 = Draft Event, 1 = Manage Posters

  // --- DRAFT EVENT STATES ---
  final List<Map<String, dynamic>> _stagedEvents = [];
  bool _isSubmitting = false;

  final List<String> _commonEventTitles = [
    'Sealing Services',
    'Joint Executive Meeting',
    'NEC Meetings',
    "Annual Officers' Opening Meeting",
    'TTACTSO Opening Function',
    'Apostle Day',
    'Senior Testify Sisters',
    'Junior Testify Sisters',
    'General Officers & Tithes Meeting',
    'CYC Provincial & Global Visits',
    'Old Age & Physically Challenged Day',
    'Pre-Examination Services & TTACTSO Closing',
    'Sunday School Weekend',
    'TTACTSO CLOSING Function',
    'Cluster Thanksgiving',
    "Annual Officers' Closing Meeting",
    'CYC Youth Seminars',
    'Other (Type Manually)',
  ];
  String _selectedTitle = 'Sealing Services';
  final TextEditingController _customTitleController = TextEditingController();

  final List<String> _daysList = List.generate(
    31,
    (i) => (i + 1).toString().padLeft(2, '0'),
  );
  String _daySelectionType = 'Single';
  String _selectedSingleDay = '01';
  String _selectedStartDay = '01';
  String _selectedEndDay = '02';

  final List<String> _monthsList = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  List<String> _selectedMonths = [];
  bool _isMonthTBC = false;
  String _selectedYear = DateTime.now().year.toString();
  final List<String> _years = [
    DateTime.now().year.toString(),
    (DateTime.now().year + 1).toString(),
    (DateTime.now().year + 2).toString(),
  ];

  // --- MANAGE POSTERS STATES ---
  List<dynamic> _serverEvents = [];
  bool _isLoadingServerEvents = false;
  String? _uploadingEventId;

  // --- DRAFT EVENT LOGIC ---
  void _stageEvent() {
    String finalTitle = _selectedTitle == 'Other (Type Manually)'
        ? _customTitleController.text.trim()
        : _selectedTitle;

    if (finalTitle.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please provide an Event Title.")));
      return;
    }

    String finalDay;
    if (_daySelectionType == 'TBC') {
      finalDay = "To Be Communicated";
    } else if (_daySelectionType == 'Range') {
      finalDay = "$_selectedStartDay - $_selectedEndDay";
    } else {
      finalDay = _selectedSingleDay;
    }

    String finalMonth;
    if (_isMonthTBC) {
      finalMonth = "To Be Communicated";
    } else {
      finalMonth = _selectedMonths.join(' - ');
    }

    setState(() {
      _stagedEvents.add({
        'title': finalTitle,
        'day': finalDay,
        'month': finalMonth,
        'year': int.parse(_selectedYear),
      });

      _customTitleController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  void _removeStagedEvent(int index) {
    setState(() {
      _stagedEvents.removeAt(index);
    });
  }

  Future<void> _submitAllEvents() async {
    if (_stagedEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "No events to submit. Please add events to the list first.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      int successCount = 0;

      for (var event in _stagedEvents) {
        final response = await http.post(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/event_diary/'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode(event),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          successCount++;
        } else {
          print("Failed to add event: ${response.body}");
        }
      }

      if (successCount == _stagedEvents.length) {
        setState(() {
          _stagedEvents.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Successfully uploaded all $successCount events!",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Uploaded $successCount out of ${_stagedEvents.length}. Some failed.",
            ),
          ),
        );
      }
    } catch (e) {
      print("Submission error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("A network error occurred during submission.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // --- MANAGE POSTERS LOGIC ---
  Future<void> _fetchServerEvents() async {
    setState(() {
      _isLoadingServerEvents = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final response = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/event_diary/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _serverEvents = json.decode(response.body);
        });
      } else {
        print("Failed to fetch events: ${response.body}");
      }
    } catch (e) {
      print("Error fetching server events: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingServerEvents = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPoster(Map<String, dynamic> event) async {
    final picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedImage == null) return;

    setState(() {
      _uploadingEventId = event['id'];
    });

    try {
      File file = File(pickedImage.path);
      String fileName =
          'event_posters/${event['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await http.patch(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/event_diary/${event['id']}/',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({'poster_url': downloadUrl}),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Poster updated successfully!",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        );
        _fetchServerEvents();
      } else {
        print("Backend update failed: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update event with new poster.")),
        );
      }
    } catch (e) {
      print("Upload poster error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred while uploading.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingEventId = null;
        });
      }
    }
  }

  Future<void> _updateEventDetails(
    String eventId,
    String title,
    String day,
    String month,
    String year,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await http.patch(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/event_diary/$eventId/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'title': title,
          'day': day,
          'month': month,
          'year': int.tryParse(year) ?? DateTime.now().year,
        }),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Event updated successfully!",
              style: TextStyle(color: Colors.greenAccent),
            ),
          ),
        );
        _fetchServerEvents();
      } else {
        print("Update failed: ${response.body}");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to update event.")));
      }
    } catch (e) {
      print("Update error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("A network error occurred.")));
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> event) async {
    TextEditingController editTitleController = TextEditingController(
      text: event['title'],
    );
    TextEditingController editDayController = TextEditingController(
      text: event['day'],
    );
    TextEditingController editMonthController = TextEditingController(
      text: event['month'],
    );
    TextEditingController editYearController = TextEditingController(
      text: event['year'].toString(),
    );
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final neumoBaseColor = Color.alphaBlend(
          theme.primaryColor.withOpacity(0.08),
          theme.scaffoldBackgroundColor,
        );

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: neumoBaseColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Edit Event",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Title",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: editTitleController,
                        decoration: InputDecoration(border: InputBorder.none),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Day / Duration",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: editDayController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "e.g., 18 or 11 - 12",
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Month",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: editMonthController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "e.g., Apr",
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Year",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: editYearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(border: InputBorder.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                GestureDetector(
                  onTap: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          await _updateEventDetails(
                            event['id'],
                            editTitleController.text.trim(),
                            editDayController.text.trim(),
                            editMonthController.text.trim(),
                            editYearController.text.trim(),
                          );
                          setDialogState(() => isSaving = false);
                          if (mounted) Navigator.pop(context);
                        },
                  child: NeumorphicContainer(
                    color: theme.primaryColor,
                    borderRadius: 8,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: isSaving
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Save",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTabSwitcher(theme),
            Expanded(
              child: _currentTabIndex == 0
                  ? _buildDraftEventView(theme, isDesktop)
                  : _buildManagePostersView(theme),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB SWITCHER WIDGET ---
  Widget _buildTabSwitcher(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTabIndex = 0),
              child: NeumorphicContainer(
                isPressed: _currentTabIndex == 0,
                borderRadius: 12,
                color: _currentTabIndex == 0 ? theme.primaryColor : null,
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    "Draft Event",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currentTabIndex == 0
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentTabIndex = 1;
                  if (_serverEvents.isEmpty) {
                    _fetchServerEvents();
                  }
                });
              },
              child: NeumorphicContainer(
                isPressed: _currentTabIndex == 1,
                borderRadius: 12,
                color: _currentTabIndex == 1 ? theme.primaryColor : null,
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    "Manage Events",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currentTabIndex == 1
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DRAFT EVENT TAB ---
  Widget _buildDraftEventView(ThemeData theme, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SingleChildScrollView(child: _buildForm(theme))),
          Container(
            width: 1,
            color: theme.primaryColor.withOpacity(0.2),
            margin: EdgeInsets.symmetric(vertical: 20),
          ),
          Expanded(child: _buildStagedList(theme, isMobile: false)),
        ],
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildForm(theme),
            Container(
              height: 1,
              color: theme.primaryColor.withOpacity(0.2),
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            _buildStagedList(theme, isMobile: true),
          ],
        ),
      );
    }
  }

  Widget _buildForm(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Draft New Event",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Select the event details below to add it to the staging list.",
            style: TextStyle(color: Colors.grey[700]),
          ),
          SizedBox(height: 24),
          Text(
            "Event Title *",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          NeumorphicContainer(
            isPressed: true,
            borderRadius: 12,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTitle,
                isExpanded: true,
                items: _commonEventTitles.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedTitle = newValue!;
                  });
                },
              ),
            ),
          ),

          if (_selectedTitle == 'Other (Type Manually)') ...[
            SizedBox(height: 12),
            NeumorphicContainer(
              isPressed: true,
              borderRadius: 12,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _customTitleController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "Type custom event title...",
                  hintStyle: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
          ],
          SizedBox(height: 24),

          // --- DAY SELECTION ---
          Text(
            "Day / Duration",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildToggleTab("Single", "Single", theme),
              SizedBox(width: 8),
              _buildToggleTab("Range", "Range", theme),
              SizedBox(width: 8),
              _buildToggleTab("TBC", "TBC", theme),
            ],
          ),
          SizedBox(height: 12),

          if (_daySelectionType == 'Single')
            NeumorphicContainer(
              isPressed: true,
              borderRadius: 12,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSingleDay,
                  isExpanded: true,
                  items: _daysList
                      .map(
                        (String value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSingleDay = val!),
                ),
              ),
            )
          else if (_daySelectionType == 'Range')
            Row(
              children: [
                Expanded(
                  child: NeumorphicContainer(
                    isPressed: true,
                    borderRadius: 12,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStartDay,
                        isExpanded: true,
                        items: _daysList
                            .map(
                              (String value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedStartDay = val!),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    "to",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: NeumorphicContainer(
                    isPressed: true,
                    borderRadius: 12,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedEndDay,
                        isExpanded: true,
                        items: _daysList
                            .map(
                              (String value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedEndDay = val!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 24),

          // --- MONTH SELECTION ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Month(s)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _isMonthTBC,
                    activeColor: theme.primaryColor,
                    onChanged: (val) {
                      setState(() {
                        _isMonthTBC = val ?? false;
                        if (_isMonthTBC) _selectedMonths.clear();
                      });
                    },
                  ),
                  Text(
                    "To Be Communicated",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
          if (!_isMonthTBC) ...[
            SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _monthsList.map((month) {
                bool isSelected = _selectedMonths.contains(month);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedMonths.remove(month);
                      } else {
                        _selectedMonths.add(month);
                        // Sort chronologically
                        _selectedMonths.sort(
                          (a, b) => _monthsList
                              .indexOf(a)
                              .compareTo(_monthsList.indexOf(b)),
                        );
                      }
                    });
                  },
                  child: NeumorphicContainer(
                    isPressed: isSelected,
                    borderRadius: 20,
                    color: isSelected
                        ? theme.primaryColor.withOpacity(0.1)
                        : null,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(
                      month,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.primaryColor
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          SizedBox(height: 24),

          // --- YEAR SELECTION ---
          Text(
            "Year",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          NeumorphicContainer(
            isPressed: true,
            borderRadius: 12,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedYear,
                isExpanded: true,
                items: _years.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedYear = newValue!;
                  });
                },
              ),
            ),
          ),
          SizedBox(height: 30),

          GestureDetector(
            onTap: _stageEvent,
            child: NeumorphicContainer(
              color: theme.primaryColor,
              borderRadius: 12,
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  "Add to List",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab(String title, String value, ThemeData theme) {
    bool isSelected = _daySelectionType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _daySelectionType = value),
        child: NeumorphicContainer(
          isPressed: isSelected,
          borderRadius: 8,
          color: isSelected ? theme.primaryColor : null,
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- STAGED LIST WIDGET ---
  Widget _buildStagedList(ThemeData theme, {required bool isMobile}) {
    Widget listContent = _stagedEvents.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: Text(
                "No events staged yet.\nSelect events from the form.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            ),
          )
        : ListView.builder(
            shrinkWrap: isMobile,
            physics: isMobile
                ? NeverScrollableScrollPhysics()
                : AlwaysScrollableScrollPhysics(),
            itemCount: _stagedEvents.length,
            itemBuilder: (context, index) {
              final event = _stagedEvents[index];
              String dayDisplay = event['day'];
              bool isDayTBC = dayDisplay.toLowerCase().contains("communicated");

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: NeumorphicContainer(
                  borderRadius: 16,
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      NeumorphicContainer(
                        isPressed: true,
                        borderRadius: 10,
                        padding: EdgeInsets.all(12),
                        child: Column(
                          children: [
                            isDayTBC
                                ? Icon(
                                    Icons.pending_actions,
                                    color: theme.primaryColor,
                                  )
                                : Text(
                                    dayDisplay.split('-')[0].trim(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                      fontSize: 18,
                                    ),
                                  ),
                            if (event['month'].toString().isNotEmpty &&
                                !isDayTBC)
                              Text(
                                event['month'].toString().split(' ')[0],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event['title'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Date: ${event['day']} ${event['month'].toString().isNotEmpty ? event['month'] : ''} ${event['year']}",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade400,
                        ),
                        onPressed: () => _removeStagedEvent(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Staged Events (${_stagedEvents.length})",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
              if (_stagedEvents.isNotEmpty)
                GestureDetector(
                  onTap: _isSubmitting ? null : _submitAllEvents,
                  child: NeumorphicContainer(
                    color: Colors.green.shade600,
                    borderRadius: 8,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: _isSubmitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Submit All",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20),
          isMobile ? listContent : Expanded(child: listContent),
        ],
      ),
    );
  }

  // --- MANAGE POSTERS & EVENTS TAB ---
  Widget _buildManagePostersView(ThemeData theme) {
    if (_isLoadingServerEvents) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (_serverEvents.isEmpty) {
      return Center(
        child: Text(
          "No events found on server.",
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchServerEvents,
      color: theme.primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.all(24),
        itemCount: _serverEvents.length,
        itemBuilder: (context, index) {
          final event = _serverEvents[index];
          final String eventId = event['id'];
          final String title = event['title'] ?? 'Unknown Event';
          final String date =
              "${event['day']} ${event['month']} ${event['year']}";
          final String posterUrl = event['poster_url'] ?? '';
          final bool isUploading = _uploadingEventId == eventId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: NeumorphicContainer(
              borderRadius: 16,
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  NeumorphicContainer(
                    isPressed: true,
                    borderRadius: 12,
                    padding: EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: posterUrl.isNotEmpty
                          ? Image.network(
                              posterUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.broken_image, color: Colors.grey),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[500],
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // Edit Button
                  GestureDetector(
                    onTap: isUploading ? null : () => _showEditDialog(event),
                    child: NeumorphicContainer(
                      color: theme.primaryColor,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Upload Poster Button
                  GestureDetector(
                    onTap: isUploading
                        ? null
                        : () => _pickAndUploadPoster(event),
                    child: NeumorphicContainer(
                      color: isUploading ? Colors.grey : theme.primaryColor,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: isUploading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.upload_file,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
