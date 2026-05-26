// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class ShareCardGenerator extends StatelessWidget {
  final String songName;
  final String artistName;
  final String appLogoPath; // e.g., "assets/dankie_logo.PNG"

  const ShareCardGenerator({
    Key? key,
    required this.songName,
    required this.artistName,
    required this.appLogoPath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ⭐️ ENHANCED COLOR PALETTE
    final Color baseColor = Color(0xFFE0E5EC); // Classic Neumorphic Base
    final Color accentBlue = Colors.blueAccent; // Your requested Blue

    return Container(
      width: 400,
      height: 711,
      decoration: BoxDecoration(
        color: baseColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            baseColor.withOpacity(0.9),
            Color(0xFFD1D9E6), // Slightly darker for gradient depth
          ],
        ),
      ),
      child: Stack(
        children: [
          // 1. TOP-LEFT ACCENT GLOW (Ambient Blue)
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBlue.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: accentBlue.withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ 
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [ 
                    NeumorphicContainer(
                      color: baseColor,
                      isPressed: false,
                      borderRadius: 200,
                      padding: EdgeInsets.all(20),
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
 
                    NeumorphicContainer(
                      color: baseColor,
                      isPressed: true,
                      borderRadius: 180,
                      padding: EdgeInsets.all(12),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentBlue.withOpacity(0.15),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: Stack(
                            children: [
                              Image.asset(
                                appLogoPath,
                                fit: BoxFit.cover,
                                width: 150,
                                height: 150,
                              ), 
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.2),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.1),
                                    ],
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

              SizedBox(height: 50),

              // 3. SONG DETAILS (The "Wow" Card)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: NeumorphicContainer(
                  color: baseColor,
                  isPressed: false,
                  borderRadius: 30,
                  padding: EdgeInsets.all(4), // For border effect
                  child: Container(
                    padding: EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withOpacity(0.5), baseColor],
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          songName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accentBlue,
                            fontSize: 26,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(height: 1, width: 20, color: accentBlue),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                artistName,
                                style: TextStyle(
                                  color: Colors.blueGrey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(height: 1, width: 20, color: accentBlue),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 50),

              // 4. ACTION BADGE (Cyber Neumorphic Style)
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: accentBlue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: NeumorphicContainer(
                  color: baseColor,
                  isPressed: true,
                  borderRadius: 50,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 15),
                      Text(
                        "AVAILABLE DANKIE MUSIC",
                        style: TextStyle(
                          color: accentBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 40),

              // 5. SUBTLE BRANDING
              Text(
                "SHARED FROM THE Dankie APP",
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
