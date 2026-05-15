// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/HomePageHelpers.dart';
import 'package:ttact/Components/NotificationService.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/Tabs/apostles_greetings.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/Tabs/branches_tab.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/Tabs/career_opportunities.dart'
    hide isLargeScreen;
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/Tabs/events_tab.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/Tabs/music_tab.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/main_menu.dart' hide isLargeScreen;

// ⭐️ IMPORT YOUR NEUMORPHIC UTILS
import 'package:ttact/Components/NeumorphicUtils.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/home/Tabs/find_nearby_branch.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0; // Tracks active tab for styling
  AdManager adManager = AdManager();
  final GlobalKey<MusicTabState> _musicTabKey = GlobalKey<MusicTabState>();

  void _onDeepLinkReceived() async {
    const int musicTabIndex = 1;
    final songUrlId = MotherPage.deepLinkSongIdNotifier.value;
    if (songUrlId == null) return;

    if (_tabController.index != musicTabIndex) {
      _tabController.animateTo(musicTabIndex);
      setState(() => _currentIndex = musicTabIndex);
      await Future.delayed(Duration(milliseconds: 500));
    }
    MotherPage.deepLinkSongIdNotifier.value = null;
    if (_musicTabKey.currentState != null) {
      _musicTabKey.currentState!.playDeepLinkedSong(songUrlId);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
 
    _tabController.addListener(() {
      if (_tabController.index != _currentIndex) {
        setState(() => _currentIndex = _tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      MotherPage.deepLinkSongIdNotifier.addListener(_onDeepLinkReceived);
      if (MotherPage.deepLinkSongIdNotifier.value != null) {
        Future.delayed(Duration(milliseconds: 1000), _onDeepLinkReceived);
      }
    });

    adManager.loadRewardedInterstitialAd();
    NotificationService.scheduleDailyVerses();
  }

  @override
  void dispose() {
    MotherPage.deepLinkSongIdNotifier.removeListener(_onDeepLinkReceived);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: baseColor,
      body: Column(
        children: [
          // ⭐️ PREMIUM SCROLLABLE TAB BAR
          // We removed the Center/ConstrainedBox here to allow full-width scrolling
          _buildPremiumTabSwitcher(theme, baseColor),

          // ⭐️ CLEAN CONTENT AREA
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _simpleWrapper(child: EventsTab()),
                _simpleWrapper(child: FindNearbyBranch()),
                _simpleWrapper(
                  child: MusicTab(
                    key: _musicTabKey,
                    isDesktop: isLargeScreen(context),
                  ),
                ),
                _simpleWrapper(
                  child: BranchesTab(isDesktop: isLargeScreen(context)),
                ),
                _simpleWrapper(child: CareerOpportunities()),
                _simpleWrapper(child: ApostlesGreetings()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Simple wrapper to center content on web
  Widget _simpleWrapper({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: child,
        ),
      ),
    );
  }

  // ⭐️ THE ADVANCED SCROLLABLE TAB BAR ⭐️
  Widget _buildPremiumTabSwitcher(ThemeData theme, Color baseColor) {
    final tabs = [
      {'icon': Ionicons.calendar_outline, 'label': 'EVENTS'},
      {'icon': Icons.near_me_outlined, 'label': 'FIND NEARBY'},
      {'icon': Ionicons.musical_notes_outline, 'label': 'MUSIC'},
      {'icon': Ionicons.business_outline, 'label': 'BRANCHES'},
      {'icon': Ionicons.briefcase_outline, 'label': 'CAREER'},
      {'icon': Icons.message_outlined, 'label': 'APOSTLES GREETINGS'},
    ];

    // Increased height to accommodate the card size + shadows
    return Container(
      height: 70,
      width: double.infinity,
      // No margin here so scrolling hits the edges
      child: ListView.separated(
        // ⭐️ Padding inside list ensures shadows aren't clipped
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const ScrollPhysics(),
        itemCount: tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 15),
        itemBuilder: (context, index) {
          final isSelected = _currentIndex == index;
          // Get distinct color per card
          final accentColor = NeumorphicUtils.getAccentColor(index);

          return GestureDetector(
            onTap: () {
              setState(() => _currentIndex = index);
              _tabController.animateTo(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130, // ⭐️ Fixed width ensures perfect shape & no overflow
              decoration: NeumorphicUtils.decoration(
                context: context,
                radius: 18,
                isPressed: isSelected, // Pressed IN when selected
                isDark: theme.brightness == Brightness.dark,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ⭐️ VERTICAL ACCENT LINE (Thicker & Gradient)
                        Container(
                          width: 8,
                          decoration: BoxDecoration(
                            color: accentColor,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accentColor,
                                accentColor.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),

                        // TAB CONTENT
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tabs[index]['icon'] as IconData,
                                color: isSelected
                                    ? theme.primaryColor
                                    : theme.hintColor,
                                size: 32, // Large, clear icon
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tabs[index]['label'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? theme.primaryColor
                                      : theme.hintColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Optional: Subtle active indicator dot on top right
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
