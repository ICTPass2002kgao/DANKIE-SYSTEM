import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Ensure this path matches where you saved the code above
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/Auth/sign_in.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// --- FEATURE ICON COMPONENT ---
class NeumorphicFeatureIcon extends StatefulWidget {
  final IconData iconData;
  final String label;
  final Duration delay;

  const NeumorphicFeatureIcon({
    super.key,
    required this.iconData,
    required this.label,
    required this.delay,
  });

  @override
  State<NeumorphicFeatureIcon> createState() => _NeumorphicFeatureIconState();
}

class _NeumorphicFeatureIconState extends State<NeumorphicFeatureIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _pulseController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: NeumorphicContainer(
              color: NeuTheme.background,

              borderRadius: 50, // Circle
              padding: const EdgeInsets.all(16),
              child: Icon(widget.iconData, size: 26, color: NeuTheme.accent),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: NeuTheme.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// --- MAIN PAGE ---
class Introductionpage extends StatefulWidget {
  final VoidCallback onGetStarted;

  const Introductionpage({super.key, required this.onGetStarted});

  @override
  State<Introductionpage> createState() => _IntroductionpageState();
}

class _IntroductionpageState extends State<Introductionpage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _contentAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> features = [
    {'icon': Icons.headphones, 'label': 'Listen', 'delay': Duration.zero},
    {
      'icon': Icons.school,
      'label': 'Learn',
      'delay': const Duration(milliseconds: 200),
    },
    {
      'icon': Icons.near_me_outlined,
      'label': 'Find church',
      'delay': const Duration(milliseconds: 400),
    },
    {
      'icon': Icons.school,
      'label': 'Career',
      'delay': const Duration(milliseconds: 600),
    },
    {
      'icon': Icons.shopping_bag,
      'label': 'Market',
      'delay': const Duration(milliseconds: 800),
    },
    {
      'icon': Icons.history_edu,
      'label': 'History',
      'delay': const Duration(milliseconds: 1000),
    },
    {
      'icon': Icons.analytics,
      'label': 'Reports',
      'delay': const Duration(milliseconds: 1200),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const double contentMaxWidth = 500;

    return Scaffold(
      // CRITICAL: Background must match the Neumorphic component color
      backgroundColor: NeuTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              padding: const EdgeInsets.symmetric(
                horizontal: 30.0,
                vertical: 20.0,
              ),
              child: FadeTransition(
                opacity: _contentAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // 1. Header Card
                    NeumorphicContainer(
                      color: NeuTheme.background,
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 30,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'DANKIE Ministry',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: NeuTheme.accent, // Brand color
                              letterSpacing: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Connecting community,\nfaith, and progress.',
                            style: TextStyle(
                              fontSize: 15,
                              color: NeuTheme.text.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 2. Feature Icons
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 20,
                      runSpacing: 25,
                      children: features
                          .map(
                            (f) => NeumorphicFeatureIcon(
                              iconData: f['icon'],
                              label: f['label'],
                              delay: f['delay'],
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 40),

                    // 3. Image Frame
                    NeumorphicContainer(
                      color: NeuTheme.background,
                      borderRadius: 20,
                      padding: const EdgeInsets.all(10.0), // The "Frame"
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(
                          'assets/images4.jpeg',
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback in case image is missing during dev
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),

                    // 4. Interactive Get Started Button
                    NeuButton(
                      onTap: () {
                        widget.onGetStarted();
                        Navigator.of(context).pushReplacement(
                          isIOSPlatform
                              ? CupertinoPageRoute(
                                  builder: (_) => const Login_Page(),
                                )
                              : MaterialPageRoute(
                                  builder: (_) => const Login_Page(),
                                ),
                        );
                      },
                      child: Center(
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: NeuTheme.accent,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
