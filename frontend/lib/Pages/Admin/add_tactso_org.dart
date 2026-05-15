// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_field_validation/text_field_validation.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/Admin/services/branch_services.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// --- ⭐️ NEUMORPHIC TEXT FIELD WRAPPER ---
Widget _buildNeumorphicTextField({
  required TextEditingController controller,
  required String placeholder,
  required Color baseColor,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  Widget? suffixIcon,
  String? Function(String?)? validator,
  required BuildContext context,
}) {
  final theme = Theme.of(context);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NeumorphicContainer(
        isPressed: true,
        color: baseColor,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: isIOSPlatform
            ? CupertinoTextField(
                controller: controller,
                placeholder: placeholder,
                placeholderStyle: TextStyle(
                  color: theme.hintColor.withOpacity(0.9),
                ),
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
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
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
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
                validator: validator,
              ),
      ),
      if (validator != null) SizedBox(height: 15),
    ],
  );
}

class AddTactsoBranch extends StatefulWidget {
  final String? uid;
  final String? fullName;
  final String? portfolio;
  final String? province;
  const AddTactsoBranch({
    super.key,
    this.uid,
    this.fullName,
    this.portfolio,
    this.province,
  });

  @override
  State<AddTactsoBranch> createState() => _AddTactsoBranchState();
}

class _AddTactsoBranchState extends State<AddTactsoBranch> {
  final _service = BranchService();
  final _picker = ImagePicker();

  // Assignment State Variables
  List<dynamic> _allOverseers = [];
  List<dynamic> _allDistricts = [];
  String? _selectedOverseerId;
  String? _selectedDistrictId;
  bool _isLoadingData = true;

  // Controllers
  final universityNameController = TextEditingController();
  final campusNameController = TextEditingController();
  final applicationLinkController = TextEditingController();
  final institutionAddressController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final educationOfficerNameController = TextEditingController();
  final chairpersonNameController = TextEditingController();

  // Files
  XFile? universityImageFile;
  XFile? educationOfficerImageFile;
  XFile? chairpersonImageFile;

