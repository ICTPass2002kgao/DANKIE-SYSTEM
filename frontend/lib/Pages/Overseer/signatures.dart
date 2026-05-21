// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

class Signatures extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;

  const Signatures({
    super.key,
    this.committeeMemberName,
    this.committeeMemberRole,
    this.faceUrl,
    required this.isLargeScreen,
  });

  @override
  State<Signatures> createState() => _SignaturesState();
}

class _SignaturesState extends State<Signatures> {
  final String baseUrl = Api().BACKEND_BASE_URL_DEBUG;

  bool _isLoading = true;

  // Variables to hold the current logged-in user's data
  String? _dbId;
  String _endpoint = '/committee_members/';
  String? _cardSignature;

  // Neumorphism Theme Colors
  final Color _baseColor = const Color(0xFFE0E5EC);
  final Color _shadowLight = Colors.white;
  final Color _shadowDark = const Color(0xFFA3B1C6);
  final Color _textColor = const Color(0xFF4A5568);

  BoxDecoration _neuDecoration({double radius = 20, bool isPressed = false}) {
    return BoxDecoration(
      color: _baseColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: isPressed
          ? []
          : [
              BoxShadow(
                color: _shadowDark.withOpacity(0.6),
                offset: const Offset(8, 8),
                blurRadius: 15,
              ),
              BoxShadow(
                color: _shadowLight,
                offset: const Offset(-8, -8),
                blurRadius: 15,
              ),
            ],
    );
  }

  BoxDecoration _neuInnerDecoration({double radius = 16}) {
    return BoxDecoration(
      color: const Color(0xFFD1D9E6),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchSignatoriesData();
  }

  Future<void> _fetchSignatoriesData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String? token = await user.getIdToken();
    final String uid = user.uid;

    try {
      final overRes = await http.get(
        Uri.parse('$baseUrl/overseers/?uid=$uid'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (overRes.statusCode == 200) {
        final List data = jsonDecode(overRes.body);
        if (data.isNotEmpty) {
          final String overId = data.first['id'];
          final String currentRole = widget.committeeMemberRole ?? 'Portfolio';
          final String currentName = widget.committeeMemberName ?? 'Name';

          final comRes = await http.get(
            Uri.parse('$baseUrl/committee_members/?overseer=$overId'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (comRes.statusCode == 200) {
            final List comData = jsonDecode(comRes.body);
            for (var member in comData) {
              if (member['portfolio'] == currentRole &&
                  member['full_name'] == currentName) {
                setState(() {
                  _dbId = member['id'];
                  _cardSignature = member['signature_base64'];
                });
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching signatory data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSignature(Uint8List signatureBytes) async {
    if (_dbId == null) {
      Api().showMessage(
        context,
        "Could not identify your committee record to update.",
        "Error",
        Colors.red,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String? token = await user.getIdToken();

    Api().showLoading(context);

    try {
      String base64Sig = base64Encode(signatureBytes);

      final res = await http.patch(
        Uri.parse('$baseUrl$_endpoint$_dbId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'signature_base64': base64Sig}),
      );

      Navigator.pop(context);

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _cardSignature = base64Sig;
        });
        Api().showMessage(
          context,
          "Signature successfully saved to your profile!",
          "Success",
          Colors.green,
        );
      } else {
        Api().showMessage(
          context,
          "Failed to save. Server responded with ${res.statusCode}",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      print("Error saving signature: $e");
      Api().showMessage(
        context,
        "Failed to save signature.",
        "Error",
        Colors.red,
      );
    }
  }

  void _openSignaturePad(String role) {
    final SignatureController sigController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black, // ⭐️ Ensured pen is distinctly Black
      exportBackgroundColor: Colors.transparent,
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 600,
          padding: EdgeInsets.all(24),
          decoration: _neuDecoration(radius: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Sign as $role",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _textColor,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 20),
              Container(
                decoration: _neuInnerDecoration(radius: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Signature(
                    controller: sigController,
                    height: 250,
                    backgroundColor: _baseColor,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      sigController.clear();
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => sigController.clear(),
                    child: Text(
                      "Clear",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    decoration: _neuDecoration(radius: 12),
                    child: CustomOutlinedButton(
                      onPressed: () async {
                        if (sigController.isNotEmpty) {
                          final signatureBytes = await sigController
                              .toPngBytes();
                          if (signatureBytes != null) {
                            Navigator.pop(ctx);
                            _saveSignature(signatureBytes);
                          }
                        }
                      },
                      text: "Save Signature",
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      width: 150,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureCard(String role, String name, String? signatureData) {
    return Container(
      width: 450,
      padding: EdgeInsets.all(30),
      decoration: _neuDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.blue.shade800,
                  letterSpacing: 1.5,
                ),
              ),
              InkWell(
                onTap: () => _openSignaturePad(role),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _baseColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: _shadowDark.withOpacity(0.4),
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                      BoxShadow(
                        color: _shadowLight,
                        offset: Offset(-2, -2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.draw, size: 16, color: Colors.blue.shade800),
                      SizedBox(width: 8),
                      Text(
                        signatureData != null && signatureData.isNotEmpty
                            ? "Update"
                            : "Sign",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              name.isNotEmpty && name != 'null' ? name : 'Name not provided',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          SizedBox(height: 25),
          Container(
            height: 150,
            width: double.infinity,
            decoration: _neuInnerDecoration(radius: 12),
            child: signatureData != null && signatureData.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(signatureData),
                      fit: BoxFit.contain,
                    ),
                  )
                : Center(
                    child: Text(
                      "Awaiting Signature",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          SizedBox(height: 15),
          Divider(color: Colors.white, thickness: 2),
          Text(
            "Authorized Signature",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: _baseColor,
        height: 300,
        child: Center(
          child: CircularProgressIndicator(color: Colors.blue.shade800),
        ),
      );
    }

    final String currentRole = widget.committeeMemberRole ?? 'Portfolio';
    final String currentName = widget.committeeMemberName ?? 'Name';

    return Container(
      color: _baseColor,
      padding: EdgeInsets.all(widget.isLargeScreen ? 40 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ 
          Text(
            "Ensure your signature is up to date for official document authorization.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),

          Center(
            child: _buildSignatureCard(
              currentRole,
              currentName,
              _cardSignature,
            ),
          ),
        ],
      ),
    );
  }
}
