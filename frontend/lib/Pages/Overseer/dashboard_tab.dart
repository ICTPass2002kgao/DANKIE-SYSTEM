// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class DashboardTab extends StatefulWidget {
  final bool isLargeScreen;
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;

  const DashboardTab({
    super.key,
    required this.isLargeScreen,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    required this.faceUrl,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

// ⭐️ ADDED WidgetsBindingObserver to detect when user returns from Paystack browser
class _DashboardTabState extends State<DashboardTab>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // --- CHART DATA STATE ---
  List<BarChartGroupData> _monthlyOfferingsData = [];
  Map<String, double> _districtTotals = {};
  double _maxOfferingAmount = 100.0;

  Map<String, int> _districtMemberCounts = {};
  int _totalMemberCountForChart = 0;

  Map<int, double> _weeklyTotals = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
  double _maxWeeklyTithe = 100.0;

  // --- EVENT ALERT STATE ---
  Map<String, dynamic>? _nearestEvent;
  bool _isLoadingEvent = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Color> _pieColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    // ⭐️ Register the observer
    WidgetsBinding.instance.addObserver(this);

    _loadDashboardData();
    _loadNearestEvent();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // ⭐️ Remove the observer
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  // ⭐️ AUTO REFRESH: When user returns from Paystack browser, refresh the alert!
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNearestEvent();
    }
  }

  // --- FETCH NEAREST (UNPAID) EVENT ---
  Future<void> _loadNearestEvent() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();
      final uid = user.uid;

      // 1. Fetch all events
      final eventsResponse = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/event_diary/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // 2. Fetch the overseer's contributions
      final contribResponse = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/event_contributions/?overseer_uid=$uid',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (eventsResponse.statusCode == 200 &&
          contribResponse.statusCode == 200) {
        List<dynamic> events = json.decode(eventsResponse.body);
        List<dynamic> contributions = json.decode(contribResponse.body);

        // 3. Build a set of Event IDs that the overseer has ALREADY PAID for
        Set<String> paidEventIds = {};
        for (var c in contributions) {
          if (c['has_contributed'] == true) {
            paidEventIds.add(c['event'].toString());
          }
        }

        final now = DateTime.now();
        Map<String, dynamic>? closestEvent;
        DateTime? closestDate;

        for (var event in events) {
          String eventId = event['id'].toString();

          // ⭐️ MAGIC FIX: Skip this event if they already paid for it!
          if (paidEventIds.contains(eventId)) continue;

          final eventDate = _parseEventDate(event);
          if (eventDate != null && eventDate.isAfter(now)) {
            if (closestDate == null || eventDate.isBefore(closestDate)) {
              closestDate = eventDate;
              closestEvent = event;
            }
          }
        }

        if (mounted) {
          setState(() {
            _nearestEvent = closestEvent;
            _isLoadingEvent = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingEvent = false);
      }
    } catch (e) {
      print("Error loading events: $e");
      if (mounted) setState(() => _isLoadingEvent = false);
    }
  }

  DateTime? _parseEventDate(Map<String, dynamic> event) {
    final now = DateTime.now();
    final year = event['year'] ?? now.year;
    String? day = event['day']?.toString();
    String? month = event['month']?.toString();

    if (day == null || day.toLowerCase().contains('communicated')) return null;

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

  // --- HANDLE PAYMENT & CONTRIBUTION LOGGING ---
  Future<void> _processContribution(double amount, String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await user.getIdToken();
    final uniqueRef =
        "EVT_${eventId.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}";
    final userEmail = user.email ?? "admin@dankie.co.za";

    try {
      // Fetch Overseer ID first
      String? overseerId;
      final profileResp = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=$userEmail',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (profileResp.statusCode == 200) {
        final List data = json.decode(profileResp.body);
        if (data.isNotEmpty) overseerId = data[0]['id'];
      }

      if (overseerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error identifying your profile.")),
        );
        return;
      }

      final payResponse = await http.post(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/create-payment-link/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "email": userEmail,
          "orderReference": uniqueRef,
          "contribution_type": "event_contribution",
          "event_id": eventId,
          "overseer_id": overseerId,
          "products": [
            {
              "price": amount,
              "quantity": 1,
              "subaccount": "ACCT_hvj7wvps74catuq",
            },
          ],
        }),
      );

      final responseData = json.decode(payResponse.body);

      if (payResponse.statusCode == 200 || payResponse.statusCode == 201) {
        final paymentUrl = responseData['paymentLink'];

        // Log a "Pending" attempt locally
        await http.post(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/event_contributions/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({
            "event": eventId,
            "overseer": overseerId,
            "amount": amount,
            "has_contributed": false, // Pending until webhook confirms
            "remarks": "Payment Initiated (Pending)",
          }),
        );

        if (await canLaunchUrl(Uri.parse(paymentUrl))) {
          await launchUrl(
            Uri.parse(paymentUrl),
            mode: LaunchMode.externalApplication,
          );
          // Once they return from the browser, didChangeAppLifecycleState will trigger!
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not launch secure payment gateway.")),
          );
        }
      } else {
        final errorMsg = responseData['error'] ?? 'Initialization failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Payment Failed: $errorMsg"),
            backgroundColor: Colors.red.shade800,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("Payment Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("A critical network error occurred.")),
      );
    }
  }

  void _showContributionDialog(
    BuildContext context,
    Map<String, dynamic> event,
  ) {
    final TextEditingController amountController = TextEditingController();
    final theme = Theme.of(context);
    final neumoBase = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: NeumorphicContainer(
            color: neumoBase,
            borderRadius: 20,
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.volunteer_activism_rounded,
                  size: 50,
                  color: theme.primaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  "Support Your District",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.primaryColor,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Lead by example. Fund the ${event['title']} to ensure your district is proudly represented in the Annual Report.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 24),
                NeumorphicContainer(
                  isPressed: true,
                  borderRadius: 12,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter Amount (Min R50.00)",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        "Later",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final amount = double.tryParse(amountController.text);
                        if (amount != null && amount >= 50.0) {
                          Navigator.pop(ctx);
                          _processContribution(amount, event['id']);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Amount must be at least R50.00 to process.",
                              ),
                              backgroundColor: Colors.red[800],
                            ),
                          );
                        }
                      },
                      child: NeumorphicContainer(
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        color: theme.primaryColor,
                        child: Text(
                          "PROCEED TO PAYMENT",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- EXISTING DASHBOARD FETCH LOGIC ---
  Future<void> _loadDashboardData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$uid',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) return;

      final List<dynamic> users = json.decode(response.body);

      Map<String, double> districtTitheTotals = {};
      Map<String, int> districtMemberCounts = {};
      Map<int, double> weeklyTitheTotals = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
      double maxTitheTotal = 0.0;
      int totalMembers = 0;

      for (var data in users) {
        totalMembers++;
        final districtName =
            data['district_elder_name'] ??
            data['districtElderName'] ??
            'Unassigned';

        final w1 = double.tryParse(data['week1']?.toString() ?? '0') ?? 0.0;
        final w2 = double.tryParse(data['week2']?.toString() ?? '0') ?? 0.0;
        final w3 = double.tryParse(data['week3']?.toString() ?? '0') ?? 0.0;
        final w4 = double.tryParse(data['week4']?.toString() ?? '0') ?? 0.0;

        final monthlyTotal = w1 + w2 + w3 + w4;

        districtTitheTotals.update(
          districtName,
          (v) => v + monthlyTotal,
          ifAbsent: () => monthlyTotal,
        );
        districtMemberCounts.update(
          districtName,
          (v) => v + 1,
          ifAbsent: () => 1,
        );

        weeklyTitheTotals[1] = (weeklyTitheTotals[1] ?? 0) + w1;
        weeklyTitheTotals[2] = (weeklyTitheTotals[2] ?? 0) + w2;
        weeklyTitheTotals[3] = (weeklyTitheTotals[3] ?? 0) + w3;
        weeklyTitheTotals[4] = (weeklyTitheTotals[4] ?? 0) + w4;
      }

      List<BarChartGroupData> chartGroups = [];
      int index = 0;
      districtTitheTotals.forEach((district, total) {
        chartGroups.add(
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: total,
                color: Theme.of(context).primaryColor,
                width: 15,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            showingTooltipIndicators: [0],
          ),
        );
        if (total > maxTitheTotal) maxTitheTotal = total;
        index++;
      });

      double maxWeekly = weeklyTitheTotals.values.reduce(
        (curr, next) => curr > next ? curr : next,
      );

      if (mounted) {
        setState(() {
          _monthlyOfferingsData = chartGroups;
          _districtTotals = districtTitheTotals;
          _maxOfferingAmount = maxTitheTotal > 0 ? maxTitheTotal * 1.2 : 100.0;
          _districtMemberCounts = districtMemberCounts;
          _totalMemberCountForChart = totalMembers;
          _weeklyTotals = weeklyTitheTotals;
          _maxWeeklyTithe = maxWeekly > 0 ? maxWeekly * 1.2 : 100.0;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    }
  }

  Future<int> _getTotalOverseerMemberCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$uid',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return (json.decode(response.body) as List).length;
      }
    } catch (e) {
      print(e);
    }
    return 0;
  }

  Future<int> _getTotalOverseerDistrictCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final profileUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${FirebaseAuth.instance.currentUser?.email}',
      );
      final profileResp = await http.get(profileUrl);
      if (profileResp.statusCode == 200) {
        final List data = json.decode(profileResp.body);
        if (data.isNotEmpty) {
          final overseerId = data[0]['id'];
          final distUrl = Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/districts/?overseer=$overseerId',
          );
          final distResp = await http.get(distUrl);
          if (distResp.statusCode == 200) {
            return (json.decode(distResp.body) as List).length;
          }
        }
      }
    } catch (e) {
      print(e);
    }
    return 0;
  }

  Future<int> _getTotalOverseerBranchCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final profileUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${FirebaseAuth.instance.currentUser?.email}',
      );
      final profileResp = await http.get(profileUrl);
      if (profileResp.statusCode == 200) {
        final List data = json.decode(profileResp.body);
        if (data.isNotEmpty) {
          final overseerId = data[0]['id'];
          final commUrl = Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/communities/?district__overseer=$overseerId',
          );
          final commResp = await http.get(commUrl);
          if (commResp.statusCode == 200) {
            return (json.decode(commResp.body) as List).length;
          }
        }
      }
    } catch (e) {
      print(e);
    }
    return 0;
  }

  final Color _primaryColor = const Color(0xFF1E3A8A);
  final Color _accentColor = const Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NEUMORPHIC HEADER
            NeumorphicContainer(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _accentColor],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child:
                            widget.faceUrl != null && widget.faceUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: Image.network(
                                  widget.faceUrl!,
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Welcome Back,",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            widget.committeeMemberName != null
                                ? "${widget.committeeMemberName}\n(${widget.committeeMemberRole})"
                                : " Overseer",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- ⭐️ ELEGANT NEAREST EVENT ALERT BANNER ---
            if (!_isLoadingEvent && _nearestEvent != null)
              ScaleTransition(
                scale: _pulseAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.15),
                          blurRadius: 15,
                          offset: Offset(5, 5),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 15,
                          offset: Offset(-5, -5),
                        ),
                      ],
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              color: Colors.amber[700],
                              size: 30,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "PRIORITY REMINDER",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          _nearestEvent!['title'] ?? 'Unknown Event',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: theme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Scheduled: ${_nearestEvent!['day']} ${_nearestEvent!['month'] ?? ''} ${_nearestEvent!['year']}",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            "Your contribution secures your district's standing in the Annual Report. Lead by example and support this event today.",
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => _showContributionDialog(
                              context,
                              _nearestEvent!,
                            ),
                            child: NeumorphicContainer(
                              color: theme.primaryColor,
                              borderRadius: 12,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "CONTRIBUTE NOW",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Text(
              "Overview",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 20),

            // 1. STAT CARDS (Responsive Wrap)
            LayoutBuilder(
              builder: (ctx, constraints) {
                int crossAxisCount = widget.isLargeScreen
                    ? 3
                    : (constraints.maxWidth > 600 ? 2 : 1);
                double cardWidth =
                    (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                    crossAxisCount;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard(
                      "Total Members",
                      Icons.group,
                      Colors.blue,
                      theme.primaryColorLight,
                      _getTotalOverseerMemberCount,
                      width: cardWidth,
                    ),
                    _buildStatCard(
                      "Total Districts",
                      Icons.map,
                      Colors.orange,
                      theme.splashColor,
                      _getTotalOverseerDistrictCount,
                      width: cardWidth,
                    ),
                    _buildStatCard(
                      "Total Branches",
                      Icons.location_city,
                      Colors.red,
                      theme.primaryColorDark,
                      _getTotalOverseerBranchCount,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // 2. CHARTS (Bar + Pie)
            widget.isLargeScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTitheBarChart(context)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildMemberPieChart(context)),
                    ],
                  )
                : Column(
                    children: [
                      _buildTitheBarChart(context),
                      const SizedBox(height: 20),
                      _buildMemberPieChart(context),
                    ],
                  ),

            const SizedBox(height: 20),

            // 3. WEEKLY TREND LINE CHART
            _buildWeeklyTitheLineChart(context),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildStatCard(
    String title,
    IconData icon,
    Color iconColor,
    Color cardColor,
    Future<int> Function() future, {
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: FutureBuilder<int>(
        future: future(),
        builder: (context, snapshot) {
          return NeumorphicContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                NeumorphicContainer(
                  isPressed: true,
                  borderRadius: 50,
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    snapshot.connectionState == ConnectionState.waiting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: iconColor,
                            ),
                          )
                        : Text(
                            "${snapshot.data ?? 0}",
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- CHART BUILDERS ---

  Widget _buildTitheBarChart(BuildContext context) {
    final isWeb = kIsWeb;
    final districtNames = _districtTotals.keys.toList();

    if (_monthlyOfferingsData.isEmpty) {
      return _buildChartPlaceholder(context, 'Tithe Offerings by District');
    }

    return NeumorphicContainer(
      padding: const EdgeInsets.all(20.0),
      borderRadius: 16,
      child: SizedBox(
        height: isWeb ? 350 : 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Monthly Tithe (R)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxOfferingAmount,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String districtName = districtNames[group.x.toInt()];
                        return BarTooltipItem(
                          '$districtName\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: 'R${rod.toY.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < districtNames.length) {
                            String name = districtNames[index];
                            String initials = name
                                .split(' ')
                                .map(
                                  (e) => e.isNotEmpty ? e.substring(0, 1) : '',
                                )
                                .join();
                            return SideTitleWidget(
                              meta: meta,
                              space: 4.0,
                              child: Text(
                                initials,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _maxOfferingAmount / 5,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'R${value.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _monthlyOfferingsData,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                ),
              ),
            ),
            if (districtNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: Text(
                    'Key: ${districtNames.asMap().entries.map((e) => '${e.value.split(' ').map((s) => s.isNotEmpty ? s.substring(0, 1) : '').join()}=${e.value}').join(', ')}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberPieChart(BuildContext context) {
    final color = Theme.of(context);
    final isWeb = kIsWeb;

    if (_districtMemberCounts.isEmpty) {
      return _buildChartPlaceholder(context, 'Member Distribution by District');
    }

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    _districtMemberCounts.forEach((district, count) {
      final double percentage = _totalMemberCountForChart > 0
          ? (count / _totalMemberCountForChart) * 100
          : 0;
      sections.add(
        PieChartSectionData(
          color: _pieColors[colorIndex % _pieColors.length],
          value: count.toDouble(),
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 90.0,
          titleStyle: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: color.scaffoldBackgroundColor,
            shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
          ),
        ),
      );
      colorIndex++;
    });

    return NeumorphicContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: SizedBox(
        height: isWeb ? 350 : 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: sections,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ListView(
                      children: _districtMemberCounts.keys
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                            int index = entry.key;
                            String district = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color:
                                          _pieColors[index % _pieColors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '$district (${_districtMemberCounts[district]})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
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

  Widget _buildWeeklyTitheLineChart(BuildContext context) {
    final color = Theme.of(context);
    final isWeb = kIsWeb;

    if (_weeklyTotals.values.every((v) => v == 0.0)) {
      return _buildChartPlaceholder(context, 'Weekly Tithe Trend');
    }

    final List<FlSpot> spots = [
      FlSpot(1, _weeklyTotals[1] ?? 0.0),
      FlSpot(2, _weeklyTotals[2] ?? 0.0),
      FlSpot(3, _weeklyTotals[3] ?? 0.0),
      FlSpot(4, _weeklyTotals[4] ?? 0.0),
    ];

    return NeumorphicContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: SizedBox(
        height: isWeb ? 350 : 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Tithe Trend (All Districts)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 18.0, top: 10.0),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: _maxWeeklyTithe / 4,
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            String text = '';
                            switch (value.toInt()) {
                              case 1:
                                text = 'Week 1';
                                break;
                              case 2:
                                text = 'Week 2';
                                break;
                              case 3:
                                text = 'Week 3';
                                break;
                              case 4:
                                text = 'Week 4';
                                break;
                            }
                            return SideTitleWidget(
                              meta: meta,
                              space: 8.0,
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _maxWeeklyTithe / 4,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              'R${value.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 1,
                    maxX: 4,
                    minY: 0,
                    maxY: _maxWeeklyTithe,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [color.primaryColor, color.splashColor],
                        ),
                        barWidth: 5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              color.primaryColor.withOpacity(0.2),
                              color.splashColor.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartPlaceholder(BuildContext context, String title) {
    return NeumorphicContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: SizedBox(
        height: kIsWeb ? 350 : 250,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: NeumorphicContainer(
                  isPressed: true,
                  borderRadius: 12,
                  child: Center(
                    child: Text(
                      'Loading Data Visualization or No Data Available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
