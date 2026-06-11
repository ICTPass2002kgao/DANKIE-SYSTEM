// ignore_for_file: prefer_const_constructors
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/tactso_pages/components/utilis.dart'; 

void showSignatureDialog(
  BuildContext context,
  Color neumoColor,
  Color primaryColor,
  void Function(Uint8List? signatureBytes) onConfirm,
) {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      const double canvasWidth = 320.0;

      return AlertDialog(
        backgroundColor: neumoColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Please Sign", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[900])
        ),
        content: SizedBox(
          width: canvasWidth, 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Provide your signature for the official document.", 
                style: TextStyle(color: Colors.grey[600], fontSize: 12)
              ),
              SizedBox(height: 16),
              Container(
                width: canvasWidth, 
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Signature(
                    controller: _signatureController,
                    height: 150,
                    width: canvasWidth, 
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _signatureController.clear(),
                  child: Text("Clear Signature", style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _signatureController.dispose();
              Navigator.pop(ctx);
            },
            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              if (_signatureController.isNotEmpty) {
                final signatureBytes = await _signatureController.toPngBytes();
                _signatureController.dispose();
                Navigator.pop(ctx);
                onConfirm(signatureBytes);
              } else {
                _signatureController.dispose();
                Navigator.pop(ctx);
                onConfirm(null);
              }
            },
            child: Text("Confirm & Generate", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    }
  );
}

