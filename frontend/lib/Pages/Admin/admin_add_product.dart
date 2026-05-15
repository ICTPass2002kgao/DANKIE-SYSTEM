// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'dart:convert'; // Added for JSON encoding
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io show File;
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart'; // ⭐️ IMPORT FIREBASE STORAGE
import 'package:path/path.dart' as path; // Useful for getting file extensions

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class AdminAddProduct extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;

  const AdminAddProduct({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<AdminAddProduct> createState() => _AdminAddProductState();
}

class _AdminAddProductState extends State<AdminAddProduct> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  List<XFile> imageFiles = [];

  final ImagePicker _picker = ImagePicker();
  final bool _isWeb = kIsWeb;

  // --- 1. State to track Item Type ---
  String _selectedType = 'Product';
  String _selectedCategory = '';

  // --- 2. Separate Category Lists ---
  final List<String> _productCategories = [
    'Shirts & Polos',
    'Suits & Jackets',
    'Trousers & Skirts',
    'Footwear',
    'Accessories',
    'Hats',
    'Shoes',
  ];

  final List<String> _serviceCategories = [
    'Transportation (Bus/Taxi)',
    'Tents & Marquees',
    'Sound System',
    'Mobile Toilets',
    'Chairs & Tables',
    'Catering & Food',
    'Decor & Flowers',
    'Photography & Video',
  ];

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles = picked;
      });
    }
  }

  // ⭐️ NEW: Function to upload a single file to Firebase and get URL
  Future<String?> uploadFileToFirebase(XFile file) async {
    try {
      // Create a unique filename
      String fileName =
          'products/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;

      if (_isWeb) {
        // For Web, we upload bytes
        final bytes = await file.readAsBytes();
        var metadata = SettableMetadata(contentType: file.mimeType);
        uploadTask = storageRef.putData(bytes, metadata);
      } else {
        // For Mobile, we upload from path
        uploadTask = storageRef.putFile(io.File(file.path));
      }

      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  Future<void> uploadItem() async {
    if (nameController.text.isEmpty ||
        descController.text.isEmpty ||
        _selectedCategory.isEmpty ||
        imageFiles.isEmpty) {
      Api().showMessage(
        context,
        'Missing Fields',
        'Please fill in name, description, category, and select at least one image.',
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);

    try {
      // 1. Upload Images to Firebase First
      List<String> uploadedImageUrls = [];

      for (var file in imageFiles) {
        String? url = await uploadFileToFirebase(file);
        if (url != null) {
          uploadedImageUrls.add(url);
        }
      }

      if (uploadedImageUrls.isEmpty) {
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Image upload failed',
          'Could not upload images to storage.',
          Colors.red,
        );
        return;
      }

      // 2. Prepare Data for Backend
      // We send a JSON body now, not Multipart
      Map<String, dynamic> productData = {
        'name': nameController.text.trim(),
        'description': descController.text.trim(),
        'category': _selectedCategory,
        'type': _selectedType,
        'image_url': uploadedImageUrls[0], // <--- The backend is rejecting this
        'images': uploadedImageUrls,
      };

      var uri = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/products/');

      // 3. Send JSON Post Request
      var response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization":
              "Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}",
        },
        body: jsonEncode(productData),
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading

      if (response.statusCode == 201 || response.statusCode == 200) {
        Api().showMessage(
          context,
          'Global Catalog Item Created!',
          'Success',
          Colors.green,
        );
        _clearForm();
      } else {
        print("Server Error: ${response.body}");
        Api().showMessage(
          context,
          'Failed to save to database. Status: ${response.statusCode}\n${response.body}',
          'Server Error',
          Colors.red,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      Api().showMessage(context, 'Error: ${e.toString()}', 'Error', Colors.red);
    }
  }

  void _clearForm() {
    nameController.clear();
    descController.clear();
    setState(() {
      imageFiles = [];
      _selectedCategory = '';
    });
  }

  // --- NEUMORPHIC TEXT FIELD HELPER ---
  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String placeholder,
    required Color baseColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: NeumorphicContainer(
        isPressed: true,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: baseColor,
        child: TextField(
          controller: controller,
          style: TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: theme.hintColor),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color baseColor = Color.alphaBlend(
      theme.scaffoldBackgroundColor,
      theme.primaryColor,
    );
    final primaryColor = theme.primaryColor;

    final currentCategories = _selectedType == 'Product'
        ? _productCategories
        : _serviceCategories;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Global Catalog Item', // Updated Title
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 20),

              // --- 4. Type Selector (Neumorphic Toggle) ---
              NeumorphicContainer(
                isPressed: true,
                borderRadius: 12,
                padding: EdgeInsets.all(4),
                color: baseColor,
                child: Row(
                  children: [
                    _buildTypeOption('Product', Icons.shopping_bag),
                    _buildTypeOption('Service', Icons.handyman),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // --- Image Picker (Neumorphic Inset Drop Zone) ---
              GestureDetector(
                onTap: () => pickImages(),
                child: NeumorphicContainer(
                  isPressed: true,
                  borderRadius: 16,
                  padding: EdgeInsets.zero,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            imageFiles.isNotEmpty
                                ? Icons.check_circle
                                : Icons.add_photo_alternate,
                            size: 45,
                            color: imageFiles.isNotEmpty
                                ? Colors.green
                                : primaryColor,
                          ),
                          SizedBox(height: 8),
                          Text(
                            imageFiles.isNotEmpty
                                ? '${imageFiles.length} Images Selected'
                                : 'Tap to upload ${_selectedType.toLowerCase()} images',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Image Preview
              if (imageFiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageFiles.length,
                      itemBuilder: (context, index) {
                        final file = imageFiles[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: NeumorphicContainer(
                            borderRadius: 12,
                            padding: EdgeInsets.all(2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _isWeb
                                  ? Container(
                                      width: 76,
                                      height: 76,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.image),
                                    )
                                  : Image.file(
                                      io.File(file.path),
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              SizedBox(height: 15),

              // --- Form Fields ---
              _buildNeumorphicTextField(
                baseColor: baseColor,
                controller: nameController,
                placeholder: _selectedType == 'Product'
                    ? 'Product Name (e.g. Navy Suit)'
                    : 'Service Name (e.g. 50-Seater Bus)',
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: NeumorphicContainer(
                  isPressed: false,
                  borderRadius: 12,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  color: baseColor,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value:
                          _selectedCategory.isNotEmpty &&
                              currentCategories.contains(_selectedCategory)
                          ? _selectedCategory
                          : null,
                      hint: Text(
                        "Select Category",
                        style: TextStyle(color: theme.hintColor),
                      ),
                      isExpanded: true,
                      dropdownColor: baseColor,
                      items: currentCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value ?? '';
                        });
                      },
                    ),
                  ),
                ),
              ),

              _buildNeumorphicTextField(
                baseColor: baseColor,
                controller: descController,
                placeholder: _selectedType == 'Product'
                    ? 'Description (Material, Size, etc.)'
                    : 'Description (Capacity, Terms, Features)',
              ),

              SizedBox(height: 30),

              GestureDetector(
                onTap: uploadItem,
                child: NeumorphicContainer(
                  isPressed: false,
                  borderRadius: 12,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  color: baseColor,
                  child: Center(
                    child: Text(
                      "Add to Global Catalog", // Updated text
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, IconData icon) {
    final isSelected = _selectedType == type;
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final baseColor = Color.alphaBlend(
      theme.scaffoldBackgroundColor,
      theme.primaryColor,
    );

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedCategory = '';
          });
        },
        child: NeumorphicContainer(
          isPressed: !isSelected,
          borderRadius: 10,
          padding: EdgeInsets.symmetric(vertical: 12),
          color: isSelected ? baseColor : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? primaryColor : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                type,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
