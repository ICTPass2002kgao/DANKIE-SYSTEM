// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class ViewApplicationBottomSheet extends StatefulWidget {
  final String userId;
  final String universityUid;

  const ViewApplicationBottomSheet({
    Key? key,
    required this.userId,
    required this.universityUid,
  }) : super(key: key);

  @override
  State<ViewApplicationBottomSheet> createState() =>
      _ViewApplicationBottomSheetState();
}

class _ViewApplicationBottomSheetState
    extends State<ViewApplicationBottomSheet> {
  Map<String, dynamic>? _applicationData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplicationData();
  }

  Future<void> _fetchApplicationData() async {
    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('university_applications')
          .where('applicationDetails.uid', isEqualTo: widget.universityUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _applicationData =
            querySnapshot.docs.first.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching application data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ⭐️ TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: neumoBaseColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
      ),
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : _applicationData != null
          ? SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      isPressed: true, // Sunken
                      borderRadius: 10,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: SizedBox(height: 4, width: 30),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Header
                  Center(
                    child: Text(
                      'Your Application',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Status Badge
                  Center(
                    child: _buildStatusBadge(
                      _applicationData!['status'],
                      neumoBaseColor,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // University & Campus Details (Highlighted Card)
                  NeumorphicContainer(
                    color: neumoBaseColor,
                    isPressed: false,
                    borderRadius: 20,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            NeumorphicContainer(
                              color: neumoBaseColor,

                              isPressed: true, // Sunken Icon
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.account_balance,
                                color: theme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _applicationData!['universityName'] ??
                                        'N/A',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    _applicationData!['campus'] ?? 'N/A',
                                    style: TextStyle(
                                      color: theme.hintColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Personal Information Card
                  _buildInfoCard(
                    title: 'Personal Information',
                    icon: Icons.person,
                    theme: theme,
                    baseColor: neumoBaseColor,
                    children: [
                      _buildDetailRow(
                        'Full Name',
                        _applicationData!['applicationDetails']['fullName'],
                        theme,
                      ),
                      _buildDetailRow(
                        'Email',
                        _applicationData!['applicationDetails']['email'],
                        theme,
                      ),
                      _buildDetailRow(
                        'Phone',
                        _applicationData!['applicationDetails']['phone'],
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Program Details Card
                  _buildInfoCard(
                    title: 'Program Selection',
                    icon: Icons.school,
                    theme: theme,
                    baseColor: neumoBaseColor,
                    children: [
                      _buildDetailRow(
                        'Primary Program',
                        _applicationData!['applicationDetails']['primaryProgram'],
                        theme,
                      ),
                      _buildDetailRow(
                        'Second Choice',
                        _applicationData!['applicationDetails']['secondChoiceProgram'],
                        theme,
                      ),
                      _buildDetailRow(
                        'Third Choice',
                        _applicationData!['applicationDetails']['thirdChoiceProgram'],
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Documents Card
                  _buildInfoCard(
                    title: 'Supporting Documents',
                    icon: Icons.folder_copy,
                    theme: theme,
                    baseColor: neumoBaseColor,
                    children: [
                      _buildDocumentStatus(
                        'ID / Passport',
                        _applicationData!['applicationDetails']['documents']['idPassportUrl'],
                        theme,
                        neumoBaseColor,
                      ),
                      _buildDocumentStatus(
                        'School Results',
                        _applicationData!['applicationDetails']['documents']['schoolResultsUrl'],
                        theme,
                        neumoBaseColor,
                      ),
                      _buildDocumentStatus(
                        'Passport Photo',
                        _applicationData!['applicationDetails']['documents']['passportPhotoUrl'],
                        theme,
                        neumoBaseColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            )
          : Center(
              child: Text(
                'No application found.',
                style: TextStyle(color: theme.hintColor),
              ),
            ),
    );
  }

  Widget _buildStatusBadge(String? status, Color baseColor) {
    Color badgeColor;
    switch (status) {
      case 'Submitted':
        badgeColor = Colors.green;
        break;
      case 'Pending':
        badgeColor = Colors.orange;
        break;
      case 'Review':
        badgeColor = Colors.blue;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return NeumorphicContainer(
      color: baseColor,
      isPressed: true, // Sunken Pill
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        (status ?? 'Unknown').toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required ThemeData theme,
    required Color baseColor,
  }) {
    return NeumorphicContainer(
      color: baseColor,
      isPressed: false, // Convex Card
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
          Divider(color: theme.hintColor.withOpacity(0.2), height: 25),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              '$label',
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatus(
    String label,
    String? url,
    ThemeData theme,
    Color baseColor,
  ) {
    final bool isUploaded = url != null && url.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          NeumorphicContainer(
            color: baseColor,
            isPressed: true, // Sunken Indicator

            padding: EdgeInsets.all(6),
            child: Icon(
              isUploaded ? Icons.check : Icons.close,
              color: isUploaded ? Colors.green : Colors.orange,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(
            isUploaded ? 'Uploaded' : 'Pending',
            style: TextStyle(
              color: isUploaded ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
