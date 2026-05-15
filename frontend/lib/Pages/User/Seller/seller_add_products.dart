// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';
import 'package:ttact/Pages/User/Seller/seller_verification.dart';

class SellerAddProductTab extends StatefulWidget {
  final String userId;
  final bool isVerified;
  final Map<String, dynamic> userData;
  final VoidCallback? onSaveSuccess;

  const SellerAddProductTab({
    super.key,
    required this.userId,
    required this.isVerified,
    required this.userData,
    this.onSaveSuccess,
  });

  @override
  State<SellerAddProductTab> createState() => _SellerAddProductTabState();
}

class _SellerAddProductTabState extends State<SellerAddProductTab> {
  final priceController = TextEditingController();
  final locationController = TextEditingController();

  List<String> _selectedColors = [];
  List<String> _selectedSizes = [];

  final List<String> _colors = [
    'Black',
    'White',
    'Grey',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Navy',
    'Maroon',
  ];
  final List<String> _sizesStd = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'];

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Uint8List? _idDocumentBytes;
  String? _idDocumentName;

  Uint8List? _faceImageBytes;
  String? _faceImageName;

  bool _isUploadingFiles = false;

  // ⭐️ NEW: Legal Consent Tracker
  bool _agreedToPopiaAndContract = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill location with user's stored address on initialization
    locationController.text = widget.userData['address'] ?? '';
  }

  Future<List<dynamic>> fetchGlobalProducts() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      String? token = await user.getIdToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/products/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          return data['results'];
        } else if (data is List) {
          return data;
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<void> addProductToInventory(String productId) async {
    if (priceController.text.isEmpty || locationController.text.isEmpty) {
      Api().showMessage(
        context,
        "Please fill Price & Location",
        "Missing Info",
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");
      String? token = await user.getIdToken();
      if (token == null) throw Exception("Token retrieval failed");

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/seller-inventory/',
      );

      final Map<String, dynamic> body = {
        "product_id": productId,
        "seller_uid": widget.userId,
        "price": double.parse(priceController.text),
        "location": locationController.text,
        "seller_colors": _selectedColors,
        "seller_sizes": _selectedSizes,
      };

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(body),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 201) {
        Navigator.pop(context);
        _clearForm();
        if (widget.onSaveSuccess != null) {
          widget.onSaveSuccess!();
        } else {
          Api().showMessage(
            context,
            "Product published!",
            "Success",
            Colors.green,
          );
        }
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        String errorString = errorData.toString();
        if (errorString.contains("unique set") ||
            errorString.contains("already exists")) {
          Api().showMessage(
            context,
            "You have already listed this product.\nGo to 'Items' tab to edit it.",
            "Already Listed",
            Colors.orange,
          );
        } else {
          Api().showMessage(
            context,
            "Validation Error: $errorData",
            "Error",
            Colors.red,
          );
        }
      } else {
        Api().showMessage(
          context,
          "Server Error: ${response.statusCode}",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      Api().showMessage(context, "Connection Error: $e", "Error", Colors.red);
    }
  }

  void _clearForm() {
    priceController.clear();
    // Keep the location populated with the user's address when form resets
    locationController.text = widget.userData['address'] ?? '';
    setState(() {
      _selectedColors = [];
      _selectedSizes = [];
    });
  }

  Future<void> _pickIdDocument() async {
    if (!_agreedToPopiaAndContract) {
      Api().showMessage(
        context,
        "You must agree to the POPIA Data consent and Contract Terms first.",
        "Action Required",
        Colors.orange,
      );
      return;
    }
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _idDocumentBytes = result.files.single.bytes;
        _idDocumentName = result.files.single.name;
      });
    }
  }

  Future<void> _pickFaceImage() async {
    if (!_agreedToPopiaAndContract) {
      Api().showMessage(
        context,
        "You must agree to the POPIA Data consent and Contract Terms first.",
        "Action Required",
        Colors.orange,
      );
      return;
    }
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _faceImageBytes = bytes;
        _faceImageName = image.name;
      });
    }
  }

  Future<void> _submitVerification() async {
    if (!_agreedToPopiaAndContract) {
      Api().showMessage(
        context,
        "Please agree to the POPIA & Contract terms before proceeding.",
        "Consent Required",
        Colors.red,
      );
      return;
    }
    if (_signatureController.isEmpty) {
      Api().showMessage(
        context,
        "Please sign the digital contract.",
        "Missing Signature",
        Colors.red,
      );
      return;
    }
    if (_idDocumentBytes == null) {
      Api().showMessage(
        context,
        "Please upload your ID document.",
        "Missing ID",
        Colors.red,
      );
      return;
    }
    if (_faceImageBytes == null) {
      Api().showMessage(
        context,
        "Please upload a clear face image.",
        "Missing Face",
        Colors.red,
      );
      return;
    }

    setState(() {
      _isUploadingFiles = true;
    });

    try {
      final Uint8List? signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null)
        throw Exception("Failed to process signature.");

      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/users/${widget.userId}/submit_verification/',
        ),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        http.MultipartFile.fromBytes(
          'signature',
          signatureBytes,
          filename: 'signature.png',
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'id_document',
          _idDocumentBytes!,
          filename: _idDocumentName ?? 'id_doc.pdf',
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'face_image',
          _faceImageBytes!,
          filename: _faceImageName ?? 'face.jpg',
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseData);
        String faceUrl = jsonResponse['face_image_url'];

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SellerFaceVerificationScreen(
              entityUid: widget.userId,
              referenceFaceUrl: faceUrl,
              fullName:
                  "${widget.userData['name']} ${widget.userData['surname']}",
              onVerificationSuccess: () {
                _markAsPendingAdminReview();
              },
            ),
          ),
        );
      } else {
        throw Exception("Failed to update profile details: $responseData");
      }
    } catch (e) {
      Api().showMessage(context, e.toString(), "Upload Error", Colors.red);
    } finally {
      setState(() {
        _isUploadingFiles = false;
      });
    }
  }

  Future<void> _markAsPendingAdminReview() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();
      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/${widget.userId}/',
      );
      await http.patch(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({"verification_status": "Pending Review"}),
      );
      if (mounted) {
        setState(() {
          widget.userData['verification_status'] = 'Pending Review';
        });
        Navigator.pop(context);
        Api().showMessage(
          context,
          "Live verification passed. Awaiting Admin Approval.",
          "Success",
          Colors.green,
        );
      }
    } catch (e) {
      print(e);
    }
  }

  // ⭐️ NEW: Contract Preview UI
  Widget _buildContractPreview(String fullName, ThemeData theme) {
    return Container(
      height: 250,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(-5, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TERMS OF AGREEMENT AND STRICT FRAUD LIABILITY",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "I, $fullName, hereby acknowledge and legally bind myself to the following conditions of operating as a verified seller on the Dankie Platform:",
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            _contractClause(
              "1. GUARANTEE OF SERVICE:",
              "I declare under penalty of perjury that I possess the goods and services I am listing. I commit to fulfilling all orders placed and paid for by customers promptly.",
            ),
            _contractClause(
              "2. FRAUD AND SCAM ACCOUNTABILITY:",
              "I understand that listing phantom products, failing to deliver paid goods, or engaging in any form of scam is a direct violation of the law. Should I fail to provide the promised service, I accept full legal and financial liability.",
            ),
            _contractClause(
              "3. PLATFORM RIGHTS & LAW ENFORCEMENT:",
              "The platform reserves the right to immediately suspend my account, freeze payouts, and hand over my provided ID Document, Face Image, and this digitally signed contract to law enforcement agencies in the event of fraud.",
            ),
            _contractClause(
              "4. REIMBURSEMENT & RECOVERY:",
              "In the event of a dispute where I am found at fault, I authorize the platform to deduct funds from my Paystack subaccount or pursue legal channels to reimburse the affected parties without prior notice.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _contractClause(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: "$title ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationForm() {
    final theme = Theme.of(context);
    final String fullName =
        "${widget.userData['name'] ?? ''} ${widget.userData['surname'] ?? ''}"
            .trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Seller Verification Setup",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "To maintain platform security, all sellers must legally bind themselves to the service agreement and provide encrypted verification documents.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),

          // ⭐️ LEGAL PREVIEW
          Text(
            "1. Review Legal Contract",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _buildContractPreview(fullName, theme),
          const SizedBox(height: 20),

          // ⭐️ POPIA & FRAUD DISCLAIMER TOGGLE
          Container(
            padding: EdgeInsets.all(15),
            decoration: NeumorphicUtils.decoration(
              context: context,
              isPressed: _agreedToPopiaAndContract,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _agreedToPopiaAndContract,
                  activeColor: Colors.green,
                  onChanged: (val) {
                    setState(() {
                      _agreedToPopiaAndContract = val ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    "POPIA CONSENT: I explicitly consent to the encrypted storage of my ID and Biometric data. I acknowledge this data is collected strictly for fraud-prevention and will be handed over to law enforcement if I breach the contract above.",
                    style: TextStyle(
                      fontSize: 10,
                      color: _agreedToPopiaAndContract
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontWeight: _agreedToPopiaAndContract
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          Text(
            "2. Digital Signature",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(15),
            decoration: NeumorphicUtils.decoration(
              context: context,
              isPressed: true,
            ),
            child: Column(
              children: [
                Text(
                  "By signing below, I, $fullName, agree that this electronic signature holds the exact same legal weight as a physical handwritten signature.",
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Signature(
                    controller: _signatureController,
                    height: 150,
                    backgroundColor: Colors.grey[200]!,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _signatureController.clear(),
                    child: Text(
                      "Clear Signature",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          Text(
            "3. Upload ID Document",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickIdDocument,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: NeumorphicUtils.decoration(context: context),
              child: Column(
                children: [
                  Icon(
                    Icons.badge,
                    size: 40,
                    color: _agreedToPopiaAndContract
                        ? theme.primaryColor
                        : Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _idDocumentBytes != null
                        ? "ID Selected: $_idDocumentName"
                        : "Tap to Upload ID (PDF/Image)",
                    style: TextStyle(
                      color: _idDocumentBytes != null
                          ? Colors.green
                          : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          Text(
            "4. Upload Reference Face Image",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickFaceImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: NeumorphicUtils.decoration(context: context),
              child: Column(
                children: [
                  Icon(
                    Icons.face,
                    size: 40,
                    color: _agreedToPopiaAndContract
                        ? theme.primaryColor
                        : Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _faceImageBytes != null
                        ? "Face Image Selected"
                        : "Tap to Upload Face Image",
                    style: TextStyle(
                      color: _faceImageBytes != null
                          ? Colors.green
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          _isUploadingFiles
              ? Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: _submitVerification,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: NeumorphicUtils.decoration(context: context)
                        .copyWith(
                          color: _agreedToPopiaAndContract
                              ? theme.primaryColor
                              : Colors.grey,
                        ),
                    child: const Center(
                      child: Text(
                        "NEXT: Live Face Match",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVerified) {
      final String verificationStatus =
          widget.userData['verification_status'] ?? 'Unverified';

      if (verificationStatus == 'Pending Review') {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top, size: 60, color: Colors.orange),
              SizedBox(height: 20),
              Text(
                "Pending Admin Approval",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "Your identity documents have been submitted securely and are waiting for admin review.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return _buildVerificationForm();
    }

    return FutureBuilder<List<dynamic>>(
      future: fetchGlobalProducts(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Text("Error loading catalog: ${snapshot.error}"),
          );
        final products = snapshot.data ?? [];
        if (products.isEmpty)
          return const Center(child: Text("Global Catalog is empty."));

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            final crossAxisCount = isDesktop ? 3 : 1;

            if (isDesktop) {
              return GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 3.5,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                ),
                itemCount: products.length,
                itemBuilder: (c, i) => _buildAddCard(products[i], i),
              );
            } else {
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: products.length,
                itemBuilder: (c, i) => _buildAddCard(products[i], i),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAddCard(Map<String, dynamic> product, int index) {
    final accent = NeumorphicUtils.getAccentColor(index);
    String imageUrl = product['image_url'] ?? product['imageUrl'] ?? '';
    String productName =
        product['name'] ?? product['product_name'] ?? 'Unnamed Product';
    String category = product['category'] ?? 'General';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: NeumorphicUtils.decoration(
        context: context,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              const SizedBox(width: 15),
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                backgroundImage: (imageUrl.isNotEmpty)
                    ? NetworkImage(imageUrl)
                    : null,
                radius: 25,
                child: (imageUrl.isEmpty)
                    ? Icon(
                        Icons.image_not_supported,
                        size: 20,
                        color: Colors.grey,
                      )
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      category,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, size: 30),
                color: accent,
                onPressed: () => _openAddModal(product),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddModal(Map<String, dynamic> product) {
    _clearForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            void toggleColor(String color) {
              setStateModal(() {
                if (_selectedColors.contains(color))
                  _selectedColors.remove(color);
                else
                  _selectedColors.add(color);
              });
            }

            void toggleSize(String size) {
              setStateModal(() {
                if (_selectedSizes.contains(size))
                  _selectedSizes.remove(size);
                else
                  _selectedSizes.add(size);
              });
            }

            String productName =
                product['product_name'] ?? product['name'] ?? 'Item';

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    "Sell $productName",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          NeumorphicUtils.buildTextField(
                            controller: priceController,
                            placeholder: "Your Price (ZAR)",
                            prefixIcon: Icons.attach_money,
                            context: context,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 15),
                          NeumorphicUtils.buildTextField(
                            controller: locationController,
                            placeholder: "Location / Branch",
                            prefixIcon: Icons.pin_drop,
                            context: context,
                          ),
                          const SizedBox(height: 20),
                          _buildSelector(
                            context,
                            "Available Colors",
                            _colors,
                            _selectedColors,
                            toggleColor,
                          ),
                          const SizedBox(height: 20),
                          _buildSelector(
                            context,
                            "Available Sizes",
                            _sizesStd,
                            _selectedSizes,
                            toggleSize,
                          ),
                          const SizedBox(height: 30),
                          GestureDetector(
                            onTap: () => addProductToInventory(product['id']),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: NeumorphicUtils.decoration(
                                context: context,
                              ).copyWith(color: Theme.of(context).primaryColor),
                              child: const Center(
                                child: Text(
                                  "PUBLISH LISTING",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height:
                                MediaQuery.of(context).viewInsets.bottom + 20,
                          ),
                        ],
                      ),
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

  Widget _buildSelector(
    BuildContext context,
    String title,
    List<String> options,
    List<String> selectedList,
    Function(String) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedList.contains(option);
            return GestureDetector(
              onTap: () => onToggle(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration:
                    NeumorphicUtils.decoration(
                      context: context,
                      isPressed: isSelected,
                      radius: 8,
                    ).copyWith(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : null,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 1,
                            )
                          : null,
                    ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
