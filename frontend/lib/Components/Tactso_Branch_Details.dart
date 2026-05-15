// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/User/ask_for_assistance.dart';
import 'package:url_launcher/url_launcher.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class TactsoBranchDetails extends StatelessWidget {
  final Map<String, dynamic> universityDetails;
  final dynamic campusListForUniversity;

  const TactsoBranchDetails({
    Key? key,
    required this.universityDetails,
    required this.campusListForUniversity,
  }) : super(key: key);

  // --- NEUMORPHIC BUTTON BUILDER ---
  Widget _buildNeuButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required String text,
    required Color baseColor,
    required Color textColor,
    bool isPrimary = false, // If true, button is colored (Active)
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onPressed,
      child: NeumorphicContainer(
        color: isPrimary ? theme.primaryColor : baseColor,
        isPressed: false, // Convex Button
        borderRadius: 15,
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isPrimary ? Colors.white : textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    final bool hasMultipleCampuses =
        universityDetails['has_multiple_campuses'] ?? false;
    final bool isAppOpen =
        universityDetails['is_application_open'] ??
        universityDetails['is_application_open'] ??
        false;

    return Container(
      decoration: BoxDecoration(
        color: neumoBaseColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(25, 15, 25, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
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
            const SizedBox(height: 30),

            // --- 1. NEUMORPHIC IMAGE FRAME ---
            Center(
              child: NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: false, // Pop out frame
                borderRadius: 20,
                padding: EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: (universityDetails['image_urls'] == null)
                      ? Container(
                          height: 150,
                          width: double.infinity,
                          color: theme.scaffoldBackgroundColor,
                          child: Icon(
                            Icons.location_city,
                            size: 60,
                            color: theme.hintColor.withOpacity(0.3),
                          ),
                        )
                      : Image.network(
                          universityDetails['image_urls'],
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              width: double.infinity,
                              color: theme.scaffoldBackgroundColor,
                              child: Icon(
                                Icons.broken_image,
                                size: 50,
                                color: theme.hintColor,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- 2. TITLE & SHARE ROW ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    universityDetails['university_name'] ?? 'University Name',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                      height: 1.1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    Share.share(
                      "Check out ${universityDetails['university_name'] ?? 'this university'}'s application page: ${universityDetails['application_link'] ?? ''}",
                    );
                  },
                  child: NeumorphicContainer(
                    color: neumoBaseColor,

                    isPressed: false,
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      isIOSPlatform ? CupertinoIcons.share : Icons.share,
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- 3. SUNKEN ADDRESS FIELD ---
            GestureDetector(
              onTap: () async {
                final address = universityDetails['address'] ?? '';
                if (address.isNotEmpty) {
                  Uri mapUrl = isIOSPlatform
                      ? Uri.parse(
                          'https://maps.apple.com/?q=${Uri.encodeComponent(address)}',
                        )
                      : Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
                        );

                  if (await canLaunchUrl(mapUrl)) {
                    await launchUrl(
                      mapUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    Api().showMessage(
                      context,
                      'Cannot launch Maps',
                      "Error",
                      Colors.red,
                    );
                  }
                } else {
                  Api().showMessage(
                    context,
                    'No address provided.',
                    "Error",
                    Colors.orange,
                  );
                }
              },
              child: NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: true, // Sunken
                borderRadius: 15,
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isIOSPlatform
                          ? CupertinoIcons.location_solid
                          : Icons.location_on,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        universityDetails['address'] ?? 'Address not available',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: theme.hintColor,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // --- 4. STATUS INDICATOR ---
            Row(
              children: [
                NeumorphicContainer(
                  color: neumoBaseColor,

                  isPressed: true, // Sunken LED
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.circle,
                    size: 12,
                    color: isAppOpen ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  isAppOpen ? 'Applications Open' : 'Applications Closed',
                  style: TextStyle(
                    color: isAppOpen ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- 5. ACTION BUTTONS ---

            // APPLY BUTTON
            if (isAppOpen)
              _buildNeuButton(
                context: context,
                onPressed: () async {
                  final url = Uri.parse(
                    universityDetails['application_link'] ?? 'about:blank',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                  } else {
                    Api().showMessage(
                      context,
                      'Cannot open application link.',
                      "Error",
                      Colors.red,
                    );
                  }
                },
                text: 'Apply for yourself',
                baseColor: neumoBaseColor,
                textColor: Colors.white,
                isPrimary: true, // Colored Button
              )
            else
              NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: true, // Sunken Disabled Button
                borderRadius: 15,
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    'Applications Closed',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 15),

            // ASK FOR HELP BUTTON
            _buildNeuButton(
              context: context,
              onPressed: () {
                List<Map<String, dynamic>> actualCampusList = [];
                if (campusListForUniversity is List) {
                  for (var item in campusListForUniversity) {
                    if (item is Map<String, dynamic>)
                      actualCampusList.add(item);
                  }
                }

                if (hasMultipleCampuses && actualCampusList.isNotEmpty) {
                  if (isIOSPlatform) {
                    _showiOSCampusSelection(context, theme, actualCampusList);
                  } else {
                    _showAndroidCampusSelection(
                      context,
                      theme,
                      neumoBaseColor,
                      actualCampusList,
                    );
                  }
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UniversityApplicationScreen(
                        universityData: universityDetails,
                        selectedCampus: actualCampusList.isNotEmpty
                            ? actualCampusList.first
                            : null,
                      ),
                    ),
                  );
                }
              },
              text: 'Ask for Help!',
              baseColor: neumoBaseColor,
              textColor: theme.primaryColor,
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }

  // --- NEUMORPHIC CAMPUS SELECTION (Android) ---
  void _showAndroidCampusSelection(
    BuildContext context,
    ThemeData theme,
    Color baseColor,
    List<Map<String, dynamic>> campuses,
  ) {
    Navigator.pop(context); // Close current

    showModalBottomSheet(
      context: context,
      backgroundColor: baseColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        Map<String, dynamic>? _selectedCampus;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(25.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select a Campus",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // List of Campuses
                    ...campuses.map((campus) {
                      if (campus['campus_name'] == null)
                        return SizedBox.shrink();
                      bool isSelected = _selectedCampus == campus;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () =>
                              setModalState(() => _selectedCampus = campus),
                          child: NeumorphicContainer(
                            color: isSelected
                                ? theme.primaryColor.withOpacity(0.1)
                                : baseColor,
                            isPressed: isSelected, // Sunken if selected
                            borderRadius: 12,
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  campus['campus_name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? theme.primaryColor
                                        : theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: theme.primaryColor,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 25),

                    _buildNeuButton(
                      context: context,
                      onPressed: () {
                        if (_selectedCampus != null) {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UniversityApplicationScreen(
                                universityData: universityDetails,
                                selectedCampus: _selectedCampus,
                              ),
                            ),
                          );
                        } else {
                          Api().showMessage(
                            context,
                            'Select a campus first.',
                            "Warning",
                            Colors.orange,
                          );
                        }
                      },
                      text: "Proceed",
                      baseColor: baseColor,
                      textColor: Colors.white,
                      isPrimary: true,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- IOS CAMPUS SELECTION (Native Sheet) ---
  void _showiOSCampusSelection(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> campuses,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select Campus'),
        message: const Text('Which campus do you need assistance with?'),
        actions: campuses.map((campus) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UniversityApplicationScreen(
                    universityData: universityDetails,
                    selectedCampus: campus,
                  ),
                ),
              );
            },
            child: Text(campus['campus_name'] ?? 'Unknown Campus'),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