void showEditMemberDialog(
  BuildContext context,
  Map<String, dynamic> userMap,
  bool isVisitor,
  Color neumoColor,
  Color primaryColor,
  void Function(String, bool, Map<String, dynamic>) onSave,
) {
  final nameCtrl = TextEditingController(text: userMap['name'] ?? '');
  final surnameCtrl = TextEditingController(text: userMap['surname'] ?? '');
  final phoneCtrl = TextEditingController(text: userMap['phone'] ?? '');

  bool isReadyForMembership = false;
  if (userMap['ready_for_membership'] != null) {
    isReadyForMembership =
        userMap['ready_for_membership'] == true ||
        userMap['ready_for_membership'] == 'true';
  }

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: 400,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: neumoColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-10, -10),
                    blurRadius: 20,
                  ),
                  BoxShadow(
                    color: Colors.grey.shade400,
                    offset: Offset(10, 10),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.pencil_circle_fill,
                          color: primaryColor,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Edit Record",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Update testifier/visitor details.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 24),
                    buildNeuInput(
                      "First Name",
                      nameCtrl,
                      neumoColor,
                      primaryColor,
                      CupertinoIcons.person_fill,
                    ),
                    buildNeuInput("Surname", surnameCtrl, neumoColor, primaryColor),
                    buildNeuInput(
                      "Contact Number",
                      phoneCtrl,
                      neumoColor,
                      primaryColor,
                      CupertinoIcons.phone_fill,
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isReadyForMembership
                            ? Colors.green.withOpacity(0.1)
                            : neumoColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isReadyForMembership
                              ? Colors.green
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Ready for Membership",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isReadyForMembership
                                        ? Colors.green[800]
                                        : Colors.blueGrey[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Has met the Priest & approved.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: isReadyForMembership,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              setDialogState(
                                () => isReadyForMembership = val,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            if (nameCtrl.text.isEmpty ||
                                surnameCtrl.text.isEmpty) {
                              Api().showMessage(
                                context,
                                "Name and Surname are required.",
                                "Warning",
                                Colors.orange,
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            Map<String, dynamic> updatePayload = {
                              "name": nameCtrl.text,
                              "surname": surnameCtrl.text,
                              "phone": phoneCtrl.text,
                              "ready_for_membership": isReadyForMembership,
                            };
                            onSave(userMap['ui_id'], isVisitor, updatePayload);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              "Save Changes",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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

void showAddVisitingMemberDialog(
  BuildContext context,
  Color neumoColor,
  Color primaryColor,
  Map<String, List<String>> officialHierarchy,
  void Function(String, String, String, String, String, String, String, {String visitorCategory, String? visitorRole}) onSave,
) {
  final nameCtrl = TextEditingController();
  final surnameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  if (officialHierarchy.isEmpty) {
    Api().showMessage(context, "No districts available.", "Error", Colors.red);
    return;
  }

  String? selectedDistrict = officialHierarchy.keys.first;
  String? selectedCommunity = officialHierarchy[selectedDistrict]?.isNotEmpty == true
      ? officialHierarchy[selectedDistrict]!.first
      : null;

  String selectedCategory = 'Mother';
  String selectedRole = 'Deacon';
  final List<String> categories = ['Mother', 'Father', 'Brother', 'Sister'];
  final List<String> roles = [
    'None', 'Deacon', 'Priest', 'Community Elder', 'District Elder', 'Overseer', 'Apostle',
  ];

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          bool isParent = selectedCategory == 'Mother' || selectedCategory == 'Father';

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: 400,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: neumoColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.white, offset: Offset(-10, -10), blurRadius: 20),
                  BoxShadow(color: Colors.grey.shade400, offset: Offset(10, 10), blurRadius: 20),
                ],
              ),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.person_2_fill, color: primaryColor, size: 28),
                        SizedBox(width: 12),
                        Text("Add Guest Member", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blueGrey[900])),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text("Register a visiting relative.", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    SizedBox(height: 24),

                    Text("ASSIGNMENT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade500)),
                    SizedBox(height: 8),
                    NeumorphicContainer(
                      color: neumoColor,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedDistrict,
                          icon: Icon(CupertinoIcons.building_2_fill, color: primaryColor),
                          items: officialHierarchy.keys.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedDistrict = val;
                                selectedCommunity = officialHierarchy[val]?.isNotEmpty == true ? officialHierarchy[val]!.first : null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    if (selectedCommunity != null)
                      NeumorphicContainer(
                        color: neumoColor,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedCommunity,
                            icon: Icon(CupertinoIcons.location_solid, color: primaryColor),
                            items: officialHierarchy[selectedDistrict!]!.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedCommunity = val);
                            },
                          ),
                        ),
                      ),
                    SizedBox(height: 16),

                    Text("RELATIONSHIP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade500)),
                    SizedBox(height: 8),
                    NeumorphicContainer(
                      color: neumoColor,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCategory,
                          items: categories.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    if (isParent) ...[
                      Text("SPIRITUAL RANK (Optional)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade500)),
                      SizedBox(height: 8),
                      NeumorphicContainer(
                        color: neumoColor,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedRole,
                            items: roles.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedRole = val);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],

                    Text("PERSONAL INFO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade500)),
                    SizedBox(height: 12),

                    buildNeuInput("First Name", nameCtrl, neumoColor, primaryColor, CupertinoIcons.person_fill),
                    buildNeuInput("Surname", surnameCtrl, neumoColor, primaryColor),
                    buildNeuInput("Contact Number", phoneCtrl, neumoColor, primaryColor, CupertinoIcons.phone_fill),
                    buildNeuInput("Home Address", addressCtrl, neumoColor, primaryColor, CupertinoIcons.map_pin_ellipse),

                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(width: 16),
                        GestureDetector(
                          onTap: () async {
                            if (nameCtrl.text.isEmpty || surnameCtrl.text.isEmpty || selectedCommunity == null) {
                              Api().showMessage(context, "Name, Surname and Location required.", "Warning", Colors.orange);
                              return;
                            }
                            Navigator.pop(ctx);

                            String deducedGender = (selectedCategory == 'Mother' || selectedCategory == 'Sister') ? 'Female' : 'Male';

                            onSave(
                              nameCtrl.text, surnameCtrl.text, phoneCtrl.text, addressCtrl.text, deducedGender,
                              selectedDistrict!, selectedCommunity!,
                              visitorCategory: selectedCategory, visitorRole: isParent ? selectedRole : null,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Text("Save Guest", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

void showAddVisitorDialog(
  BuildContext context,
  Color neumoColor,
  Color primaryColor,
  Map<String, List<String>> officialHierarchy,
  void Function(String, String, String, String, String, String, String, {String visitorCategory, String? visitorRole}) onSave,
) {
  final nameCtrl = TextEditingController();
  final surnameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  String selectedGender = 'Male';

  if (officialHierarchy.isEmpty) {
    Api().showMessage(context, "No districts available.", "Error", Colors.red);
    return;
  }

  String? selectedDistrict = officialHierarchy.keys.first;
  String? selectedCommunity = officialHierarchy[selectedDistrict]?.isNotEmpty == true
      ? officialHierarchy[selectedDistrict]!.first
      : null;

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: 400,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: neumoColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.white, offset: Offset(-10, -10), blurRadius: 20),
                  BoxShadow(color: Colors.grey.shade400, offset: Offset(10, 10), blurRadius: 20),
                ],
              ),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.person_badge_plus_fill, color: Colors.orange, size: 28),
                        SizedBox(width: 12),
                        Text("Add Testify", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blueGrey[900])),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text("Assign a new testify.", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    SizedBox(height: 24),

                    Text("ASSIGNMENT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade500)),
                    SizedBox(height: 8),
                    NeumorphicContainer(
                      color: neumoColor,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedDistrict,
                          icon: Icon(CupertinoIcons.building_2_fill, color: primaryColor),
                          items: officialHierarchy.keys.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedDistrict = val;
                                selectedCommunity = officialHierarchy[val]?.isNotEmpty == true ? officialHierarchy[val]!.first : null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    if (selectedCommunity != null)
                      NeumorphicContainer(
                        color: neumoColor,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedCommunity,
                            icon: Icon(CupertinoIcons.location_solid, color: primaryColor),
                            items: officialHierarchy[selectedDistrict!]!.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedCommunity = val);
                            },
                          ),
                        ),
                      ),
                    SizedBox(height: 16),

                    Text("PERSONAL INFO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade500)),
                    SizedBox(height: 12),

                    buildNeuInput("First Name", nameCtrl, neumoColor, primaryColor, CupertinoIcons.person_fill),
                    buildNeuInput("Surname", surnameCtrl, neumoColor, primaryColor),
                    buildNeuInput("Contact Number", phoneCtrl, neumoColor, primaryColor, CupertinoIcons.phone_fill),
                    buildNeuInput("Home Address", addressCtrl, neumoColor, primaryColor, CupertinoIcons.map_pin_ellipse),

                    NeumorphicContainer(
                      color: neumoColor,
                      borderRadius: 12,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedGender,
                          items: ['Male', 'Female'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedGender = val);
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(width: 16),
                        GestureDetector(
                          onTap: () async {
                            if (nameCtrl.text.isEmpty || surnameCtrl.text.isEmpty || selectedCommunity == null) {
                              Api().showMessage(context, "Name, Surname and Location required.", "Warning", Colors.orange);
                              return;
                            }
                            Navigator.pop(ctx);
                            onSave(
                              nameCtrl.text, surnameCtrl.text, phoneCtrl.text, addressCtrl.text, selectedGender,
                              selectedDistrict!, selectedCommunity!,
                              visitorCategory: 'Testify',
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Text("Save Testify", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

void showMonthPickerForReport(
  BuildContext context,
  Color neumoColor,
  Color primaryColor,
  void Function(int, int) onGenerate,
) {
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: neumoColor,
            title: Row(
              children: [
                Icon(CupertinoIcons.calendar_circle_fill, color: primaryColor, size: 28),
                SizedBox(width: 10),
                Text("Select Month", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey[900])),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: selectedMonth,
                        isExpanded: true,
                        items: List.generate(12, (index) => index + 1).map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(DateFormat('MMMM').format(DateTime(2024, m)), style: TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedMonth = val!),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<int>(
                        value: selectedYear,
                        isExpanded: true,
                        items: [DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1].map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text(y.toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedYear = val!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onGenerate(selectedMonth, selectedYear);
                },
                child: Text("Generate Ledger", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}