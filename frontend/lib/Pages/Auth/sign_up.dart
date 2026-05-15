// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'dart:io' if (dart.library.html) 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Pages/Auth/email_verification_page.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Components/API.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

// --- ⭐️ NEUMORPHIC TEXT FIELD BUILDER ---
Widget _buildNeumorphicTextField({
  required TextEditingController controller,
  required String placeholder,
  required Color baseColor,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  bool readOnly = false,
  int? maxLines = 1,
  Widget? suffixIcon,
  required BuildContext context,
}) {
  final theme = Theme.of(context);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: NeumorphicContainer(
      isPressed: true,
      color: baseColor,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: isIOSPlatform
          ? CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              readOnly: readOnly,
              maxLines: maxLines,
              placeholderStyle: TextStyle(
                color: theme.hintColor.withOpacity(0.6),
                fontFamily: 'Roboto',
              ),
              style: TextStyle(
                color: theme.hintColor.withOpacity(0.6),
                fontFamily: 'Roboto',
              ),
              keyboardType: keyboardType,
              obscureText: obscureText,
              decoration: null,
              padding: const EdgeInsets.all(16.0),
              prefix: prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(prefixIcon, color: theme.primaryColor),
                    )
                  : null,
              suffix: suffixIcon,
            )
          : TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              readOnly: readOnly,
              maxLines: maxLines,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontFamily: 'Roboto',
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: theme.hintColor.withOpacity(0.6),
                  fontFamily: 'Roboto',
                ),
                prefixIcon: prefixIcon != null
                    ? Icon(prefixIcon, color: theme.primaryColor)
                    : null,
                suffixIcon: suffixIcon,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 10.0,
                ),
              ),
            ),
    ),
  );
}

// --- ⭐️ NEUMORPHIC SELECTION TILE ---
Widget _buildNeumorphicSelectionTile({
  required String title,
  required String trailingText,
  required VoidCallback onTap,
  required BuildContext context,
  required Color baseColor,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: false,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 15,
              ),
            ),
            Row(
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    trailingText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.hintColor.withOpacity(0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// --- ⭐️ NEUMORPHIC SECTION HEADER ---
Widget _buildNeumorphicSectionHeader(String title, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: Theme.of(context).primaryColor.withOpacity(0.8),
      ),
    ),
  );
}

