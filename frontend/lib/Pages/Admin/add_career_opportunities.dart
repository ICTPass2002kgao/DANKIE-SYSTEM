// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class AddCareerOpportunities extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const AddCareerOpportunities({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<AddCareerOpportunities> createState() => _AddCareerOpportunitiesState();
}

class _AddCareerOpportunitiesState extends State<AddCareerOpportunities>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- State Variables for Logic ---
  String? _editingId;
  bool _isLoading = false;

  // --- Image State (Web & Mobile Compatible) ---
  XFile? _pickedImage;
  Uint8List? _imageBytes; // For Web display and upload
  String? _existingImageUrl;

  // --- Application Form State (Z83 etc) ---
  PlatformFile? _pickedAppForm; // From file_picker
  Uint8List? _appFormBytes; // For upload
  String? _existingAppFormUrl;
  String? _existingAppFormName; // To show name if editing

  // --- Controllers (Standard) ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // --- Controllers (Contact & Physical) ---
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // --- Controllers (Single Field Details) ---
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _financialController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // --- Controllers (Dynamic Lists) ---
  final TextEditingController _reqInputController = TextEditingController();
  final TextEditingController _dutyInputController = TextEditingController();
  final TextEditingController _courseInputController = TextEditingController();
  final TextEditingController _customDocController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  // --- Lists Data ---
  List<String> _requirementsList = [];
  List<String> _dutiesList = [];
  List<String> _coursesList = [];
  List<String> _customDocumentsList = [];

  // --- Date State ---
  DateTime? _expiryDate;
  String _selectedCategory = 'Bursary';

  // --- UPDATED: Added In-Service Training ---
  final List<String> _categories = [
    'Bursary',
    'Scholarship',
    'Internship',
    'In-Service Training',
    'Job',
    'Learnership',
  ];

  // Standard Document Defaults - UPDATED with In-Service Training
  final Map<String, List<String>> _defaultDocsByCategory = {
    'Bursary': [
      'Certified ID Copy',
      'Matric Certificate/Results',
      'Full Academic Record',
      'Proof of Residence',
      'Proof of income',
    ],
    'Scholarship': [
      'Certified ID Copy',
      'Full Academic Record',
      'Motivation Letter',
      'Curriculum Vitae (CV)',
    ],
    'Internship': [
      'Curriculum Vitae (CV)',
      'Certified ID Copy',
      'Full Academic Record',
      'Letter from Institution',
    ],
    'In-Service Training': [
      'Curriculum Vitae (CV)',
      'Certified ID Copy',
      'Full Academic Record',
      'Letter from Institution (WIL)',
      'Matric Certificate',
    ],
    'Job': [
      'Curriculum Vitae (CV)',
      'Certified ID Copy',
      'Matric Certificate/Results',
    ],
    'Learnership': [
      'Curriculum Vitae (CV)',
      'Certified ID Copy',
      'Matric Certificate/Results',
      'Proof of Residence',
    ],
  };

  final List<String> _commonDocuments = [
    'Certified ID Copy',
    'Curriculum Vitae (CV)',
    'Matric Certificate/Results',
    'Full Academic Record',
    'Proof of Residence',
    'Motivation Letter',
    'Parents/Guardians Proof of Income',
    'Proof of Registration',
    '3 Months Bank Statements',
    'Letter from Institution',
    'Driver\'s License',
  ];

  List<String> _selectedStandardDocuments = [];

  final List<String> _bursaryBenefitsOptions = [
    'Tuition Fees',
    'Accommodation',
    'Meals',
    'Textbooks',
    'Laptop',
    'Monthly Allowance',
    'Transport',
  ];
  final List<String> _selectedBenefits = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedStandardDocuments = List.from(_defaultDocsByCategory['Bursary']!);

    _tabController.addListener(() {
      if (_tabController.index == 0 &&
          _tabController.previousIndex == 1 &&
          !_tabController.indexIsChanging) {}
    });
  }

  void _populateFormForEditing(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Map<String, dynamic> details = data['details'] ?? {};

    setState(() {
      _editingId = doc.id;

      _selectedCategory = data['category'] ?? 'Bursary';
      _titleController.text = data['title'] ?? '';
      _linkController.text = data['link'] ?? '';
      _emailController.text = data['applicationEmail'] ?? '';
      _existingImageUrl = data['imageUrl'];
      _instructionsController.text = data['instructions'] ?? '';
      _existingAppFormUrl = data['applicationFormUrl'];
      _existingAppFormName = _existingAppFormUrl != null
          ? "Current Form (Attached)"
          : null;
      if (data['expiryDate'] != null) {
        _expiryDate = (data['expiryDate'] as Timestamp).toDate();
      } else {
        _expiryDate = null;
      }
      List<dynamic> allDocs = data['requiredDocuments'] ?? [];
      _selectedStandardDocuments.clear();
      _customDocumentsList.clear();

      for (var d in allDocs) {
        if (_commonDocuments.contains(d) ||
            _defaultDocsByCategory.values.any((list) => list.contains(d))) {
          if (!_selectedStandardDocuments.contains(d))
            _selectedStandardDocuments.add(d.toString());
        } else {
          _customDocumentsList.add(d.toString());
        }
      }

      // Details
      _subtitleController.text = details['subtitle'] ?? '';
      _financialController.text = details['financial'] ?? '';
      _durationController.text = details['duration'] ?? '';
      _locationController.text = details['location'] ?? '';
      _addressController.text = details['address'] ?? '';
      _phoneController.text = details['contactNumber'] ?? '';

      // Lists
      _selectedBenefits.clear();
      if (details['benefits'] != null) {
        _selectedBenefits.addAll(List<String>.from(details['benefits']));
      }

      _requirementsList = List<String>.from(details['requirementsList'] ?? []);
      _dutiesList = List<String>.from(details['dutiesList'] ?? []);
      _coursesList = List<String>.from(details['coursesList'] ?? []);

      // Switch Tab
      _tabController.animateTo(0);
    });
  }

  // --- Logic: Category Changed ---
  void _onCategoryChanged(String newCategory) {
    setState(() {
      _selectedCategory = newCategory;
      if (_editingId == null) {
        _selectedStandardDocuments = List.from(
          _defaultDocsByCategory[newCategory] ?? [],
        );
        _selectedBenefits.clear();
      }
    });
  }

  // --- Logic: Add/Remove List Items ---
  void _addItemToList(
    TextEditingController controller,
    List<String> targetList,
  ) {
    if (controller.text.trim().isNotEmpty) {
      setState(() {
        targetList.add(controller.text.trim());
        controller.clear();
      });
    }
  }

  void _removeItemFromList(String item, List<String> targetList) {
    setState(() {
      targetList.remove(item);
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedImage = picked;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _pickAppForm() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        Uint8List? fileBytes = file.bytes;
        if (fileBytes == null && file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes != null) {
          setState(() {
            _pickedAppForm = file;
            _appFormBytes = fileBytes;
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking document: $e");
    }
  }

  void _removeAppForm() {
    setState(() {
      _pickedAppForm = null;
      _appFormBytes = null;
    });
  }

  // --- Logic: Toggles ---
  void _toggleStandardDoc(String doc) {
    setState(() {
      _selectedStandardDocuments.contains(doc)
          ? _selectedStandardDocuments.remove(doc)
          : _selectedStandardDocuments.add(doc);
    });
  }

  void _toggleBenefit(String benefit) {
    setState(() {
      _selectedBenefits.contains(benefit)
          ? _selectedBenefits.remove(benefit)
          : _selectedBenefits.add(benefit);
    });
  }

  // --- Logic: Upload / Update ---
  Future<void> _submitData() async {
    if (_titleController.text.isEmpty) {
      _showPlatformAlert("Missing Info", "Title is required.");
      return;
    }
    List<String> finalDocs = [
      ..._selectedStandardDocuments,
      ..._customDocumentsList,
    ];

    setState(() => _isLoading = true);

    try {
      // 1. Image Upload
      String imageUrl = _existingImageUrl ?? "";
      if (_imageBytes != null && _pickedImage != null) {
        String fileName = path.basename(_pickedImage!.name);
        String uniqueName =
            "${DateTime.now().millisecondsSinceEpoch}_$fileName";
        Reference ref = FirebaseStorage.instance.ref().child(
          'career_images/$uniqueName',
        );
        UploadTask task = ref.putData(
          _imageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        await task;
        imageUrl = await ref.getDownloadURL();
      }

      String? appFormUrl = _existingAppFormUrl;
      if (_appFormBytes != null && _pickedAppForm != null) {
        String fileName = _pickedAppForm!.name;
        String uniqueName =
            "${DateTime.now().millisecondsSinceEpoch}_$fileName";
        Reference ref = FirebaseStorage.instance.ref().child(
          'career_forms/$uniqueName',
        );
        UploadTask task = ref.putData(_appFormBytes!);
        await task;
        appFormUrl = await ref.getDownloadURL();
      }

      Map<String, dynamic> specificDetails = {
        'subtitle': _subtitleController.text.trim(),
        'financial': _financialController.text.trim(),
        'duration': _durationController.text.trim(),
        'location': _locationController.text.trim(),
        'benefits': _selectedBenefits,
        'requirementsList': _requirementsList,
        'dutiesList': _dutiesList,
        'coursesList': _coursesList,
        'address': _addressController.text.trim(),
        'contactNumber': _phoneController.text.trim(),
      };

      Map<String, dynamic> mainData = {
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'link': _linkController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'applicationEmail': _emailController.text.trim(),
        'imageUrl': imageUrl,
        'applicationFormUrl': appFormUrl,
        'requiredDocuments': finalDocs,
        'details': specificDetails,
        'expiryDate': _expiryDate != null
            ? Timestamp.fromDate(_expiryDate!)
            : null,
        'isActive': true,
      };

      if (_editingId != null) {
        // UPDATE Existing
        mainData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('career_opportunities')
            .doc(_editingId)
            .update(mainData);
        if (mounted)
          _showPlatformAlert("Success", "Opportunity Updated Successfully!");
      } else {
        // CREATE New
        mainData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('career_opportunities')
            .add(mainData);
        if (mounted) _showPlatformAlert("Success", "Opportunity Published!");
      }

      if (mounted) {
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showPlatformAlert("Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _linkController.clear();
    _emailController.clear();
    _addressController.clear();
    _phoneController.clear();
    _subtitleController.clear();
    _financialController.clear();
    _durationController.clear();
    _locationController.clear();
    _instructionsController.clear();

    _reqInputController.clear();
    _dutyInputController.clear();
    _courseInputController.clear();
    _customDocController.clear();

    setState(() {
      _editingId = null;
      _existingImageUrl = null;
      _existingAppFormUrl = null;
      _existingAppFormName = null;

      _pickedImage = null;
      _imageBytes = null;

      _pickedAppForm = null;
      _appFormBytes = null;

      _expiryDate = null;
      _selectedCategory = 'Bursary';
      _selectedStandardDocuments = List.from(
        _defaultDocsByCategory['Bursary']!,
      );
      _selectedBenefits.clear();
      _requirementsList.clear();
      _dutiesList.clear();
      _coursesList.clear();
      _customDocumentsList.clear();
    });
  }

  Future<void> _deleteOpportunity(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('career_opportunities')
          .doc(docId)
          .delete();
      _showPlatformAlert("Deleted", "Opportunity removed.");
    } catch (e) {
      _showPlatformAlert("Error", "Could not delete: $e");
    }
  }

  void _showPlatformAlert(String title, String message) {
    Api().showMessage(
      context,
      message,
      title,
      _editingId != null ? Colors.blue : Colors.green,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  // --- NEUMORPHIC TEXT FIELD HELPER ---
  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String placeholder,
    IconData? icon,
    bool isIos = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;

    // Inset (Sunken) Neumorphic Container for Inputs
    return NeumorphicContainer(
      isPressed: true,
      borderRadius: 12,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: baseColor,
      child: isIos
          ? CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              padding: const EdgeInsets.symmetric(vertical: 12),
              keyboardType: keyboardType,
              prefix: icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        icon,
                        color: CupertinoColors.systemGrey,
                        size: 20,
                      ),
                    )
                  : null,
              decoration: null, // Remove default decoration
            )
          : TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: theme.hintColor),
                icon: icon != null
                    ? Icon(icon, size: 20, color: theme.hintColor)
                    : null,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final primaryColor = Theme.of(context).primaryColor;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor, // Ensure base color matches
      body: Column(
        children: [
          // Neumorphic Tab Bar Container
          NeumorphicContainer(
            borderRadius: 0, // Flat bottom/top for tabs usually
            padding: EdgeInsets.zero,
            color: theme.scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.add_box), text: "Post / Edit"),
                Tab(icon: Icon(Icons.list), text: "Manage All"),
              ],
            ),
          ),

          if (_editingId != null)
            Container(
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Editing Mode", style: TextStyle(color: Colors.blue)),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.blue),
                    tooltip: "Cancel Edit",
                    onPressed: _clearForm,
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFormTab(isIos, primaryColor),
                _buildListTab(primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: The Form
  // ==========================================
  Widget _buildFormTab(bool isIos, Color primaryColor) {
    final theme = Theme.of(context);

    return _isLoading
        ? const Center(child: CircularProgressIndicator.adaptive())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Image Banner (Neumorphic Inset)
                GestureDetector(
                  onTap: _pickImage,
                  child: NeumorphicContainer(
                    isPressed: true, // Sunken
                    borderRadius: 12,
                    padding: EdgeInsets.zero,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image:
                            (_imageBytes == null && _existingImageUrl != null)
                            ? DecorationImage(
                                image: NetworkImage(_existingImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : (_existingImageUrl == null)
                          ? Center(
                              child: Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Category Selector
                Text(
                  "Category",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(
                          right: 12.0,
                          bottom: 8.0,
                        ),
                        child: GestureDetector(
                          onTap: () => _onCategoryChanged(cat),
                          child: NeumorphicContainer(
                            isPressed: isSelected, // Sunken if selected
                            borderRadius: 20,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: isSelected
                                ? primaryColor.withOpacity(0.1)
                                : theme.scaffoldBackgroundColor,
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: isSelected
                                    ? primaryColor
                                    : Colors.grey[600],
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Main Title
                _buildNeumorphicTextField(
                  controller: _titleController,
                  placeholder: _getLabelForTitle(),
                  icon: Icons.title,
                  isIos: isIos,
                ),
                const SizedBox(height: 16),

                // 4. Application Form Upload Section (New)
                Text(
                  "Attachments",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                NeumorphicContainer(
                  borderRadius: 12,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.description, color: Colors.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Application Form (Z83 / Other)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (_pickedAppForm != null)
                              Text(
                                "Selected: ${_pickedAppForm!.name}",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              )
                            else if (_existingAppFormUrl != null)
                              Text(
                                "$_existingAppFormName",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                ),
                              )
                            else
                              Text(
                                "No file selected",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_pickedAppForm != null || _existingAppFormUrl != null)
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            _removeAppForm();
                          },
                        ),

                      // Upload Button (Neumorphic)
                      GestureDetector(
                        onTap: _pickAppForm,
                        child: NeumorphicContainer(
                          isPressed: false,
                          borderRadius: 8,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            "Upload",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Expiry Date
                NeumorphicContainer(
                  borderRadius: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          _expiryDate == null
                              ? "Open / No Closing Date"
                              : "Closes: ${DateFormat('yyyy-MM-dd').format(_expiryDate!)}",
                          style: TextStyle(
                            color: _expiryDate == null
                                ? Colors.green
                                : Colors.black87,
                            fontWeight: _expiryDate == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (_expiryDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () =>
                                  setState(() => _expiryDate = null),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.calendar_today,
                              color: primaryColor,
                            ),
                            onPressed: () => _selectDate(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Dynamic Fields
                ..._buildCategorySpecificFields(isIos, primaryColor),

                // 7. Application Method
                const SizedBox(height: 20),
                Text(
                  "Application & Contact Details",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildNeumorphicTextField(
                        controller: _linkController,
                        placeholder: "Web Link",
                        icon: Icons.link,
                        isIos: isIos,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildNeumorphicTextField(
                        controller: _emailController,
                        placeholder: "Email",
                        icon: Icons.email,
                        isIos: isIos,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildNeumorphicTextField(
                  controller: _phoneController,
                  placeholder: "Contact Number",
                  icon: Icons.phone,
                  isIos: isIos,
                  keyboardType: TextInputType.phone,
                ),

                // 8. Documents Checklist
                const SizedBox(height: 20),
                Text(
                  "Required Documents Checklist",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                _buildNeumorphicTextField(
                  controller: _instructionsController,
                  placeholder: "Application Instructions (optional)",
                  icon: Icons.map,
                  isIos: isIos,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _commonDocuments.map((doc) {
                    final isSelected = _selectedStandardDocuments.contains(doc);
                    return GestureDetector(
                      onTap: () => _toggleStandardDoc(doc),
                      child: NeumorphicContainer(
                        isPressed: isSelected,
                        borderRadius: 20,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: isSelected
                            ? primaryColor.withOpacity(0.1)
                            : theme.scaffoldBackgroundColor,
                        child: Text(
                          doc,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? primaryColor : Colors.grey[600],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _buildDynamicListSection(
                  title: "Custom Documents",
                  placeholder: "e.g. Skipper License",
                  controller: _customDocController,
                  targetList: _customDocumentsList,
                  isIos: isIos,
                  primaryColor: primaryColor,
                ),

                const SizedBox(height: 30),

                // Submit Button (Neumorphic Popped)
                GestureDetector(
                  onTap: _submitData,
                  child: NeumorphicContainer(
                    isPressed: false,
                    borderRadius: 12,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    // For the main action, we can use primary color background logic if desired,
                    // but strict neomorphism uses same color. Let's use primary text/icon.
                    child: Center(
                      child: Text(
                        _editingId != null
                            ? "Update Opportunity"
                            : "Publish Opportunity",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
  }

  // ==========================================
  // TAB 2: Manage List
  // ==========================================
  Widget _buildListTab(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('career_opportunities')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Error loading data"));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(child: Text("No opportunities posted yet."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            String expiryText = "Open / Ongoing";
            bool isExpired = false;
            if (data['expiryDate'] != null) {
              DateTime exp = (data['expiryDate'] as Timestamp).toDate();
              expiryText = DateFormat('dd MMM yyyy').format(exp);
              if (exp.isBefore(DateTime.now())) isExpired = true;
            }

            // Neumorphic List Item
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: NeumorphicContainer(
                borderRadius: 16,
                padding: EdgeInsets.all(12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      image:
                          (data['imageUrl'] != null && data['imageUrl'] != "")
                          ? DecorationImage(
                              image: NetworkImage(data['imageUrl']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (data['imageUrl'] == null || data['imageUrl'] == "")
                        ? const Icon(Icons.work)
                        : null,
                  ),
                  title: Text(
                    data['title'] ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${data['category']}  •  Expires: $expiryText",
                    style: TextStyle(
                      color: isExpired ? Colors.red : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit')
                        _populateFormForEditing(doc);
                      else if (value == 'delete')
                        _deleteOpportunity(doc.id);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text("Edit")),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper: Dynamic Labels ---
  String _getLabelForTitle() {
    switch (_selectedCategory) {
      case 'Job':
        return "Job Title";
      case 'Internship':
        return "Role Title";
      case 'In-Service Training':
        return "Training Program Title";
      case 'Learnership':
        return "Programme Name";
      default:
        return "Opportunity Title";
    }
  }

  // --- Helper: Dynamic Fields Builder ---
  List<Widget> _buildCategorySpecificFields(bool isIos, Color primaryColor) {
    List<Widget> fields = [];

    if (_selectedCategory == 'Bursary' || _selectedCategory == 'Scholarship') {
      fields.add(
        _buildDynamicListSection(
          title: "Courses / Fields of Study",
          placeholder: "Add field (e.g. Engineering)",
          controller: _courseInputController,
          targetList: _coursesList,
          isIos: isIos,
          primaryColor: primaryColor,
        ),
      );
    } else {
      String subPlace = _selectedCategory == 'Learnership'
          ? "Qualification Level"
          : "Company Name";
      fields.add(
        _buildNeumorphicTextField(
          controller: _subtitleController,
          placeholder: subPlace,
          icon: Icons.business,
          isIos: isIos,
        ),
      );
    }
    fields.add(const SizedBox(height: 16));

    if (_selectedCategory != 'Bursary' && _selectedCategory != 'Scholarship') {
      fields.add(
        Row(
          children: [
            Expanded(
              child: _buildNeumorphicTextField(
                controller: _financialController,
                placeholder: _selectedCategory == 'Job' ? "Salary" : "Stipend",
                icon: Icons.money,
                isIos: isIos,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildNeumorphicTextField(
                controller: _locationController,
                placeholder: "Location",
                icon: Icons.location_on,
                isIos: isIos,
              ),
            ),
          ],
        ),
      );
      fields.add(const SizedBox(height: 16));
    }

    fields.add(
      _buildDynamicListSection(
        title: "Requirements",
        placeholder: "Add requirement...",
        controller: _reqInputController,
        targetList: _requirementsList,
        isIos: isIos,
        primaryColor: primaryColor,
      ),
    );
    fields.add(const SizedBox(height: 16));

    if (_selectedCategory == 'Bursary' || _selectedCategory == 'Scholarship') {
      fields.add(
        Text(
          "What it Covers",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      );
      fields.add(
        Wrap(
          spacing: 6,
          children: _bursaryBenefitsOptions.map((benefit) {
            final isSelected = _selectedBenefits.contains(benefit);
            return FilterChip(
              label: Text(benefit),
              selected: isSelected,
              onSelected: (_) => _toggleBenefit(benefit),
              selectedColor: Colors.green.withOpacity(0.2),
              checkmarkColor: Colors.green,
            );
          }).toList(),
        ),
      );
      fields.add(const SizedBox(height: 16));
    }

    if (_selectedCategory == 'Internship' ||
        _selectedCategory == 'Learnership' ||
        _selectedCategory == 'Bursary' ||
        _selectedCategory == 'In-Service Training') {
      fields.add(
        _buildNeumorphicTextField(
          controller: _durationController,
          placeholder: "Duration",
          icon: Icons.timer,
          isIos: isIos,
        ),
      );
      fields.add(const SizedBox(height: 16));
    }

    String dutyTitle = "Duties / Responsibilities";
    if (_selectedCategory == 'Learnership') dutyTitle = "Modules / Syllabus";
    if (_selectedCategory == 'Bursary') dutyTitle = "Additional Info";

    fields.add(
      _buildDynamicListSection(
        title: dutyTitle,
        placeholder: "Add item...",
        controller: _dutyInputController,
        targetList: _dutiesList,
        isIos: isIos,
        primaryColor: primaryColor,
      ),
    );

    return fields;
  }

  Widget _buildDynamicListSection({
    required String title,
    required String placeholder,
    required TextEditingController controller,
    required List<String> targetList,
    required bool isIos,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildNeumorphicTextField(
                controller: controller,
                placeholder: placeholder,
                icon: Icons.add_circle_outline,
                isIos: isIos,
              ),
            ),
            const SizedBox(width: 8),

            // Add Button (Neumorphic)
            GestureDetector(
              onTap: () => _addItemToList(controller, targetList),
              child: NeumorphicContainer(
                isPressed: false,
                borderRadius: 8,
                padding: EdgeInsets.all(10),
                child: Icon(Icons.add, color: primaryColor, size: 20),
              ),
            ),
          ],
        ),
        if (targetList.isNotEmpty)
          NeumorphicContainer(
            isPressed: true, // Inset background for list
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(vertical: 8),
            //color: Colors.grey[100],
            child: Column(
              children: targetList.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item, style: const TextStyle(fontSize: 13)),
                      ),
                      InkWell(
                        onTap: () => _removeItemFromList(item, targetList),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red[300],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
