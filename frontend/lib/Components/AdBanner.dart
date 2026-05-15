// // AdBanner.dart
// REMOVED: import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// NEW: Import foundation for kIsWeb and defaultTargetPlatform checks
import 'package:flutter/foundation.dart';

typedef OnAdFailedCallback = void Function();

// --- PLATFORM UTILITY ---
// Checks if the current environment is Android (non-web)
bool get isAndroidPlatform => 
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
// ------------------------

class AdManager {
  // Initialization of the singleton instance is safe, but the fields below 
  // must use platform-safe checks.
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  // --- PLATFORM-SAFE AD UNIT ID DEFINITIONS ---

  /// Ad Unit IDs (replace with your real ones when live)
  // FIX: Use isAndroidPlatform check instead of Platform.isAndroid
  final String _bannerAdUnitId = isAndroidPlatform
      ? 'ca-app-pub-6759693957212853/4627097298' // Android Ad Unit
      : 'ca-app-pub-3940256099942544/6300978111'; // iOS/Other Ad Unit (Test Ad Unit)

  // FIX: Use isAndroidPlatform check instead of Platform.isAndroid
  final String _interstitialAdUnitId = isAndroidPlatform
      ? 'ca-app-pub-6759693957212853/8015639971'
      : 'ca-app-pub-3940256099942544/1033173712';

  // FIX: Use isAndroidPlatform check instead of Platform.isAndroid
  final String _rewardedInterstitialAdUnitId = isAndroidPlatform
      ? 'ca-app-pub-6759693957212853/4756966871'
      : 'ca-app-pub-3940256099942544/5354046340';
  
  // --- END AD UNIT ID DEFINITIONS ---

  InterstitialAd? _interstitialAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isInterstitialAdLoaded = false;
  bool _isRewardedInterstitialAdLoaded = false;

  /// Call this early (e.g., in main.dart)
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // IMPORTANT: Only initialize MobileAds if NOT on Web, as it's typically not supported
    // or requires a different integration approach (which MobileAds.instance.initialize() doesn't cover).
    if (!kIsWeb) {
      await MobileAds.instance.initialize();
      AdManager().loadInterstitialAd();
      AdManager().loadRewardedInterstitialAd();
    } else {
        debugPrint("AdManager: Mobile Ads initialization skipped on Web platform.");
    }
  }

  /// ============== INTERSTITIAL ==============
  void loadInterstitialAd() {
    if (kIsWeb) return; // Skip ad loading on Web
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _setInterstitialFullScreenContentCallback();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  void _setInterstitialFullScreenContentCallback() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isInterstitialAdLoaded = false;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isInterstitialAdLoaded = false;
        loadInterstitialAd();
      },
    );
  }

  void showInterstitialAd() {
    if (kIsWeb) return; // Skip ad showing on Web
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      loadInterstitialAd();
    }
  }

  /// ============== REWARDED INTERSTITIAL ==============
  void loadRewardedInterstitialAd({OnAdFailedCallback? onAdFailed}) {
    if (kIsWeb) return; // Skip ad loading on Web
    RewardedInterstitialAd.load(
      adUnitId: _rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdLoaded = true;
          _setRewardedInterstitialFullScreenContentCallback();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isRewardedInterstitialAdLoaded = false;
          if (onAdFailed != null) onAdFailed();
        },
      ),
    );
  }

  void _setRewardedInterstitialFullScreenContentCallback() {
    _rewardedInterstitialAd?.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedInterstitialAdLoaded = false;
        loadRewardedInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isRewardedInterstitialAdLoaded = false;
        loadRewardedInterstitialAd();
      },
    );
  }

  void showRewardedInterstitialAd(
    OnUserEarnedRewardCallback onReward, {
    OnAdFailedCallback? onAdFailed,
  }) {
    if (kIsWeb) {
        if (onAdFailed != null) onAdFailed(); // Gracefully fail on web
        return;
    } 
    
    if (_isRewardedInterstitialAdLoaded && _rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.show(onUserEarnedReward: onReward);
    } else {
      // The ad is not loaded, but we still trigger the onAdFailed callback
      if (onAdFailed != null) onAdFailed();
      // Start loading a new ad for the next time.
      loadRewardedInterstitialAd();
    }
  }

  /// Banner helper
  // NOTE: This widget will return SizedBox.shrink() on web because 
  // _BannerAdWidget will never load the ad unit on a non-mobile environment.
  Widget bannerAdWidget() {
    // Return a placeholder or skip entirely if definitely on web/desktop
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
        return const SizedBox.shrink(); 
    }
    return _BannerAdWidget(adUnitId: _bannerAdUnitId);
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedInterstitialAd?.dispose();
  }
}

/// ============== BANNER WIDGET ==============
class _BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  const _BannerAdWidget({required this.adUnitId});

  @override
  State<_BannerAdWidget> createState() => __BannerAdWidgetState();
}

class __BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Safety check: Only attempt to load the ad if it's a mobile platform
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: widget.adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );
    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}