// Custom platform-aware Action Sheet Builder
void _buildActionSheet({
  required BuildContext context,
  required String title,
  required List<String> actions,
  required ValueChanged<String> onSelected,
}) {
  if (isIOSPlatform) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(title),
        actions: actions.map((item) {
          return CupertinoActionSheetAction(
            child: Text(item),
            onPressed: () {
              onSelected(item);
              Navigator.pop(context);
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Divider(),
              ...actions.map((item) {
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    onSelected(item);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  TextEditingController txtEmail = TextEditingController();
  TextEditingController txtName = TextEditingController();
  TextEditingController txtSurname = TextEditingController();
  TextEditingController txtAddress = TextEditingController();
  TextEditingController txtContactNumber = TextEditingController();
  TextEditingController txtAccountNumber = TextEditingController();
  TextEditingController txtBankCodeController = TextEditingController();

  TextEditingController txtPassword = TextEditingController();
  TextEditingController txtConfirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool isChecked = false;
  Api backendService = Api();
  List<String> roles = ['Member', 'Seller', 'External Member'];
  String? role;

  String? selectedMemberUid;
  String? selectedProvince;
  List<String> provinces = [
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];

  String? selectedGender;
  List<String> genders = ['Male', 'Female'];

  String? selectedDistrictElder;
  String? selectedCommunityName;
  Map<String, dynamic>? selectedDistrictData;
  Map<String, dynamic>? currentOverseerData;
  AdManager adManager = AdManager();

  // ⭐️ FIX 1: State variables to hold fetched overseers so it doesn't reload on every keystroke
  bool _isLoadingOverseers = false;
  List<dynamic> _overseersList = [];

  @override
  void initState() {
    super.initState();
    adManager.loadRewardedInterstitialAd();
    _getAddress();
  }

  @override
  void dispose() {
    txtEmail.dispose();
    txtName.dispose();
    txtSurname.dispose();
    txtAddress.dispose();
    txtContactNumber.dispose();
    txtPassword.dispose();
    txtConfirmPassword.dispose();
    super.dispose();
  }

  Future<void> _getAddress() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          Api().showMessage(
            context,
            'Location Permission Denied',
            'Please grant location permission to auto-fill address.',
            Colors.orange,
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (kIsWeb) {
        const String apiKey = "AIzaSyBzPf3eQnhq13QKvDw9ZShYSYk1qycHMww";
        final url = Uri.parse(
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey",
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            String formattedAddress = data['results'][0]['formatted_address'];
            setState(() {
              txtAddress.text = formattedAddress;
            });
          } else {
            txtAddress.text = "Address not found (Web API Error)";
          }
        } else {
          txtAddress.text = "Connection error";
        }
      } else {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark p = placemarks.first;
          String fullAddress = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.postalCode,
          ].where((s) => s != null && s.isNotEmpty).join(', ');

          setState(() {
            txtAddress.text = fullAddress;
          });
        } else {
          txtAddress.text = "Address details not found";
        }
      }
    } catch (e) {
      Api().showMessage(
        context,
        'Location Error',
        'Could not get address. Check Internet or Permissions.',
        Colors.red,
      );
    }
  }

  List<String> get_district_elder_names(Map<String, dynamic>? data) {
    if (data == null ||
        !data.containsKey('districts') ||
        data['districts'] == null) {
      return [];
    }
    return (data['districts'] as List<dynamic>)
        .map((district) => district['district_elder_name'] as String?)
        .where((name) => name != null)
        .cast<String>()
        .toSet()
        .toList();
  }

  List<String> getCommunityNamesForDistrict(
    Map<String, dynamic>? districtData,
  ) {
    if (districtData == null ||
        !districtData.containsKey('communities') ||
        districtData['communities'] == null) {
      return [];
    }
    return (districtData['communities'] as List<dynamic>)
        .map((community) => community['community_name'] as String?)
        .where((name) => name != null)
        .cast<String>()
        .toSet()
        .toList();
  }

  // ⭐️ FIX 2: Fetches overseers explicitly and updates state once, preventing the UI from constantly resetting.
  Future<void> _fetchAndSetOverseersForProvince(String province) async {
    setState(() {
      _isLoadingOverseers = true;
      _overseersList = [];
    });

    final url = Uri.parse(
      '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?province=$province',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          setState(() {
            _overseersList = decoded['results'] as List<dynamic>;
          });
        } else if (decoded is List) {
          setState(() {
            _overseersList = decoded;
          });
        }
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        print(
          "❌ Blocked by Django: Update OverseerViewSet permissions to AllowAny for GET.",
        );
      }
    } catch (e) {
      print("Network Error: $e");
    } finally {
      setState(() {
        _isLoadingOverseers = false;
      });
    }
  }

  // Searchable Overseer Modal
  void _showOverseerSearchSheet(BuildContext context, Color neumoBaseColor) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            final theme = Theme.of(context);
            final filteredOverseers = _overseersList.where((overseer) {
              final name = (overseer['overseer_initials_surname'] ?? '')
                  .toString()
                  .toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: neumoBaseColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.hintColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search Overseer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: NeumorphicContainer(
                      isPressed: true,
                      color: neumoBaseColor,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setStateModal(() {
                            searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by initials/surname...',
                          hintStyle: TextStyle(
                            color: theme.hintColor.withOpacity(0.6),
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.search,
                            color: theme.primaryColor,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filteredOverseers.isEmpty
                        ? Center(
                            child: Text(
                              "No overseers found",
                              style: TextStyle(color: theme.hintColor),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredOverseers.length,
                            itemBuilder: (context, index) {
                              final overseer = filteredOverseers[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 4,
                                ),
                                title: Text(
                                  overseer['overseer_initials_surname']
                                      .toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: theme.hintColor.withOpacity(0.5),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedMemberUid = overseer['uid'];
                                    currentOverseerData =
                                        overseer as Map<String, dynamic>;
                                    selectedDistrictElder = null;
                                    selectedCommunityName = null;
                                    selectedDistrictData = null;
                                  });
                                  Navigator.pop(modalContext);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ⭐️ FIX 3: Restored Strict Validation. Users cannot skip these fields.
  bool _validateFields() {
    if (txtName.text.trim().isEmpty ||
        txtSurname.text.trim().isEmpty ||
        txtAddress.text.trim().isEmpty ||
        txtContactNumber.text.trim().isEmpty) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please fill in all personal details.',
        Colors.red,
      );
      return false;
    }

    if (selectedGender == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select your gender.',
        Colors.red,
      );
      return false;
    }

    if (role == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select a role.',
        Colors.red,
      );
      return false;
    }

    if (role != 'External Member') {
      if (selectedProvince == null) {
        Api().showMessage(
          context,
          'Validation Error',
          'Please select your province.',
          Colors.red,
        );
        return false;
      }
      if (selectedMemberUid == null) {
        Api().showMessage(
          context,
          'Validation Error',
          'Please select an overseer.',
          Colors.red,
        );
        return false;
      }
      if (selectedDistrictElder == null) {
        Api().showMessage(
          context,
          'Validation Error',
          'Please select a district elder.',
          Colors.red,
        );
        return false;
      }
      if (selectedCommunityName == null) {
        Api().showMessage(
          context,
          'Validation Error',
          'Please select a community name.',
          Colors.red,
        );
        return false;
      }
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(txtEmail.text.trim())) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please enter a valid email address.',
        Colors.red,
      );
      return false;
    }

    if (txtPassword.text.isEmpty || txtConfirmPassword.text.isEmpty) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please enter and confirm your password.',
        Colors.red,
      );
      return false;
    }
    if (txtPassword.text != txtConfirmPassword.text) {
      Api().showMessage(
        context,
        'Validation Error',
        'Passwords do not match.',
        Colors.red,
      );
      return false;
    }
    if (txtPassword.text.length < 6) {
      Api().showMessage(
        context,
        'Validation Error',
        'Password must be at least 6 characters long.',
        Colors.red,
      );
      return false;
    }

    if (!isChecked) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please agree to the Terms and Conditions and Privacy Policy.',
        Colors.red,
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    String emailFromArgs = args['email'] ?? '';
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final List<String> district_elder_names = get_district_elder_names(
      currentOverseerData,
    );
    final List<String> communityNames = getCommunityNamesForDistrict(
      selectedDistrictData,
    );

    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 600 : double.infinity,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: NeumorphicContainer(
                              color: neumoBaseColor,
                              borderRadius: 50,
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.arrow_back,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: theme.primaryColor,
                                ),
                              ),
                              Text(
                                "Join the community",
                                style: TextStyle(
                                  color: theme.hintColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      _buildNeumorphicTextField(
                        context: context,
                        baseColor: neumoBaseColor,
                        controller: txtName,
                        placeholder: 'Name',
                        prefixIcon: CupertinoIcons.person_fill,
                        keyboardType: TextInputType.name,
                      ),
                      _buildNeumorphicTextField(
                        context: context,
                        baseColor: neumoBaseColor,
                        controller: txtSurname,
                        placeholder: 'Surname',
                        prefixIcon: CupertinoIcons.person_add,
                        keyboardType: TextInputType.name,
                      ),
                      _buildNeumorphicTextField(
                        context: context,
                        baseColor: neumoBaseColor,
                        controller: txtAddress,
                        placeholder: 'Address',
                        prefixIcon: CupertinoIcons.location_solid,
                        keyboardType: TextInputType.streetAddress,

                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.my_location,
                            color: theme.primaryColor,
                          ),
                          onPressed: () => _getAddress(),
                        ),
                      ),
                      _buildNeumorphicTextField(
                        context: context,
                        baseColor: neumoBaseColor,
                        controller: txtContactNumber,
                        placeholder: 'Contact Number',
                        prefixIcon: CupertinoIcons.phone_fill,
                        keyboardType: TextInputType.phone,
                      ),

                      _buildNeumorphicSelectionTile(
                        context: context,
                        baseColor: neumoBaseColor,
                        title: 'Gender',
                        trailingText: selectedGender ?? 'Select',
                        onTap: () {
                          _buildActionSheet(
                            context: context,
                            title: 'Select Gender',
                            actions: genders,
                            onSelected: (gender) {
                              setState(() {
                                selectedGender = gender;
                              });
                            },
                          );
                        },
                      ),

                      _buildNeumorphicSectionHeader("ROLE SELECTION", context),
                      _buildNeumorphicSelectionTile(
                        context: context,
                        baseColor: neumoBaseColor,
                        title: 'Select Role',
                        trailingText: role ?? 'Tap to select',
                        onTap: () {
                          _buildActionSheet(
                            context: context,
                            title: 'Select Role',
                            actions: roles,
                            onSelected: (userRole) {
                              setState(() {
                                role = userRole;
                              });
                            },
                          );
                        },
                      ),

                      if (role == 'Seller') ...[
                        const SizedBox(height: 10),
                        _buildNeumorphicTextField(
                          context: context,
                          baseColor: neumoBaseColor,
                          controller: txtAccountNumber,
                          placeholder: 'Bank Account Number',
                          prefixIcon: CupertinoIcons.money_dollar,
                          keyboardType: TextInputType.number,
                        ),
                        _buildNeumorphicTextField(
                          context: context,
                          baseColor: neumoBaseColor,
                          controller: txtBankCodeController,
                          placeholder: 'Bank Code',
                          prefixIcon: CupertinoIcons.building_2_fill,
                          keyboardType: TextInputType.number,
                        ),
                      ],

                      if (role != null && role != 'External Member') ...[
                        _buildNeumorphicSectionHeader(
                          "LOCATION DETAILS",
                          context,
                        ),
                        _buildNeumorphicSelectionTile(
                          context: context,
                          baseColor: neumoBaseColor,
                          title: 'Province',
                          trailingText: selectedProvince ?? 'Select',
                          onTap: () {
                            _buildActionSheet(
                              context: context,
                              title: 'Select your Province',
                              actions: provinces,
                              onSelected: (province) {
                                setState(() {
                                  selectedProvince = province;
                                  selectedMemberUid = null;
                                  currentOverseerData = null;
                                  selectedDistrictElder = null;
                                  selectedCommunityName = null;
                                  selectedDistrictData = null;
                                });
                                // Trigger fetch once instead of repeatedly
                                _fetchAndSetOverseersForProvince(province);
                              },
                            );
                          },
                        ),

                        if (selectedProvince != null) ...[
                          if (_isLoadingOverseers)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: isIOSPlatform
                                    ? const CupertinoActivityIndicator()
                                    : const CircularProgressIndicator(),
                              ),
                            ),

                          if (!_isLoadingOverseers)
                            _buildNeumorphicSelectionTile(
                              context: context,
                              baseColor: neumoBaseColor,
                              title: 'Overseer',
                              trailingText: selectedMemberUid != null
                                  ? (currentOverseerData?['overseer_initials_surname'] ??
                                        'Selected')
                                  : 'Select',
                              onTap: () {
                                if (_overseersList.isEmpty) {
                                  Api().showMessage(
                                    context,
                                    'No Overseers',
                                    'No overseers found for this province.',
                                    Colors.orange,
                                  );
                                  return;
                                }

                                // Custom Searchable Modal triggered here
                                _showOverseerSearchSheet(
                                  context,
                                  neumoBaseColor,
                                );
                              },
                            ),
                        ],

                        if (currentOverseerData != null)
                          _buildNeumorphicSelectionTile(
                            context: context,
                            baseColor: neumoBaseColor,
                            title: 'District Elder',
                            trailingText: selectedDistrictElder ?? 'Select',
                            onTap: () {
                              if (district_elder_names.isEmpty) {
                                Api().showMessage(
                                  context,
                                  'No Districts',
                                  'No districts found.',
                                  Colors.orange,
                                );
                                return;
                              }
                              _buildActionSheet(
                                context: context,
                                title: 'Choose District Elder',
                                actions: district_elder_names,
                                onSelected: (elderName) {
                                  setState(() {
                                    selectedDistrictElder = elderName;
                                    selectedDistrictData =
                                        (currentOverseerData?['districts']
                                                    as List<dynamic>?)
                                                ?.firstWhere(
                                                  (district) =>
                                                      district['district_elder_name'] ==
                                                      elderName,
                                                  orElse: () => null,
                                                )
                                            as Map<String, dynamic>?;
                                    selectedCommunityName = null;
                                  });
                                },
                              );
                            },
                          ),

                        if (selectedDistrictData != null)
                          _buildNeumorphicSelectionTile(
                            context: context,
                            baseColor: neumoBaseColor,
                            title: 'Community',
                            trailingText: selectedCommunityName ?? 'Select',
                            onTap: () {
                              if (communityNames.isEmpty) {
                                Api().showMessage(
                                  context,
                                  'No Communities',
                                  'No communities found.',
                                  Colors.orange,
                                );
                                return;
                              }
                              _buildActionSheet(
                                context: context,
                                title: 'Choose Community',
                                actions: communityNames,
                                onSelected: (communityName) {
                                  setState(() {
                                    selectedCommunityName = communityName;
                                  });
                                },
                              );
                            },
                          ),
                      ],

                      _buildNeumorphicSectionHeader(
                        "ACCOUNT CREDENTIALS",
                        context,
                      ),
                      if (emailFromArgs.isEmpty) ...[
                        _buildNeumorphicTextField(
                          context: context,
                          baseColor: neumoBaseColor,
                          controller: txtEmail,
                          placeholder: 'Email Address',
                          prefixIcon: CupertinoIcons.mail_solid,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _buildNeumorphicTextField(
                          context: context,
                          baseColor: neumoBaseColor,
                          controller: txtPassword,
                          placeholder: 'Password',
                          prefixIcon: CupertinoIcons.lock_fill,
                          obscureText: _obscurePassword,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                        _buildNeumorphicTextField(
                          context: context,
                          baseColor: neumoBaseColor,
                          controller: txtConfirmPassword,
                          placeholder: 'Confirm Password',
                          prefixIcon: CupertinoIcons.lock_fill,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            child: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: isChecked,
                              onChanged: (val) =>
                                  setState(() => isChecked = val!),
                              activeColor: theme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: theme.hintColor,
                                  fontSize: 14,
                                  fontFamily: 'Roboto',
                                ),
                                children: [
                                  const TextSpan(
                                    text: "I've read and agree with the ",
                                  ),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final Uri url = Uri.parse(
                                          "https://dankie-website.web.app/terms_and_conditions.html",
                                        );
                                        if (!await launchUrl(
                                          url,
                                          mode: LaunchMode.inAppBrowserView,
                                        )) {
                                          print("Could not launch url");
                                        }
                                      },
                                      child: Text(
                                        "Terms and Conditions",
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: " and the "),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final Uri url = Uri.parse(
                                          "https://dankie-website.web.app/privacy_policy.html",
                                        );
                                        if (!await launchUrl(
                                          url,
                                          mode: LaunchMode.inAppBrowserView,
                                        )) {
                                          print("Could not launch url");
                                        }
                                      },
                                      child: Text(
                                        "Privacy Policy.",
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      GestureDetector(
                        onTap: () async {
                          if (isIOSPlatform) Api().showIosLoading(context);
                          if (!isIOSPlatform) Api().showLoading(context);

                          if (!txtAddress.text.contains(',')) {
                            await _getAddress();
                          }

                          if (!_validateFields()) {
                            if (context.mounted) Navigator.pop(context);
                            return;
                          }

                          String code = Api().generateVerificationCode();
                          print('here is the code $code');

                          try {
                            bool emailSent = await Api().sendEmail(
                              txtEmail.text,
                              'Your Account Verification code',
                              """
                            Hello ${txtName.text} ${txtSurname.text},

                            Thank you for signing up!
                            Your 6-digit verification code is: $code

                            This code expires soon.
                            If you didn't request this, you can safely ignore this email.
                            """,
                              context,
                            );

                            if (emailSent) {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VerificationScreen(
                                    expectedCode: code,
                                    name: txtName.text.trim(),
                                    surname: txtSurname.text.trim(),
                                    email: txtEmail.text.trim(),
                                    password: txtPassword.text,
                                    address: txtAddress.text.trim(),
                                    contacts: txtContactNumber.text.trim(),
                                    gender: selectedGender ?? '',
                                    selectedOverseerUid:
                                        role == 'External Member'
                                        ? ''
                                        : selectedMemberUid!,
                                    role: role!,
                                    accountNumber: txtAccountNumber.text.trim(),
                                    bankCode: txtBankCodeController.text.trim(),
                                    province: role == 'External Member'
                                        ? ''
                                        : selectedProvince!,
                                    districtElder: role == 'External Member'
                                        ? ''
                                        : selectedDistrictElder!,
                                    communityName: role == 'External Member'
                                        ? ''
                                        : selectedCommunityName!,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            print("Here is the error ${e.toString()}");
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        child: NeumorphicContainer(
                          color: theme.primaryColor,
                          borderRadius: 10,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Text(
                              "SIGN UP",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Have an account?',
                            style: TextStyle(color: theme.hintColor),
                          ),
                          SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Login here',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
