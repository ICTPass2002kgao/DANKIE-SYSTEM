// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ttact/Components/NotificationService.dart';
import 'package:ttact/Pages/initial_road_wrapper.dart';
import 'package:ttact/Pages/Overseer/overseer_page.dart';
import 'package:ttact/Pages/tactso_pages/tactso_branch_main_menu.dart';
import 'package:ttact/firebase_options.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Audio_Handler.dart';
import 'package:ttact/Pages/Admin/admin_portal.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/cart.dart';
import 'package:ttact/Pages/Auth/sign_in.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/main_menu.dart';
import 'package:ttact/Pages/Auth/sign_up.dart';
import 'package:ttact/Pages/User/Seller/seller_main.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/orders.dart';
import 'package:ttact/introduction_page.dart';

MyAudioHandler? audioHandler;

/// Checks Bluetooth permissions required by WebRTC / LiveKit for wireless headsets
Future<void> _checkLiveKitPermissions() async {
  if (!kIsWeb) {
    try {
      final bluetoothStatus = await Permission.bluetooth.request();
      if (bluetoothStatus.isPermanentlyDenied) {
        print("🔴 Bluetooth Permission permanently denied");
      }

      final connectStatus = await Permission.bluetoothConnect.request();
      if (connectStatus.isPermanentlyDenied) {
        print("🔴 Bluetooth Connect Permission permanently denied");
      }
    } catch (e) {
      print("🔴 LiveKit Permission Error: $e");
    }
  }
}

Future<void> main() async { 
  runZonedGuarded<Future<void>>(
    () async {
      print("🟢 1. Starting initialization...");
      WidgetsFlutterBinding.ensureInitialized();

      print("🟢 2. Initializing timezones...");
      try {
        tz.initializeTimeZones();
      } catch (e) {
        print("🔴 Timezone error: $e");
      }

      print("🟢 3. Initializing Firebase...");
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 10));
        print("🟢 Firebase Success");
      } catch (e) {
        print("🔴 Firebase Init Error / Timeout: $e");
      }

      FlutterError.onError = (FlutterErrorDetails details) {
        print("🔴 FLUTTER UI ERROR: ${details.exception}");
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      print("🟢 4. Initializing Notifications...");
      try {
        NotificationService.init().then((_) {
          NotificationService.scheduleDailyVerses();
        });
      } catch (e) {
        print("🔴 Notification Error: $e");
      }

      print("🟢 5. Initializing Audio Session...");
      try {
        AudioSession.instance.then((session) async {
          await session.configure(const AudioSessionConfiguration.music());
        });
      } catch (e) {
        print("🔴 Audio Session failed: $e");
      }

      print("🟢 6. Checking LiveKit / Bluetooth Permissions...");
      await _checkLiveKitPermissions();

      print("🟢 7. Initializing Ads...");
      if (!kIsWeb) {
        try {
          MobileAds.instance.initialize();
          AdManager.initialize();
        } catch (e) {
          print("🔴 MobileAds initialization failed: $e");
        }
      }

      print("🟢 8. Initializing AudioService...");
      try {
        audioHandler = await AudioService.init(
          builder: () => MyAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.thetact.ttact.channel.audio',
            androidNotificationChannelName: 'TACT Music',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
            androidNotificationIcon: 'drawable/ic_notification',
          ),
        ).timeout(const Duration(seconds: 5));
      } catch (e, stackTrace) {
        print("🔴 Audio Service failed: $e");
      }

      print("🟢 9. Executing runApp()...");
      runApp(const MyApp());
    },  (error, stackTrace) { 
      print("🔥🔥🔥 FATAL ZONE ERROR CAUSING BLACK SCREEN: $error");
      print(stackTrace);
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoadingTheme = true;
  bool _showWebBanner = kIsWeb;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        final isDarkMode = prefs.getBool('isDarkMode') ?? false;
        _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
        _isLoadingTheme = false;
      });
    } catch (e) {
      print("🔴 Theme load error: $e");
      setState(() => _isLoadingTheme = false);
    }
  }

  void toggleTheme(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print("Could not launch $url");
    }
  }

  // --- RESPONSIVE WEB BANNER ---
  Widget _buildWebBanner() {
    if (!_showWebBanner) return const SizedBox.shrink();
    
    return Material(
      color: Colors.blue.shade900,
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isSmallScreen = constraints.maxWidth < 800;

            if (isSmallScreen) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.phone_android, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "For the best experience, download our official mobile applications:",
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _showWebBanner = false),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => _launchUrl('https://play.google.com/store/apps/details?id=com.thetact.ttact&pli=1'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, 
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                          ),
                          child: const Text("Android", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        ElevatedButton(
                          onPressed: () => _launchUrl('https://apps.apple.com/za/app/dankie-mobile/id6767526580'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black, 
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                          ),
                          child: const Text("iOS", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        ElevatedButton(
                          onPressed: () => _launchUrl('https://appgallery.huawei.com/app/C115359927'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, 
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                          ),
                          child: const Text("Huawei", style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_android, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "For the best experience, download our official mobile applications:",
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _launchUrl('https://play.google.com/store/apps/details?id=com.thetact.ttact&pli=1'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text("Android", style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: () => _launchUrl('https://apps.apple.com/za/app/dankie-mobile/id6767526580'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                        child: const Text("iOS", style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: () => _launchUrl('https://appgallery.huawei.com/app/C115359927'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("Huawei", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() => _showWebBanner = false),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTheme) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return Column(
            children: [
              if (kIsWeb) _buildWebBanner(),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          );
        },
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Loading App...", style: TextStyle(color: Colors.black)),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    FlutterQuillLocalizations.delegate, // <--- This fixes the crash
  ],
  supportedLocales: const [
    Locale('en', 'US'),
  ],
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      builder: (context, child) {
        return Column(
          children: [
            if (kIsWeb) _buildWebBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      theme: ThemeData(
        cardColor: Colors.black,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Color.fromARGB(255, 255, 255, 255),
        ),
        hintColor: const Color.fromARGB(255, 185, 182, 182),
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        splashColor: const Color.fromARGB(255, 33, 98, 35),
        primaryColorDark: const Color.fromARGB(255, 170, 42, 33),
        primaryColorLight: Colors.purple,
      ),
      darkTheme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        cardColor: Colors.white,
        hintColor: const Color.fromARGB(255, 255, 255, 255),
        primaryColor: Colors.blue,
        brightness: Brightness.dark,
        splashColor: const Color.fromARGB(255, 33, 98, 35),
        primaryColorDark: const Color.fromARGB(255, 170, 42, 33),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color.fromARGB(255, 0, 0, 0),
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 4, 36, 77),
      ),
      home: const InitialRouteWrapper(),
      routes: {
        '/tact_seller': (context) => SellerProductPage(),
        '/main-menu': (context) => MotherPage(onToggleTheme: toggleTheme),
        '/signup': (context) => SignUpPage(),
        '/cart': (context) => CartPage(),
        '/orders': (context) => OrdersPage(),
        '/admin': (context) => AdminPortal(),
        '/login': (context) => Login_Page(),
        '/overseer': (context) => OverseerPage(),
        '/tactso-branches': (context) => TactsoBranchesApplications(),
        '/introduction': (context) => Introductionpage(
          onGetStarted: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('hasSeenIntro', true);
          },
        ),
      },
    );
  }
}