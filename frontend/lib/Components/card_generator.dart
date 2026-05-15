import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ttact/Components/NeuDesign.dart';

class CareerShareCardGenerator extends StatelessWidget {
  final String title;
  final String category;
  final String expiryDate;

  const CareerShareCardGenerator({
    super.key,
    required this.title,
    required this.category,
    required this.expiryDate,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Color(0xFFE0E5EC);
    final Color accentBlue = Colors.blueAccent;
    final Color deepBlue = Color(0xFF1A237E);

    return Container(
      width: 400,
      height: 711,
      decoration: BoxDecoration(
        color: baseColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, baseColor.withOpacity(0.9), Color(0xFFD1D9E6)],
        ),
      ),
      child: Stack(
        children: [
          // Ambient Blue Glow
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
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
              // 1. PREMIUM LOGO RING (Same as Music Tab)
              Center(
                child: NeumorphicContainer(
                  color: baseColor,
                  isPressed: false,
                  borderRadius: 200,
                  padding: EdgeInsets.all(15),
                  child: NeumorphicContainer(
                    color: baseColor,
                    isPressed: true,
                    borderRadius: 150,
                    padding: EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Image.asset(
                        "assets/dankie_logo.PNG",
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 40),

              // 2. CATEGORY BADGE (Cyber Pill)
              NeumorphicContainer(
                color: baseColor,
                isPressed: true,
                borderRadius: 50,
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                child: Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    color: accentBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 2.0,
                  ),
                ),
              ),

              SizedBox(height: 30),

              // 3. CAREER DETAILS CARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: NeumorphicContainer(
                  color: baseColor,
                  isPressed: false,
                  borderRadius: 30,
                  padding: EdgeInsets.all(25),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: deepBlue,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 15),
                      Container(
                        height: 2,
                        width: 40,
                        color: accentBlue.withOpacity(0.3),
                      ),
                      SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            color: accentBlue,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Closing: $expiryDate",
                            style: TextStyle(
                              color: Colors.blueGrey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 50),

              // 4. ACTION FOOTER
              NeumorphicContainer(
                color: baseColor,
                isPressed: false,
                borderRadius: 20,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  "APPLY ON DANKIE APP",
                  style: TextStyle(
                    color: deepBlue.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