  bool isApplicationOpen = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fetchAssignmentData();
  }

  // --- FETCH OVERSEERS & DISTRICTS ---
  Future<void> _fetchAssignmentData() async {
    try {
      final baseUrl = Api().BACKEND_BASE_URL_DEBUG;
      final User? user = FirebaseAuth.instance.currentUser;
      final String token = user != null ? await user.getIdToken() ?? '' : '';

      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/overseers/'), headers: headers),
        http.get(Uri.parse('$baseUrl/districts/'), headers: headers),
      ]);

      setState(() {
        _allOverseers = _parseJson(responses[0]);
        _allDistricts = _parseJson(responses[1]);
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint("Error fetching assignment data: $e");
      setState(() => _isLoadingData = false);
    }
  }

  List<dynamic> _parseJson(http.Response response) {
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return (decoded is Map && decoded.containsKey('results'))
          ? decoded['results']
          : decoded;
    }
    return [];
  }

  Future<void> _pickImage(Function(XFile) onPicked) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _handleSubmit() async {
    // 1. UI Validation (Ensure Committee details are present for the table)
    if (_selectedOverseerId == null || _selectedDistrictId == null) {
      Api().showMessage(
        context,
        'Assign an Overseer and a District.',
        'Missing Assignment',
        Colors.orange,
      );
      return;
    }

    if (universityNameController.text.isEmpty ||
        universityImageFile == null ||
        educationOfficerNameController.text.isEmpty ||
        educationOfficerImageFile == null ||
        chairpersonNameController.text.isEmpty ||
        chairpersonImageFile == null ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      Api().showMessage(
        context,
        'Please fill all details & upload all committee faces.',
        'Missing Info',
        Colors.orange,
      );
      return;
    }

    Api().showLoading(context);

    try {
      // 2. Call the Service
      // Ensure your BranchService maps these names/files to 'education_officer_name', 'chairperson_name', etc.
      await _service.createBranch(
        overseerUid: _selectedOverseerId!,
        districtId: _selectedDistrictId!,
        universityName: universityNameController.text.trim(),
        campusName: campusNameController.text.trim(),
        appLink: applicationLinkController.text.trim(),
        address: institutionAddressController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        isOpen: isApplicationOpen,
        uniImage: universityImageFile!,
        // --- COMMITTEE DATA (Aligning with TactsoCommitteeMember Table) ---
        officerName: educationOfficerNameController.text.trim(),
        officerImage: educationOfficerImageFile!,
        chairName: chairpersonNameController.text.trim(),
        chairImage: chairpersonImageFile!,
      );

      // 3. Auto-add Community under the District
      try {
        final User? user = FirebaseAuth.instance.currentUser;
        final String token = user != null ? await user.getIdToken() ?? '' : '';

        String? elderName;
        try {
          final selectedDist = _allDistricts.firstWhere(
            (d) => d['id'].toString() == _selectedDistrictId,
          );
          elderName = selectedDist['district_elder_name'];
        } catch (_) {}

        await http.post(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/communities/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'community_name': universityNameController.text.trim(),
            'full_address': institutionAddressController.text.trim(),
            'district': _selectedDistrictId,
            if (elderName != null) 'district_elder_name': elderName,
          }),
        );
      } catch (e) {
        print("Community sync error: $e");
      }

      Navigator.pop(context);
      Api().showMessage(
        context,
        'Branch & Committee Created!',
        'Success',
        Colors.green,
      );
      _clearForm();
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(context, e.toString(), 'Error', Colors.red);
    }
  }

  void _clearForm() {
    universityNameController.clear();
    campusNameController.clear();
    applicationLinkController.clear();
    institutionAddressController.clear();
    emailController.clear();
    passwordController.clear();
    educationOfficerNameController.clear();
    chairpersonNameController.clear();
    setState(() {
      universityImageFile = null;
      educationOfficerImageFile = null;
      chairpersonImageFile = null;
      isApplicationOpen = false;
      _selectedOverseerId = null;
      _selectedDistrictId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    List<dynamic> filteredDistricts = _allDistricts
        .where((d) => d['overseer'].toString() == _selectedOverseerId)
        .toList();

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: _isLoadingData
          ? Center(child: CupertinoActivityIndicator())
          : Stack(
              children: [
                Positioned(
                  top: -50,
                  left: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isLargeScreen = constraints.maxWidth >= 850;
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 40,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isLargeScreen ? 1000 : 600,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              NeumorphicContainer(
                                color: neumoBaseColor,
                                borderRadius: 20,
                                padding: const EdgeInsets.all(25),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.add_business_rounded,
                                      size: 50,
                                      color: theme.primaryColor,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      "Add TACTSO Branch",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: theme.primaryColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      "Create new university portal & committee",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.primaryColor.withOpacity(
                                          0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 30),
                              NeumorphicContainer(
                                color: neumoBaseColor,
                                borderRadius: 20,
                                padding: const EdgeInsets.all(25),
                                child: isLargeScreen
                                    ? _buildDesktopLayout(
                                        theme,
                                        neumoBaseColor,
                                        filteredDistricts,
                                      )
                                    : _buildMobileLayout(
                                        theme,
                                        neumoBaseColor,
                                        filteredDistricts,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildMobileLayout(
    ThemeData theme,
    Color neumoBaseColor,
    List<dynamic> filteredDistricts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSection1(theme, neumoBaseColor, filteredDistricts),
        SizedBox(height: 30),
        Divider(),
        SizedBox(height: 10),
        _buildSection2(theme, neumoBaseColor),
        SizedBox(height: 30),
        Divider(),
        SizedBox(height: 10),
        _buildSection3(theme, neumoBaseColor),
        SizedBox(height: 30),
        Divider(),
        SizedBox(height: 10),
        _buildSection4(theme, neumoBaseColor),
        SizedBox(height: 30),
        _buildSubmitButton(theme),
      ],
    );
  }

  Widget _buildDesktopLayout(
    ThemeData theme,
    Color neumoBaseColor,
    List<dynamic> filteredDistricts,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection1(theme, neumoBaseColor, filteredDistricts),
              SizedBox(height: 30),
              Divider(),
              SizedBox(height: 10),
              _buildSection2(theme, neumoBaseColor),
            ],
          ),
        ),
        SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection3(theme, neumoBaseColor),
              SizedBox(height: 30),
              Divider(),
              SizedBox(height: 10),
              _buildSection4(theme, neumoBaseColor),
              SizedBox(height: 50),
              _buildSubmitButton(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection1(
    ThemeData theme,
    Color neumoBaseColor,
    List<dynamic> filteredDistricts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle("1. Leadership Assignment", theme),
        _buildSearchableSelector(
          currentValue: _selectedOverseerId,
          hint: "Select Overseer",
          items: _allOverseers,
          displayKey: 'overseer_initials_surname',
          baseColor: neumoBaseColor,
          onChanged: (val) {
            setState(() {
              _selectedOverseerId = val;
              _selectedDistrictId = null;
            });
          },
        ),
        SizedBox(height: 15),
        _buildSearchableSelector(
          currentValue: _selectedDistrictId,
          hint: _selectedOverseerId == null
              ? "Select Overseer First"
              : "Select District Elder",
          items: filteredDistricts,
          displayKey: 'district_elder_name',
          baseColor: neumoBaseColor,
          onChanged: _selectedOverseerId == null
              ? null
              : (val) {
                  setState(() => _selectedDistrictId = val);
                },
        ),
      ],
    );
  }

  Widget _buildSection2(ThemeData theme, Color neumoBaseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle("2. University Details", theme),
        _buildNeumorphicTextField(
          context: context,
          baseColor: neumoBaseColor,
          controller: universityNameController,
          placeholder: "University Name (e.g. UJ)",
          prefixIcon: isIOSPlatform
              ? CupertinoIcons.building_2_fill
              : Icons.school,
          validator: (v) => TextFieldValidation.name(v!),
        ),
        _buildNeumorphicTextField(
          context: context,
          baseColor: neumoBaseColor,
          controller: campusNameController,
          placeholder: "Campus Name",
          prefixIcon: isIOSPlatform
              ? CupertinoIcons.location_solid
              : Icons.location_on,
        ),
        _buildNeumorphicTextField(
          context: context,
          baseColor: neumoBaseColor,
          controller: applicationLinkController,
          placeholder: "Application Link",
          prefixIcon: isIOSPlatform ? CupertinoIcons.link : Icons.link,
        ),
        _buildNeumorphicTextField(
          context: context,
          baseColor: neumoBaseColor,
          controller: institutionAddressController,
          placeholder: "Physical Address",
          prefixIcon: isIOSPlatform
              ? CupertinoIcons.map_pin_ellipse
              : Icons.map,
        ),
        SizedBox(height: 10),
        _buildImagePicker(
          context,
          "University Logo",
          universityImageFile,
          (f) => setState(() => universityImageFile = f),
          neumoBaseColor,
        ),
        SizedBox(height: 10),
        NeumorphicContainer(
          isPressed: true,
          color: neumoBaseColor,
          borderRadius: 12,
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Is Application Open?", style: TextStyle(fontSize: 14)),
            trailing: Switch.adaptive(
              value: isApplicationOpen,
              activeColor: theme.primaryColor,
              onChanged: (v) => setState(() => isApplicationOpen = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection3(ThemeData theme, Color neumoBaseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle("3. Committee (Biometrics)", theme),
        _buildNeumorphicTextField(
          context: context,
          baseColor: neumoBaseColor,
          controller: educationOfficerNameController,
          placeholder: "Education Officer Full Name",
          prefixIcon: isIOSPlatform
              ? CupertinoIcons.person_solid
              : Icons.person,
        ),
        _buildImagePicker(
          context,
          "Officer Face",
          educationOfficerImageFile,
          (f) => setState(() => educationOfficerImageFile = f),
          neumoBaseColor,
          isBiometric: true,
        ),
        SizedBox(height: 15),
        _buildNeumorphicTextField(
          context: context,
          baseColor: neumoBaseColor,
          controller: chairpersonNameController,
          placeholder: "Chairperson Full Name",
          prefixIcon: isIOSPlatform
              ? CupertinoIcons.person_solid
              : Icons.person,
        ),
        _buildImagePicker(
          context,
          "Chairperson Face",
          chairpersonImageFile,
          (f) => setState(() => chairpersonImageFile = f),
          neumoBaseColor,
          isBiometric: true,
        ),
      ],
    );
  }

  Widget _buildSection4(ThemeData theme, Color neumoBaseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle("4. Branch Credentials", theme),
        _buildNeumorphicTextField(
          context: context,
          baseColor: neumoBaseColor,
          controller: emailController,
          placeholder: "Branch Email",
          prefixIcon: isIOSPlatform ? CupertinoIcons.mail_solid : Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        _buildNeumorphicTextField(
          context: context,
          baseColor: neumoBaseColor,
          controller: passwordController,
          placeholder: "Shared Password",
          prefixIcon: isIOSPlatform ? CupertinoIcons.lock_fill : Icons.lock,
          obscureText: _obscurePassword,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: theme.primaryColor.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return GestureDetector(
      onTap: _handleSubmit,
      child: NeumorphicContainer(
        color: theme.primaryColor,
        borderRadius: 10,
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            "CREATE BRANCH",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Text(
        title,
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildImagePicker(
    BuildContext context,
    String label,
    XFile? file,
    Function(XFile) onSet,
    Color baseColor, {
    bool isBiometric = false,
  }) {
    final theme = Theme.of(context);
    bool hasFile = file != null;
    return GestureDetector(
      onTap: () => _pickImage(onSet),
      child: NeumorphicContainer(
        color: baseColor,
        borderRadius: 12,
        isPressed: true,
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: hasFile
                    ? Colors.green.withOpacity(0.2)
                    : theme.disabledColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: hasFile
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.network(file.path, fit: BoxFit.cover)
                          : Image.file(io.File(file.path), fit: BoxFit.cover),
                    )
                  : Icon(
                      isBiometric ? Icons.face : Icons.image,
                      color: theme.primaryColor.withOpacity(0.5),
                    ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    hasFile ? "Face Captured" : "Tap to upload",
                    style: TextStyle(
                      fontSize: 12,
                      color: hasFile ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasFile ? Icons.check_circle : Icons.upload_rounded,
              color: hasFile ? Colors.green : theme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchableSelector({
    required String? currentValue,
    required String hint,
    required List<dynamic> items,
    required String displayKey,
    required Color baseColor,
    required Function(String?)? onChanged,
  }) {
    String displayString = hint;
    if (currentValue != null) {
      final match = items.firstWhere(
        (i) => i['id'].toString() == currentValue,
        orElse: () => null,
      );
      if (match != null) displayString = match[displayKey] ?? hint;
    }
    return GestureDetector(
      onTap: onChanged == null
          ? null
          : () {
              _showSearchableDialog(
                context: context,
                title: "Select Data",
                items: items,
                displayKey: displayKey,
                baseColor: baseColor,
                onSelected: (id) => onChanged(id),
              );
            },
      child: NeumorphicContainer(
        isPressed: false,
        borderRadius: 12,
        color: baseColor,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayString,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: currentValue == null
                      ? FontWeight.normal
                      : FontWeight.w600,
                  color: currentValue == null
                      ? Colors.grey[500]
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.search,
              size: 18,
              color: onChanged == null
                  ? Colors.grey[300]
                  : Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchableDialog({
    required BuildContext context,
    required String title,
    required List<dynamic> items,
    required String displayKey,
    required Color baseColor,
    required Function(String) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = items
                .where(
                  (item) => (item[displayKey] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()),
                )
                .toList();
            return Dialog(
              backgroundColor: baseColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: 400,
                ),
                child: Column(
                  children: [
                    NeumorphicContainer(
                      isPressed: true,
                      color: baseColor,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: TextField(
                        autofocus: true,
                        onChanged: (val) {
                          setDialogState(() {
                            searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Type to search...",
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.search,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Text(
                                "No results found",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredItems.length,
                              separatorBuilder: (context, index) => Divider(
                                color: Colors.grey.withOpacity(0.2),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  title: Text(
                                    item[displayKey] ?? 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onTap: () {
                                    onSelected(item['id'].toString());
                                    Navigator.pop(dialogContext);
                                  },
                                );
                              },
                            ),
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
}
