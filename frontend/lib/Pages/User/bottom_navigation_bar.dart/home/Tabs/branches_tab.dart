// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/API.dart'; // Ensure API is imported
import 'package:ttact/Components/HomePageHelpers.dart';
import 'package:ttact/Components/Tactso_Branch_Details.dart' hide isIOSPlatform;
import 'package:ttact/Components/UniversityCard.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class BranchesTab extends StatefulWidget {
  final bool isDesktop;
  const BranchesTab({super.key, required this.isDesktop});

  @override
  State<BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<BranchesTab> {
  final TextEditingController _branchSearchController = TextEditingController();
  String _branchSearchQuery = '';

  // Future for caching the API call
  late Future<List<dynamic>> _branchesFuture;

  @override
  void initState() {
    super.initState();
    _branchesFuture = _fetchBranches();
    _branchSearchController.addListener(() {
      setState(() {
        _branchSearchQuery = _branchSearchController.text;
      });
    });
  }

  @override
  void dispose() {
    _branchSearchController.dispose();
    super.dispose();
  }

  // --- 1. FETCH BRANCHES (DJANGO - SECURED) ---
  Future<List<dynamic>> _fetchBranches() async {
    try {
      // SECURE FIX: Grab the current user and their token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Blocked: No user is currently logged in.");
        return []; 
      }

      String? token = await user.getIdToken();
      if (token == null) {
        print("❌ Blocked: Could not retrieve Firebase token.");
        return [];
      }

      // URL: /api/tactso_branches/
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/tactso_branches/');
      
      // SECURE FIX: Make the GET Request WITH the Authorization Header
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Assuming Django returns a JSON List
        print(response.body);
        return json.decode(response.body);
      } else {
        print('Error fetching branches: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Network error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return FutureBuilder<List<dynamic>>(
      future: _branchesFuture,
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
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading branches',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No branches found',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }

        final branchList = snapshot.data!;

        // Group campuses by University Name
        Map<String, List<Map<String, dynamic>>> groupedUniversities = {};

        for (var item in branchList) {
          // Convert to Map<String, dynamic> safely
          final data = item as Map<String, dynamic>;

          // Handle Django snake_case vs legacy camelCase
          final universityName =
              (data['university_name'] ??
                      data['university_name'] ??
                      'Unknown University')
                  .toString()
                  .toLowerCase();

          // Filter by search query
          if (_branchSearchQuery.isEmpty ||
              universityName.contains(_branchSearchQuery.toLowerCase())) {
            if (!groupedUniversities.containsKey(universityName)) {
              groupedUniversities[universityName] = [];
            }
            groupedUniversities[universityName]!.add(data);
          }
        }

        return ListView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ⭐️ 1. NEUMORPHIC SEARCH BAR
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isDesktop ? 0 : 8.0,
                vertical: widget.isDesktop ? 20.0 : 10.0,
              ),
              child: NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: true, // Sunken
                borderRadius: 30,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _branchSearchController,
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  decoration: InputDecoration(
                    hintText: 'Search branches...',
                    hintStyle: TextStyle(color: theme.hintColor),
                    border: InputBorder.none,
                    icon: Icon(
                      isIOSPlatform ? CupertinoIcons.search : Icons.search,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ⭐️ 2. WRAP GRID
            Wrap(
              alignment: WrapAlignment.center,
              spacing: widget.isDesktop ? 20.0 : 15.0,
              runSpacing: widget.isDesktop ? 20.0 : 20.0,
              children: groupedUniversities.entries.map((entry) {
                final String universityName = entry.key; // Lowercase key
                final List<Map<String, dynamic>> campuses = entry.value;
                final Map<String, dynamic> representativeCampusData =
                    campuses.first;

                // Check if application is open (handle snake_case)
                final bool anyCampusApplicationOpen = campuses.any(
                  (campus) =>
                      (campus['is_application_open'] ??
                          campus['isApplicationOpen']) ==
                      true,
                );

                // Prepare Data for UI (Handle Django Fields)
                // Django likely returns 'image_url' instead of 'imageUrl'
                // And it might be a simple string or list depending on your serializer.
                // Assuming standard Django ImageField returns a full URL string.

                // Helper to get image URL safely
                String? getImgUrl(Map<String, dynamic> data) {
                  var img = data['image_url'] ?? data['imageUrl'];
                  if (img is List && img.isNotEmpty) return img[0];
                  if (img is String && img.isNotEmpty) return img;
                  return null;
                }

                // Display Name (Capitalize first letters for display)
                String displayName =
                    (representativeCampusData['university_name'] ??
                            representativeCampusData['universityName'] ??
                            universityName)
                        .toString();

                final cardWidth = widget.isDesktop
                    ? (MediaQuery.of(context).size.width * 0.8) / 4 - 40
                    : MediaQuery.of(context).size.width / 2 - 24;

                return SizedBox(
                  width: cardWidth,
                  // ⭐️ 3. NEUMORPHIC TILE
                  child: NeumorphicContainer(
                    color: neumoBaseColor,
                    isPressed: false,
                    borderRadius: 20,
                    padding: EdgeInsets.all(0),
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          scrollControlDisabledMaxHeightRatio: 0.9,
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) {
                            return TactsoBranchDetails(
                              universityDetails: representativeCampusData,
                              // If 'campuses' list isn't nested in Django response,
                              // we pass the grouped list we just created.
                              campusListForUniversity: campuses,
                            );
                          },
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: UniversityCard(
                          imageUrl: getImgUrl(representativeCampusData),
                          UniName: displayName,
                          uniAddress: representativeCampusData['address'] ?? '',
                          applicationLink:
                              representativeCampusData['application_link'] ??
                              representativeCampusData['application_link'] ??
                              '',
                          onPressed: () {
                            showModalBottomSheet(
                              scrollControlDisabledMaxHeightRatio: 0.9,
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) {
                                return TactsoBranchDetails(
                                  universityDetails: representativeCampusData,
                                  campusListForUniversity: campuses,
                                );
                              },
                            );
                          },
                          applicationIsOpen: anyCampusApplicationOpen,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 50),
          ],
        );
      },
    );
  }
}