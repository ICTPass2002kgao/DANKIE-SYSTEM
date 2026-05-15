// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:ttact/Components/paystack_service.dart';
import 'package:ttact/Components/NeuDesign.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  final String? requiredPlanCode; // The plan user MUST have (based on count)
  final String? currentActivePlanCode; // The plan the user CURRENTLY has
  final Function(String planCode) onSubscribe;

  const SubscriptionPlansScreen({
    super.key,
    required this.requiredPlanCode,
    this.currentActivePlanCode, // Make sure to pass this from parent!
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;
    final primaryColor = theme.primaryColor;

    // Is the user currently on Free Tier properly?
    final isFreeTierActive = requiredPlanCode == null;

    // Use currentActivePlanCode if passed, otherwise assume based on required
    final String activePlan =
        currentActivePlanCode ?? (isFreeTierActive ? 'free_tier' : '');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: NeumorphicContainer(
        borderRadius: 20,
        padding: EdgeInsets.zero,
        color: baseColor,
        child: Container(
          width: isDesktop ? 1200 : double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header ---
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subscription Plans',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: NeumorphicContainer(
                        isPressed: false,
                        borderRadius: 30,
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Body ---
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Choose Your Plan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        requiredPlanCode != null
                            ? 'You have exceeded the limit of your current plan.'
                            : 'Select a plan below.',
                        style: TextStyle(fontSize: 14, color: theme.hintColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildPlanCard(
                            context: context,
                            planCode: 'free_tier',
                            title: 'Free Tier',
                            memberRange: '0 - 49 Members',
                            price: 'Free',
                            features: ['Standard generation of balance sheet'],
                            isRecommended: isFreeTierActive,
                            isActive: activePlan == 'free_tier',
                            isDisabled: !isFreeTierActive,
                            accentColor: Colors.grey,
                          ),
                          _buildPlanCard(
                            context: context,
                            planCode: PaystackService.planTier1,
                            title: 'Tier 1',
                            memberRange: '50 - 299 Members',
                            price: 'R289',
                            features: [
                              'Generate a balance sheet of 50-299 members',
                            ],
                            isRecommended:
                                requiredPlanCode == PaystackService.planTier1,
                            isActive: activePlan == PaystackService.planTier1,
                            accentColor: const Color(0xFF00C853),
                          ),
                          _buildPlanCard(
                            context: context,
                            planCode: PaystackService.planTier2,
                            title: 'Tier 2',
                            memberRange: '300 - 499 Members',
                            price: 'R499',
                            features: [
                              'Generate a balance sheet of 300-499 members',
                            ],
                            isRecommended:
                                requiredPlanCode == PaystackService.planTier2,
                            isActive: activePlan == PaystackService.planTier2,
                            accentColor: const Color(0xFF2962FF),
                          ),
                          _buildPlanCard(
                            context: context,
                            planCode: PaystackService.planTier3,
                            title: 'Tier 3',
                            memberRange: '500+ Members',
                            price: 'R889',
                            features: [
                              'Generate a balance sheet of 500+ members',
                            ],
                            isRecommended:
                                requiredPlanCode == PaystackService.planTier3,
                            isActive: activePlan == PaystackService.planTier3,
                            accentColor: const Color(0xFF6200EA),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String planCode,
    required String title,
    required String memberRange,
    required String price,
    required List<String> features,
    required bool isRecommended, // Is this the plan they SHOULD have?
    required bool isActive, // Is this the plan they CURRENTLY have?
    required Color accentColor,
    bool isDisabled = false,
  }) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;

    String buttonText = 'Choose Plan';
    Color btnColor = accentColor;

    if (isActive) {
      buttonText = 'Current Plan';
      btnColor = Colors.green;
    } else if (isRecommended) {
      buttonText = 'Subscribe Now';
    }

    final bool isActionable = !isDisabled && !isActive;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        NeumorphicContainer(
          borderRadius: 16,
          padding: const EdgeInsets.all(24.0),
          isPressed: isActive, // Sunken look for active plan
          color: baseColor,
          child: SizedBox(
            width: 260,
            child: Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.green : accentColor,
                        ),
                      ),
                      if (isActive)
                        Icon(Icons.check_circle, color: Colors.green, size: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    memberRange,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  NeumorphicContainer(
                    isPressed: true,
                    borderRadius: 12,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (price != 'Free')
                          Text(
                            '/mo',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.hintColor,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.withOpacity(0.2)),
                  const SizedBox(height: 16),

                  ...features.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: isDisabled
                                ? Colors.grey
                                : (isActive ? Colors.green : accentColor),
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  GestureDetector(
                    onTap: isActionable ? () => onSubscribe(planCode) : null,
                    child: NeumorphicContainer(
                      isPressed: isActive,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: baseColor,
                      child: Center(
                        child: Text(
                          buttonText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: btnColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ACTIVE BADGE (Green)
        if (isActive)
          Positioned(
            top: -10,
            right: 20,
            child: NeumorphicContainer(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.green,
              child: const Text(
                "ACTIVE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // REQUIRED BADGE (Only if not active)
        if (isRecommended && !isActive)
          Positioned(
            top: -10,
            right: 20,
            child: NeumorphicContainer(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: accentColor,
              child: const Text(
                "REQUIRED",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
