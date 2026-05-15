// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // Auth State only
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Share_Career_Card.dart';
import 'package:ttact/Pages/Auth/sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1000.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
// --------------------------

class CareerOpportunities extends StatefulWidget {
  const CareerOpportunities({super.key});

  @override
  State<CareerOpportunities> createState() => _CareerOpportunitiesState();
}

class _CareerOpportunitiesState extends State<CareerOpportunities> {
  final List<String> _tabs = [
    'All',
    'Bursary',
    'Scholarship',
    'Internship',
    'In-Service Training',
    'Job',
    'Learnership',
  ];

  int _selectedIndex = 0;

  // --- DESKTOP SPLIT VIEW STATE ---
  Map<String, dynamic>? _selectedOpportunity;
  String? _selectedDocId;
  bool _isDetailsPanelVisible = false;

  late Future<List<dynamic>> _opportunitiesFuture;

  @override
  void initState() {
    super.initState();
    _opportunitiesFuture = _fetchOpportunities();
  }

  // --- 1. FETCH OPPORTUNITIES (DJANGO - SECURED) ---
  Future<List<dynamic>> _fetchOpportunities() async {
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

      // URL: /api/career_opportunities/ (Assumed endpoint)
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/careers/?is_active=true',
      );
      
      // SECURE FIX: Add Authorization header
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("Error fetching opportunities: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("Network error: $e");
      return [];
    }
  }

  // --- 2. Helper: Get Dynamic Email Body ---
  String _getCategorySpecificBody(
    String category,
    String userName,
    String jobTitle,
  ) {
    String cat = category.trim().toLowerCase();
    String titleUpper = jobTitle.toUpperCase();

    if (cat == 'job') {
      return """Dear Hiring Manager,

I hope this message finds you well.

My name is $userName, and I am writing to formally apply for the $titleUpper position. I am highly motivated and eager to contribute my skills, dedication, and willingness to learn within your organization.

This opportunity would allow me to further develop my professional experience while adding value to your team through hard work, reliability, and a positive attitude. I am confident that I can adapt quickly and perform effectively in a professional environment.

Thank you for considering my application. I would appreciate the opportunity to discuss how my skills and enthusiasm can benefit your organization.

Sincerely,  
$userName
""";
    } else {
      return """Dear Hiring Team,

I hope you are doing well.

My name is $userName, and I am writing to express my interest in the $titleUpper opportunity. I am enthusiastic about the possibility of gaining practical experience and expanding my knowledge in this field.

I am committed, eager to learn, and ready to contribute positively while developing valuable skills through this opportunity. I believe this experience would play an important role in my personal and professional growth.

Thank you for your time and consideration. I look forward to the possibility of hearing from you.

Kind regards,  
$userName
""";
    }
  }

  void _showShareSheet(Map<String, dynamic> data, String docId) {
    String title = data['title'] ?? 'Opportunity';
    String category = data['category'] ?? 'General';

    // Date parsing from Django ISO String
    String dateStr = 'Open / Ongoing';
    String? expiryStr = data['expiry_date'] ?? data['expiryDate'];
    if (expiryStr != null) {
      try {
        DateTime dt = DateTime.parse(expiryStr);
        dateStr = DateFormat('dd MMM yyyy').format(dt);
      } catch (e) {
        /* ignore */
      }
    }

    showModalBottomSheet(
      constraints: BoxConstraints(minWidth: double.infinity),
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CareerShareSheet(
        title: title,
        category: category,
        expiryDate: dateStr,
        docId: docId,
        theme: Theme.of(context),
      ),
    );
  }

  // --- 3. REUSABLE DETAILS CONTENT (Redesigned for Neumorphism) ---
  Widget _buildDetailsContent({
    required Map<String, dynamic> data,
    required String docId,
    required bool isScrollableSheet,
    ScrollController? scrollController,
    required VoidCallback onClose,
    required Color baseColor,
  }) {
    final theme = Theme.of(context);
    String title = data['title'] ?? 'Opportunity';
    String category = data['category'] ?? 'General';
    String instructions = data['instructions'] ?? '';
    String oldDescription = data['description'] ?? '';

    // Handling Nested Django Fields (Assuming JSONField or related serializer structure)
    // If backend sends 'required_documents' as list, use it.
    List<dynamic> docs =
        data['required_documents'] ?? data['requiredDocuments'] ?? [];
    String email = data['application_email'] ?? data['applicationEmail'] ?? '';
    String? applicationFormUrl =
        data['application_form_url'] ?? data['applicationFormUrl'];

    // If 'details' is a nested JSON field in Django
    Map<String, dynamic> details = data['details'] ?? {};
    // OR if backend flattened it, access directly from 'data'
    // For safety, assuming nested structure similar to Firestore for minimal frontend change

    String subtitle = details['subtitle'] ?? '';
    String address = details['address'] ?? '';
    String contactNum =
        details['contact_number'] ?? details['contactNumber'] ?? '';
    String financial = details['financial'] ?? '';
    String duration = details['duration'] ?? '';
    String location = details['location'] ?? '';

    List<dynamic> requirementsList =
        details['requirements_list'] ?? details['requirementsList'] ?? [];
    List<dynamic> dutiesList =
        details['duties_list'] ?? details['dutiesList'] ?? [];
    List<dynamic> benefitsList = details['benefits'] ?? [];
    List<dynamic> coursesList =
        details['courses_list'] ?? details['coursesList'] ?? [];

    Widget content = Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isScrollableSheet) ...[
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.hintColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 25),
          ] else ...[
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onClose,
                child: NeumorphicContainer(
                  color: baseColor,
                  borderRadius: 50,
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: theme.hintColor),
                ),
              ),
            ),
          ],

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicContainer(
                      color: baseColor,
                      isPressed: true, // Sunken Label
                      borderRadius: 8,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryColor,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showShareSheet(data, docId),
                child: NeumorphicContainer(
                  color: baseColor,
                  borderRadius: 50,
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.share, size: 20, color: theme.primaryColor),
                ),
              ),
            ],
          ),
          SizedBox(height: 25),

          // --- Quick Info Row ---
          if (financial.isNotEmpty ||
              location.isNotEmpty ||
              duration.isNotEmpty)
            Row(
              children: [
                if (financial.isNotEmpty)
                  Expanded(
                    child: _buildNeuQuickInfo(
                      baseColor,
                      Icons.payments_outlined,
                      financial,
                      "Salary/Stipend",
                    ),
                  ),
                if (financial.isNotEmpty) SizedBox(width: 10),
                if (location.isNotEmpty)
                  Expanded(
                    child: _buildNeuQuickInfo(
                      baseColor,
                      Icons.location_on_outlined,
                      location,
                      "Location",
                    ),
                  ),
                if (location.isNotEmpty) SizedBox(width: 10),
                if (duration.isNotEmpty)
                  Expanded(
                    child: _buildNeuQuickInfo(
                      baseColor,
                      Icons.timer_outlined,
                      duration,
                      "Duration",
                    ),
                  ),
              ],
            ),

          SizedBox(height: 20),

          // --- INFO SECTIONS ---
          if (applicationFormUrl != null && applicationFormUrl.isNotEmpty) ...[
            NeumorphicContainer(
              color: baseColor,
              isPressed: false,
              borderRadius: 15,
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.file_present, color: Colors.orange, size: 30),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Form Required",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Download and attach.",
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _launchWebURL(applicationFormUrl),
                    child: Text(
                      "Download",
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],

          if (instructions.isNotEmpty) ...[
            NeumorphicContainer(
              color: baseColor,
              isPressed: true,
              borderRadius: 15,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.hintColor,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Instructions",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    instructions,
                    style: TextStyle(fontSize: 13, color: theme.primaryColor),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],

          // Details List
          _buildDetailSection(context, "Fields of Study", coursesList),
          _buildDetailSection(context, "Requirements", requirementsList),
          _buildDetailSection(context, "Responsibilities", dutiesList),

          if (oldDescription.isNotEmpty && dutiesList.isEmpty) ...[
            Text(
              "Description",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(oldDescription, style: TextStyle(color: theme.primaryColor)),
            SizedBox(height: 20),
          ],

          _buildDetailSection(context, "Benefits", benefitsList, isCheck: true),
          _buildDetailSection(
            context,
            "Documents Required",
            docs,
            isCheck: true,
          ),

          Divider(height: 40, color: theme.hintColor.withOpacity(0.2)),

          // Contact
          if (email.isNotEmpty ||
              address.isNotEmpty ||
              contactNum.isNotEmpty) ...[
            Text(
              "Contact Details",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 15),
            if (email.isNotEmpty)
              _buildContactRow(theme, baseColor, Icons.email, email, () {
                AdManager().loadRewardedInterstitialAd();
                _sendEmail(email, title, category);
              }),
            if (address.isNotEmpty)
              _buildContactRow(
                theme,
                baseColor,
                Icons.map,
                address,
                () => _launchMap(address),
              ),
            if (contactNum.isNotEmpty)
              _buildContactRow(
                theme,
                baseColor,
                Icons.phone,
                contactNum,
                () => _launchCall(contactNum),
              ),
            SizedBox(height: 30),
          ],

          // Apply Button
          GestureDetector(
            onTap: () {
              if (isScrollableSheet) Navigator.pop(context);
              _checkAuthAndApply(data);
            },
            child: NeumorphicContainer(
              color: theme.primaryColor,
              borderRadius: 30,
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  "PROCEED TO APPLY",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );

    if (isScrollableSheet) {
      return ListView(controller: scrollController, children: [content]);
    } else {
      return ListView(children: [content]);
    }
  }

  // --- Detail Section Helper (Unchanged) ---
  Widget _buildDetailSection(
    BuildContext context,
    String title,
    List<dynamic> items, {
    bool isCheck = false,
  }) {
    if (items.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          ...items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isCheck ? Icons.check_circle : Icons.circle,
                        size: isCheck ? 16 : 8,
                        color: isCheck
                            ? Colors.green
                            : Theme.of(context).hintColor,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  // --- Contact Row Helper (Unchanged) ---
  Widget _buildContactRow(
    ThemeData theme,
    Color baseColor,
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: NeumorphicContainer(
          color: baseColor,
          isPressed: false,
          borderRadius: 12,
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: theme.primaryColor, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 12, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }

  // --- Quick Info Helper (Unchanged) ---
  Widget _buildNeuQuickInfo(
    Color baseColor,
    IconData icon,
    String text,
    String label,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      isPressed: true, // Sunken
      borderRadius: 12,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- LOGIC HANDLERS ---
  void _handleOpportunityClick(Map<String, dynamic> data, String docId) {
    if (isLargeScreen(context)) {
      setState(() {
        _selectedOpportunity = data;
        _selectedDocId = docId;
        _isDetailsPanelVisible = true;
      });
    } else {
      _showDetailsBottomSheet(data, docId);
    }
  }

  void _showDetailsBottomSheet(Map<String, dynamic> data, String docId) {
    final theme = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: baseColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _buildDetailsContent(
              data: data,
              docId: docId,
              isScrollableSheet: true,
              scrollController: scrollController,
              onClose: () => Navigator.pop(context),
              baseColor: baseColor,
            );
          },
        );
      },
    );
  }

  // --- Auth & Apply Logic ---
  void _checkAuthAndApply(Map<String, dynamic> data) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginBottomSheet();
    } else {
      _handleApplicationLogic(data);
    }
  }

  void _showLoginBottomSheet() {
    final theme = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: baseColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeumorphicContainer(
                color: baseColor,
                padding: EdgeInsets.all(20),
                child: Icon(Icons.lock_outline, size: 40, color: Colors.orange),
              ),
              SizedBox(height: 20),
              Text(
                "Login Required",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "To apply, you need to be logged in.",
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.hintColor),
              ),
              SizedBox(height: 30),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Login_Page()),
                  );
                },
                child: NeumorphicContainer(
                  color: theme.primaryColor,
                  borderRadius: 30,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                  child: Text(
                    "Login / Register",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleApplicationLogic(Map<String, dynamic> data) async {
    final String webLink = data['link'] ?? '';
    final String email =
        data['application_email'] ?? data['applicationEmail'] ?? '';
    final String title = data['title'] ?? 'Opportunity';
    final String category = data['category'] ?? 'General';
    final Map<String, dynamic> details = data['details'] ?? {};
    final String address = details['address'] ?? '';

    if (email.isNotEmpty || webLink.isNotEmpty) {
      if (email.isNotEmpty && webLink.isNotEmpty) {
        _showDualOptionDialog(webLink, email, title, category);
      } else if (email.isNotEmpty) {
        _sendEmail(email, title, category);
      } else if (webLink.isNotEmpty) {
        _launchWebURL(webLink);
      }
    } else if (address.isNotEmpty) {
      _launchMap(address);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No application method available.')),
      );
    }
  }

  void _showDualOptionDialog(
    String webLink,
    String email,
    String title,
    String category,
  ) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text("Choose Application Method"),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _launchWebURL(webLink);
              },
              child: Text("Apply via Website"),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _sendEmail(email, title, category);
              },
              child: Text("Apply via Email"),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.language, color: Colors.blue),
                title: Text("Apply via Website"),
                onTap: () {
                  Navigator.pop(ctx);
                  _launchWebURL(webLink);
                },
              ),
              ListTile(
                leading: Icon(Icons.email_outlined, color: Colors.orange),
                title: Text("Apply via Email"),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendEmail(email, title, category);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _launchWebURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch website')));
    }
  }

  Future<void> _launchMap(String address) async {
    final Uri url = Uri.parse("geo:0,0?q=${Uri.encodeComponent(address)}");
    if (!await launchUrl(url)) {
      await launchUrl(
        Uri.parse(
          "http://googleusercontent.com/maps.google.com/?q=${Uri.encodeComponent(address)}",
        ),
      );
    }
  }

  Future<void> _launchCall(String number) async {
    final Uri url = Uri.parse("tel:$number");
    if (!await launchUrl(url))
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not launch dialer")));
  }

  Future<void> _sendEmail(
    String email,
    String jobTitle,
    String category,
  ) async {
    User? user = FirebaseAuth.instance.currentUser;
    String userName = "Applicant";
    if (user != null) {
      userName = user.displayName ?? "Applicant";
    }
    String body = _getCategorySpecificBody(category, userName, jobTitle);
    String subject = "Application for ${jobTitle.toUpperCase()} - $userName";
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQueryParameters({'subject': subject, 'body': body}),
    );
    if (!await launchUrl(emailLaunchUri)) {
      if (mounted)
        Api().showMessage(
          context,
          "Could not open email app.",
          "Error",
          Colors.red,
        );
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    // TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    Widget mainContent = Column(
      children: [
        // --- 1. NEUMORPHIC CATEGORY PILLS ---
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            itemCount: _tabs.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 15),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                      _selectedOpportunity = null;
                      _isDetailsPanelVisible = false;
                    });
                  },
                  child: NeumorphicContainer(
                    // Selected: Colored Convex. Unselected: Tinted Convex.
                    color: isSelected ? theme.primaryColor : neumoBaseColor,
                    isPressed: false,
                    borderRadius: 30,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    child: Center(
                      child: Text(
                        _tabs[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : theme.hintColor,
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
        ),

        SizedBox(height: 20),

        // --- 2. LIST CONTENT ---
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _opportunitiesFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(child: Text('Something went wrong.'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: isIOSPlatform
                      ? CupertinoActivityIndicator()
                      : CircularProgressIndicator(),
                );
              }

              final List<dynamic> allDocs = snapshot.data!.where((data) {
                String? expiryStr = data['expiry_date'] ?? data['expiryDate'];
                if (expiryStr == null) return true;
                try {
                  final expiryDate = DateTime.parse(expiryStr);
                  return DateTime.now().isBefore(
                    expiryDate.add(Duration(days: 1)),
                  );
                } catch (e) {
                  return true;
                }
              }).toList();

              final currentTab = _tabs[_selectedIndex];
              final filteredDocs = currentTab == "All"
                  ? allDocs
                  : allDocs.where((data) {
                      return (data['category'] ?? '')
                              .toString()
                              .toLowerCase() ==
                          currentTab.toLowerCase();
                    }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: NeumorphicContainer(
                    color: neumoBaseColor,
                    isPressed: true, // Sunken empty state
                    borderRadius: 20,
                    padding: EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.work_off_outlined,
                          size: 50,
                          color: theme.hintColor.withOpacity(0.5),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "No active opportunities.",
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index] as Map<String, dynamic>;
                  final docId = data['id'].toString(); // Assuming Django ID

                  bool isSelected =
                      isDesktop &&
                      _selectedDocId == docId &&
                      _isDetailsPanelVisible;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: _buildNeumorphicCard(
                      data,
                      docId,
                      isSelected,
                      theme,
                      neumoBaseColor,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: mainContent),
                  if (_isDetailsPanelVisible && _selectedOpportunity != null)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: NeumorphicContainer(
                          color: neumoBaseColor,
                          borderRadius: 20,
                          child: _buildDetailsContent(
                            data: _selectedOpportunity!,
                            docId: _selectedDocId!,
                            isScrollableSheet: false,
                            onClose: () => setState(() {
                              _isDetailsPanelVisible = false;
                              _selectedOpportunity = null;
                            }),
                            baseColor: neumoBaseColor,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : mainContent,
      ),
    );
  }

  // --- ⭐️ NEUMORPHIC CARD BUILDER (Updated Mapping) ---
  Widget _buildNeumorphicCard(
    Map<String, dynamic> data,
    String docId,
    bool isSelected,
    ThemeData theme,
    Color baseColor,
  ) {
    String title = data['title'] ?? 'Untitled';
    String category = data['category'] ?? 'General';
    // Handle Django snake_case or legacy
    String imageUrl = data['image_url'] ?? data['imageUrl'] ?? '';

    String formattedDate = 'Open';
    String? expiryStr = data['expiry_date'] ?? data['expiryDate'];
    if (expiryStr != null) {
      try {
        DateTime dt = DateTime.parse(expiryStr);
        formattedDate = DateFormat('dd MMM').format(dt);
      } catch (e) {
        /* ignore */
      }
    }

    return GestureDetector(
      onTap: () {
        AdManager().loadRewardedInterstitialAd();
        _handleOpportunityClick(data, docId);
      },
      child: NeumorphicContainer(
        color: isSelected ? theme.primaryColor.withOpacity(0.05) : baseColor,
        isPressed: false, // Convex Card
        borderRadius: 20,
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE FRAME
            NeumorphicContainer(
              color: baseColor,
              borderRadius: 15,
              padding: EdgeInsets.all(4), // Frame
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 90,
                  height: 90,
                  color: Colors.white,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Image.asset(
                            "assets/dankie_logo.PNG",
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          "assets/dankie_logo.PNG",
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            SizedBox(width: 15),

            // CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NeumorphicContainer(
                        color: baseColor,
                        isPressed: true, // Sunken Category Tag
                        borderRadius: 6,
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                      if (expiryStr != null)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Exp: $formattedDate",
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.2,
                      color: theme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12),

                  // APPLY BUTTON (Small Neumorphic)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NeumorphicContainer(
                        color: theme.primaryColor,
                        borderRadius: 10,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          "Details",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}