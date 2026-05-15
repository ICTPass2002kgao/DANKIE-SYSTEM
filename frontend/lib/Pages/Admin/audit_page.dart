// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class TactsoBranchAudit extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const TactsoBranchAudit({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<TactsoBranchAudit> createState() => _TactsoBranchAuditState();
}

class _TactsoBranchAuditState extends State<TactsoBranchAudit> {
  // --- Color Palette (Fallbacks) ---
  final Color successGreen = const Color(0xFF388E3C);
  final Color errorRed = const Color(0xFFD32F2F);
  final Color neutralGrey = const Color(0xFF757575);

  // --- API FETCHING ---
  Future<List<dynamic>> _fetchAuditLogs() async {
    try {
      // Endpoint: /audit_logs/?ordering=-timestamp
      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/audit_logs/?ordering=-timestamp',
      );

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Handle pagination { "results": [...] } or direct list [...]
        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          return decoded['results'] as List<dynamic>;
        } else if (decoded is List) {
          return decoded;
        }
        return [];
      } else {
        debugPrint("Error fetching logs: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Exception fetching logs: $e");
      return [];
    }
  }

  Color _getActionColor(String? action, Color primaryColor) {
    if (action == null) return neutralGrey;
    action = action.toUpperCase();
    if (action.contains('CREATE') ||
        action.contains('ADD') ||
        action.contains('UPDATE')) {
      return successGreen;
    } else if (action.contains('DELETE') || action.contains('REMOVE')) {
      return errorRed;
    } else if (action.contains('VIEW') || action.contains('READ')) {
      return primaryColor;
    }
    return neutralGrey;
  }

  // --- IMAGE PREVIEW DIALOG ---
  void _showImagePreview(BuildContext context, String imageUrl, String title) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                  errorBuilder: (ctx, error, stack) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PDF GENERATION ---
  Future<void> _generateAndDownloadPdf() async {
    final pdf = pw.Document();
    final data = await _fetchAuditLogs();

    final logoImage = await rootBundle.load('assets/dankie_logo.PNG');
    final logoProvider = pw.MemoryImage(logoImage.buffer.asUint8List());

    final pdfPrimaryBlue = PdfColor.fromInt(0xFF1976D2);
    final pdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);

    List<List<dynamic>> pdfRows = [];

    for (var d in data) {
      String dateStr = '-';
      if (d['timestamp'] != null) {
        try {
          // Attempt to parse string timestamp
          DateTime dt = DateTime.parse(d['timestamp'].toString());
          dateStr = DateFormat('yyyy-MM-dd HH:mm').format(dt);
        } catch (e) {
          dateStr = d['timestamp'].toString();
        }
      }

      // ⭐️ UPDATED: snake_case keys
      String faceUrl = d['actor_face_url'] ?? '';

      pw.Widget faceWidget = pw.Text("-");
      if (faceUrl.isNotEmpty) {
        try {
          final netImage = await networkImage(faceUrl);
          faceWidget = pw.ClipOval(
            child: pw.Image(
              netImage,
              width: 20,
              height: 20,
              fit: pw.BoxFit.cover,
            ),
          );
        } catch (e) {
          /* Ignore image load error */
        }
      }

      // ⭐️ UPDATED: snake_case keys
      String actorName = d['actor_name'] ?? '-';
      String actorRole = d['actor_role'] ?? '';
      String displayActor = actorRole.isNotEmpty
          ? "$actorName\n($actorRole)"
          : actorName;

      // ⭐️ UPDATED: snake_case keys
      String studentName = d['student_name'] ?? 'N/A';
      String targetMember = d['target_member_name'] ?? 'N/A';
      String targetInfo = (studentName != 'N/A')
          ? studentName
          : (targetMember != 'N/A' ? "$targetMember (Member)" : '-');

      pdfRows.add([
        dateStr,
        faceWidget,
        displayActor,
        d['university_name'] ?? '-', // snake_case
        d['action'] ?? '-',
        targetInfo,
        d['branch_email'] ?? '-', // snake_case
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: pdfPrimaryBlue, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logoProvider, width: 40, height: 40),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'Dankie Audit Report',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfPrimaryBlue,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerDecoration: pw.BoxDecoration(color: pdfHeaderBg),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: pdfPrimaryBlue,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headers: [
                'Time',
                'Face',
                'Committee / Actor',
                'University',
                'Action',
                'Target (Student/Mem)',
                'User Email',
              ],
              data: pdfRows,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Dankie_Audit_Log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  void _showFullDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            const Text("Full Audit Details"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: data.entries.map((e) {
              String valueStr = e.value.toString();

              if ((e.key.contains('time') || e.key.contains('date')) &&
                  e.value != null) {
                try {
                  valueStr = DateFormat(
                    'yyyy-MM-dd HH:mm:ss',
                  ).format(DateTime.parse(e.value.toString()));
                } catch (_) {}
              }

              if (e.key.contains('url') || e.key.contains('image')) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key.toUpperCase().replaceAll('_', ' '), // Formatting
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: neutralGrey,
                      ),
                    ),
                    SelectableText(
                      valueStr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Divider(color: Colors.grey.shade200),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = theme.primaryColor;

    final Color neumoBaseColor = Color.alphaBlend(
      primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Stack(
        children: [
          // --- BACKGROUND BLOBS ---
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.15),
              ),
            ),
          ),

          // --- MAIN CONTENT ---
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER SECTION ---
                NeumorphicContainer(
                  color: neumoBaseColor,
                  borderRadius: 16,
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      NeumorphicContainer(
                        color: neumoBaseColor,
                        borderRadius: 50,
                        padding: const EdgeInsets.all(2),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.transparent,
                          backgroundImage: const AssetImage(
                            'assets/dankie_logo.PNG',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'System Audit Logs',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Track operations, status updates, and document access.',
                              style: TextStyle(
                                fontSize: 14,
                                color: neutralGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _generateAndDownloadPdf,
                        child: NeumorphicContainer(
                          color: primaryColor,
                          borderRadius: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.download_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Export PDF",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- TABLE SECTION ---
                Expanded(
                  child: NeumorphicContainer(
                    color: neumoBaseColor,
                    borderRadius: 16,
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FutureBuilder<List<dynamic>>(
                        future: _fetchAuditLogs(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_toggle_off,
                                    size: 40,
                                    color: neutralGrey,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "No logs found.",
                                    style: TextStyle(color: neutralGrey),
                                  ),
                                  const SizedBox(height: 20),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {});
                                    },
                                    child: NeumorphicContainer(
                                      color: neumoBaseColor,
                                      borderRadius: 8,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        "Refresh",
                                        style: TextStyle(color: primaryColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  primaryColor.withOpacity(0.05),
                                ),
                                headingRowHeight: 50,
                                dataRowMinHeight: 60,
                                dataRowMaxHeight: 70,
                                columnSpacing: 30,
                                horizontalMargin: 24,
                                dividerThickness: 0,
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'TIME',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'FACE',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ACTOR',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'UNIVERSITY',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'LOGO',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ACTION',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'TARGET',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'USER',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'VIEW',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: snapshot.data!.map((data) {
                                  // --- DATE PARSING ---
                                  String dateStr = '-';
                                  if (data['timestamp'] != null) {
                                    try {
                                      DateTime dt = DateTime.parse(
                                        data['timestamp'],
                                      );
                                      dateStr = DateFormat(
                                        'MMM dd, HH:mm',
                                      ).format(dt);
                                    } catch (_) {
                                      dateStr = data['timestamp'].toString();
                                    }
                                  }

                                  String actionStr = data['action'] ?? '';
                                  Color actionColor = _getActionColor(
                                    actionStr,
                                    primaryColor,
                                  );

                                  // --- ⭐️ UPDATED KEY MATCHING (Snake Case) ---

                                  // FACE
                                  String faceUrl = data['actor_face_url'] ?? '';

                                  // LOGO
                                  String logoUrl =
                                      data['university_logo'] ?? '';

                                  // NAME
                                  String actorName = data['actor_name'] ?? '-';

                                  // ROLE
                                  String actorRole = data['actor_role'] ?? '';

                                  // TARGET
                                  String studentName =
                                      data['student_name'] ?? 'N/A';
                                  String targetMemberName =
                                      data['target_member_name'] ?? 'N/A';
                                  String targetDisplay =
                                      (studentName != 'N/A' &&
                                          studentName != 'Unknown')
                                      ? studentName
                                      : (targetMemberName != 'N/A'
                                            ? "$targetMemberName (Member)"
                                            : '-');

                                  return DataRow(
                                    cells: [
                                      // 1. Time
                                      DataCell(
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),

                                      // 2. Committee Face
                                      DataCell(
                                        InkWell(
                                          onTap: () => _showImagePreview(
                                            context,
                                            faceUrl,
                                            "Committee Face",
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: primaryColor.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 18,
                                              backgroundColor:
                                                  Colors.grey.shade100,
                                              backgroundImage:
                                                  faceUrl.isNotEmpty
                                                  ? NetworkImage(faceUrl)
                                                  : null,
                                              child: faceUrl.isEmpty
                                                  ? Icon(
                                                      Icons.person,
                                                      size: 16,
                                                      color: Colors.grey,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 3. Committee Name & Role
                                      DataCell(
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              actorName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (actorRole.isNotEmpty)
                                              Text(
                                                actorRole,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: neutralGrey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // 4. University Name
                                      DataCell(
                                        Text(
                                          data['university_name'] ?? '-',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                      // 5. University Logo
                                      DataCell(
                                        InkWell(
                                          onTap: () => _showImagePreview(
                                            context,
                                            logoUrl,
                                            "University Logo",
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 18,
                                              backgroundColor: Colors.white,
                                              backgroundImage:
                                                  logoUrl.isNotEmpty
                                                  ? NetworkImage(logoUrl)
                                                  : null,
                                              child: logoUrl.isEmpty
                                                  ? Icon(
                                                      Icons.school,
                                                      size: 16,
                                                      color: Colors.grey,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 6. Action
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: actionColor.withOpacity(
                                              0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: actionColor.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            actionStr,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                              color: actionColor,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 7. Target
                                      DataCell(Text(targetDisplay)),

                                      // 8. User Email
                                      DataCell(
                                        Text(data['branch_email'] ?? 'System'),
                                      ),

                                      // 9. Details
                                      DataCell(
                                        IconButton(
                                          icon: Icon(
                                            Icons.visibility_outlined,
                                            color: primaryColor,
                                          ),
                                          onPressed: () =>
                                              _showFullDetails(context, data),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
