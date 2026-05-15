// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb/Platform checks
import 'package:ttact/Components/API.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class VerificationScreen extends StatefulWidget {
  final String name;
  final String surname;
  final String email;
  final String password;
  final String address;
  final String contacts;
  final String selectedOverseerUid;
  final String role;
  final String accountNumber;
  final String bankCode;
  final String province;
  final String districtElder;
  final String communityName;
  final String expectedCode;
  final String gender;

  const VerificationScreen({
    
    Key? key,
    required this.expectedCode,
    required this.name,
    required this.surname,
    required this.email,
    required this.password,
    required this.address,
    required this.contacts,
    required this.selectedOverseerUid,
    required this.role,
    required this.accountNumber,
    required this.bankCode,
    required this.province,
    required this.districtElder,
    required this.communityName, required this.gender,
  }) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentCode {
    return _controllers.map((c) => c.text).join();
  }

  void _verifyCode() async {
    for (var node in _focusNodes) {
      node.unfocus();
    }

    String code = _currentCode;
    if (code.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(Duration(seconds: 1));

    if (code == widget.expectedCode) {
      await Api().signUp(
        widget.gender,
        widget.name,
        widget.surname,
        widget.email,
        widget.password,
        widget.address,
        widget.contacts,
        widget.selectedOverseerUid,
        widget.role,
        accountNumber: widget.accountNumber,
        bankCode: widget.bankCode,
        widget.province,
        widget.districtElder,
        widget.communityName,
        context,
      );
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification Successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Wrong code, please try again.";
        for (var controller in _controllers) {
          controller.clear();
        }
      });
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final bool isSmallDevice = size.width < 600;

    // TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea( 
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 20.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start, 
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [ 
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: NeumorphicContainer(
                          color: neumoBaseColor,
                          borderRadius: 50,
                          padding: const EdgeInsets.all(12),
                          isPressed: false, 
                          child: Icon(
                            Icons.arrow_back,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ), 
                  SizedBox(height: isSmallDevice ? 30 : 50), 
                  NeumorphicContainer(
                    color: neumoBaseColor,
                    isPressed: false, 
                    borderRadius: 30,
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      children: [ 
                        NeumorphicContainer(
                          color: neumoBaseColor,
                          borderRadius: 100,
                          isPressed: true, // Sunken Icon Well
                          padding: const EdgeInsets.all(25),
                          child: Icon(
                            Icons.mark_email_read_outlined,
                            size: 50,
                            color: theme.primaryColor,
                          ),
                        ),

                        SizedBox(height: 25),

                        Text(
                          'Verification',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: theme.primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Enter the 6-digit code sent to:',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.hintColor,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          widget.email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 35),

                        // OTP INPUTS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 40,
                              height: 55,
                              child: KeyboardListener(
                                focusNode: FocusNode(),
                                onKeyEvent: (event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.backspace) {
                                    if (_controllers[index].text.isEmpty &&
                                        index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  }
                                },
                                child: NeumorphicContainer(
                                  color: neumoBaseColor,
                                  isPressed: true, // ⭐️ Sunken Input Box
                                  borderRadius: 10,
                                  padding: EdgeInsets.zero,
                                  child: Center(
                                    child: TextFormField(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      autofocus: index == 0,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: "",
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        if (_errorMessage != null) {
                                          setState(() {
                                            _errorMessage = null;
                                          });
                                        }
                                        if (value.length == 6) {
                                          for (int i = 0; i < 6; i++) {
                                            _controllers[i].text = value[i];
                                          }
                                          _verifyCode();
                                        } else if (value.length == 1) {
                                          if (index < 5) {
                                            FocusScope.of(context).requestFocus(
                                              _focusNodes[index + 1],
                                            );
                                          } else {
                                            _focusNodes[index].unfocus();
                                            _verifyCode();
                                          }
                                        } else if (value.length > 1) {
                                          _controllers[index].text = value
                                              .substring(value.length - 1);
                                          if (index < 5) {
                                            FocusScope.of(context).requestFocus(
                                              _focusNodes[index + 1],
                                            );
                                          }
                                        } else if (value.isEmpty) {
                                          if (index > 0) {
                                            FocusScope.of(context).requestFocus(
                                              _focusNodes[index - 1],
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        SizedBox(height: 20),

                        if (_errorMessage != null)
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                        SizedBox(height: 30),

                        // VERIFY BUTTON
                        GestureDetector(
                          onTap: (_isLoading)
                              ? null
                              : () {
                                  if (_currentCode.length == 6) {
                                    _verifyCode();
                                  }
                                },
                          child: NeumorphicContainer(
                            color: theme.primaryColor,
                            borderRadius: 15,
                            isPressed: false, // Convex Button
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: _isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Verify Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // Resend Code
                  TextButton(
                    onPressed: () async {
                      // ... (Keep existing Resend Logic) ...
                      isIOSPlatform
                          ? Api().showIosLoading(context)
                          : Api().showLoading(context);
                      String code = Api().generateVerificationCode();
                      bool emailSent = await Api().sendEmail(
                        widget.email,
                        'Verification code',
                        "Your code is: $code",
                        context,
                      );
                      if (emailSent) {
                        Navigator.pop(context);
                        Api().showMessage(
                          context,
                          "Sent",
                          "Success",
                          theme.primaryColor,
                        );
                      } else {
                        Navigator.pop(context);
                        Api().showMessage(
                          context,
                          "Failed",
                          "Error",
                          Colors.red,
                        );
                      }
                    },
                    child: Text(
                      "Didn't receive the code? Resend",
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
