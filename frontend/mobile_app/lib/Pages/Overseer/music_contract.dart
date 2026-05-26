import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ttact/Components/API.dart';

class MusicContract extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;

  final bool isSigned;
  final String? existingSignatureBase64;

  const MusicContract({
    super.key,
    this.committeeMemberName,
    this.committeeMemberRole,
    this.faceUrl,
    this.isSigned = false,
    this.existingSignatureBase64,
  });

  @override
  State<MusicContract> createState() => _MusicContractState();
}

class _MusicContractState extends State<MusicContract> {
  late SignatureController _signatureController;

  final Color backgroundColor = const Color(0xFFE0E0E0);
  final Color lightShadow = const Color(0xFFFFFFFF);
  final Color darkShadow = const Color(0xFFA6A6A6);

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // PDF GENERATION LOGIC
  // ===========================================================================
  Future<void> _generateAndPrintPdf(String base64Signature) async {
    final pdf = pw.Document();
    final signatureImage = pw.MemoryImage(base64Decode(base64Signature));
    final String artistName = widget.committeeMemberName ?? "UNKNOWN ARTIST";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            pw.Text(
              "ARTIST/COMPOSER CONSENT, WAIVER, AND PERPETUAL MUSIC DISTRIBUTION AGREEMENT",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              "This Agreement is made and entered into by and between:\n\nDANKIE (hereinafter referred to as \"the Platform\")\n\nand\n\n$artistName (hereinafter referred to as \"the Artist/Composer\")",
            ),
            pw.SizedBox(height: 20),

            _buildPdfSection(
              "1. PURPOSE AND BINDING NATURE OF THE DOCUMENT",
              "The purpose of this Agreement is to establish the explicit legal terms under which the Artist/Composer grants the Platform permission to upload, host, distribute, and share their music. By signing this document, the Artist/Composer acknowledges that this is a fully enforceable, legally binding contract. Failure to read or understand these terms does not exempt the Artist/Composer from the strict liabilities outlined below.",
            ),

            _buildPdfSection(
              "2. GRANT OF RIGHTS UP TO INFINITY",
              "The Artist/Composer hereby grants the Platform a non-exclusive, worldwide, royalty-free license to:\n• Upload, host, and store the Artist/Composer’s music on the Platform's servers indefinitely, up to infinity.\n• Distribute, broadcast, and make the music continuously available to all current and future users of the Platform.\n• Allow users to stream, download, share, and consume the music freely and without restriction.\n\nUnless explicitly revoked via the formal procedure outlined in Section 7, the Platform retains the right to host and distribute the submitted music up to infinity.",
            ),

            _buildPdfSection(
              "3. STRICT ZERO-COMPENSATION AND NO-ROYALTY CLAUSE",
              "The Artist/Composer expressly understands, acknowledges, and agrees that:\n• Zero Financial Expectation: The Artist/Composer will receive absolutely no payment, financial compensation, advances, or retroactive payouts for the distribution of their music on the Platform, now or at any point in the future.\n• No Royalties: The Platform operates strictly on a free-to-use model for this content. There will be no mechanical, performance, digital, or synchronization royalties generated or paid to the Artist/Composer by the Platform.\n• Waiver of Claims: The Artist/Composer waives any and all right to demand compensation for streams, downloads, or user engagement associated with their music on this Platform.",
            ),

            _buildPdfSection(
              "4. ABSOLUTE OWNERSHIP AND COPYRIGHT ACCOUNTABILITY",
              "The Artist/Composer explicitly warrants and guarantees that:\n• They are the sole, rightful, and original creator of the music, or they possess the explicit, legally documented rights to distribute the master recordings and underlying compositions.\n• The music does not contain uncleared samples, stolen beats, or unauthorized vocals.\n• The music does not infringe upon the copyrights, trademarks, or intellectual property rights of any third party.",
            ),

            _buildPdfSection(
              "5. CONSEQUENCES OF UNAUTHORIZED UPLOADS (STOLEN CONTENT)",
              "The Platform enforces a zero-tolerance policy for copyright infringement. If the Artist/Composer uploads music that belongs to another individual, entity, or record label:\n• Immediate Ban: The Artist/Composer's account will be permanently terminated without notice, losing access to all Platform services.\n• Full Legal Accountability: The Artist/Composer will be held 100% personally and legally accountable for the unauthorized distribution.\n• Cooperation with Authorities: The Platform will fully comply with copyright holders, legal representatives, and law enforcement, turning over the Artist/Composer's data (including IP addresses and account details) if a legitimate infringement claim is filed.",
            ),

            _buildPdfSection(
              "6. INDEMNITY AND HOLD HARMLESS",
              "The Artist/Composer agrees to completely indemnify, defend, and hold harmless the Platform, its owners, developers, and affiliates against any and all claims, lawsuits, damages, legal fees, and financial penalties arising directly or indirectly from:\n• Copyright infringement or theft of intellectual property.\n• Ownership or split disputes between band members, producers, or outside labels.\n• Any breach of the warranties provided by the Artist/Composer in this Agreement.",
            ),

            _buildPdfSection(
              "7. WITHDRAWAL OF CONTENT",
              "While the license granted is up to infinity, the Artist/Composer retains the right to request the removal of their music from the Platform.\n• The Artist/Composer must submit a formal, written request to the following email: dankiecommunication@gmail.com.\n• The Platform agrees to remove the content from its active database within a reasonable timeframe (e.g., 14-30 business days).\n• The Artist/Composer acknowledges that the Platform cannot be held responsible for copies of the music already downloaded or shared by users prior to the removal.",
            ),

            _buildPdfSection(
              "8. VOLUNTARY CONSENT AND ENTIRE AGREEMENT",
              "The Artist/Composer acknowledges that they have entered into this Agreement entirely voluntarily. This document represents the full, complete, and final agreement between the Platform and the Artist/Composer, overriding any prior verbal or written discussions.\n\nBy signing below, the Artist/Composer confirms they have read, understood, and accepted the strict liabilities, the zero-compensation terms, and the perpetual nature of this agreement up to infinity.",
            ),

            pw.SizedBox(height: 40),
            pw.Text("Artist/Composer Signature:"),
            pw.SizedBox(height: 10),
            pw.Image(signatureImage, height: 80),
            pw.SizedBox(height: 5),
            pw.Text("Printed Name: $artistName"),
            pw.Text(
              "Date Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'DANKIE_Music_Contract_${artistName.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _buildPdfSection(String title, String body) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 15),
        pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 5),
        pw.Text(body, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  // ===========================================================================
  // API SUBMISSION LOGIC
  // ===========================================================================
  Future<void> _submitSignature() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide your physical signature to agree.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final base64Signature = base64Encode(signatureBytes!);
      final String token =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';

      final uri = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/songs/bulk_sign_contract/',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'artist_name': widget.committeeMemberName,
          'signature': base64Signature,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contract Signed successfully! All your songs are now visible.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit contract: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String todayDate =
        "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
    String artistName = widget.committeeMemberName ?? "UNKNOWN ARTIST";
    String artistRole = widget.committeeMemberRole ?? "Chairperson";

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Music Distribution Contract",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isSubmitting
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 800,
                  ), // Responsive Max Width
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Profile Info
                        _buildNeumorphicContainer(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage:
                                    widget.faceUrl != null &&
                                        widget.faceUrl!.isNotEmpty
                                    ? NetworkImage(widget.faceUrl!)
                                    : null,
                                child:
                                    widget.faceUrl == null ||
                                        widget.faceUrl!.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                        size: 30,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artistName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      artistRole,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.isSigned)
                                const Icon(
                                  Icons.verified,
                                  color: Colors.green,
                                  size: 30,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Contract Document
                        _buildNeumorphicContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "ARTIST/COMPOSER CONSENT, WAIVER, AND PERPETUAL MUSIC DISTRIBUTION AGREEMENT",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildParagraph(
                                "This Agreement is made and entered into by and between:\n\nDANKIE (hereinafter referred to as \"the Platform\")\n\nand\n\n$artistName (hereinafter referred to as \"the Artist/Composer\")",
                              ),

                              _buildSectionTitle(
                                "1. PURPOSE AND BINDING NATURE OF THE DOCUMENT",
                              ),
                              _buildParagraph(
                                "The purpose of this Agreement is to establish the explicit legal terms under which the Artist/Composer grants the Platform permission to upload, host, distribute, and share their music. By signing this document, the Artist/Composer acknowledges that this is a fully enforceable, legally binding contract. Failure to read or understand these terms does not exempt the Artist/Composer from the strict liabilities outlined below.",
                              ),

                              _buildSectionTitle(
                                "2. GRANT OF RIGHTS UP TO INFINITY",
                              ),
                              _buildParagraph(
                                "The Artist/Composer hereby grants the Platform a non-exclusive, worldwide, royalty-free license to:",
                              ),
                              _buildBulletPoint(
                                "Upload, host, and store the Artist/Composer’s music on the Platform's servers indefinitely, up to infinity.",
                              ),
                              _buildBulletPoint(
                                "Distribute, broadcast, and make the music continuously available to all current and future users of the Platform.",
                              ),
                              _buildBulletPoint(
                                "Allow users to stream, download, share, and consume the music freely and without restriction.",
                              ),
                              _buildParagraph(
                                "\nUnless explicitly revoked via the formal procedure outlined in Section 7, the Platform retains the right to host and distribute the submitted music up to infinity.",
                              ),

                              _buildSectionTitle(
                                "3. STRICT ZERO-COMPENSATION AND NO-ROYALTY CLAUSE",
                              ),
                              _buildParagraph(
                                "The Artist/Composer expressly understands, acknowledges, and agrees that:",
                              ),
                              _buildBulletPoint(
                                "Zero Financial Expectation: The Artist/Composer will receive absolutely no payment, financial compensation, advances, or retroactive payouts for the distribution of their music on the Platform, now or at any point in the future.",
                              ),
                              _buildBulletPoint(
                                "No Royalties: The Platform operates strictly on a free-to-use model for this content. There will be no mechanical, performance, digital, or synchronization royalties generated or paid to the Artist/Composer by the Platform.",
                              ),
                              _buildBulletPoint(
                                "Waiver of Claims: The Artist/Composer waives any and all right to demand compensation for streams, downloads, or user engagement associated with their music on this Platform.",
                              ),

                              _buildSectionTitle(
                                "4. ABSOLUTE OWNERSHIP AND COPYRIGHT ACCOUNTABILITY",
                              ),
                              _buildParagraph(
                                "The Artist/Composer explicitly warrants and guarantees that:",
                              ),
                              _buildBulletPoint(
                                "They are the sole, rightful, and original creator of the music, or they possess the explicit, legally documented rights to distribute the master recordings and underlying compositions.",
                              ),
                              _buildBulletPoint(
                                "The music does not contain uncleared samples, stolen beats, or unauthorized vocals.",
                              ),
                              _buildBulletPoint(
                                "The music does not infringe upon the copyrights, trademarks, or intellectual property rights of any third party.",
                              ),

                              _buildSectionTitle(
                                "5. CONSEQUENCES OF UNAUTHORIZED UPLOADS (STOLEN CONTENT)",
                              ),
                              _buildParagraph(
                                "The Platform enforces a zero-tolerance policy for copyright infringement. If the Artist/Composer uploads music that belongs to another individual, entity, or record label:",
                              ),
                              _buildBulletPoint(
                                "Immediate Ban: The Artist/Composer's account will be permanently terminated without notice, losing access to all Platform services.",
                              ),
                              _buildBulletPoint(
                                "Full Legal Accountability: The Artist/Composer will be held 100% personally and legally accountable for the unauthorized distribution.",
                              ),
                              _buildBulletPoint(
                                "Cooperation with Authorities: The Platform will fully comply with copyright holders, legal representatives, and law enforcement, turning over the Artist/Composer's data (including IP addresses and account details) if a legitimate infringement claim is filed.",
                              ),

                              _buildSectionTitle(
                                "6. INDEMNITY AND HOLD HARMLESS",
                              ),
                              _buildParagraph(
                                "The Artist/Composer agrees to completely indemnify, defend, and hold harmless the Platform, its owners, developers, and affiliates against any and all claims, lawsuits, damages, legal fees, and financial penalties arising directly or indirectly from:",
                              ),
                              _buildBulletPoint(
                                "Copyright infringement or theft of intellectual property.",
                              ),
                              _buildBulletPoint(
                                "Ownership or split disputes between band members, producers, or outside labels.",
                              ),
                              _buildBulletPoint(
                                "Any breach of the warranties provided by the Artist/Composer in this Agreement.",
                              ),

                              _buildSectionTitle("7. WITHDRAWAL OF CONTENT"),
                              _buildParagraph(
                                "While the license granted is up to infinity, the Artist/Composer retains the right to request the removal of their music from the Platform.",
                              ),
                              _buildBulletPoint(
                                "The Artist/Composer must submit a formal, written request to the following email: dankiecommunication@gmail.com.",
                              ),
                              _buildBulletPoint(
                                "The Platform agrees to remove the content from its active database within a reasonable timeframe (e.g., 14-30 business days).",
                              ),
                              _buildBulletPoint(
                                "The Artist/Composer acknowledges that the Platform cannot be held responsible for copies of the music already downloaded or shared by users prior to the removal.",
                              ),

                              _buildSectionTitle(
                                "8. VOLUNTARY CONSENT AND ENTIRE AGREEMENT",
                              ),
                              _buildParagraph(
                                "The Artist/Composer acknowledges that they have entered into this Agreement entirely voluntarily. This document represents the full, complete, and final agreement between the Platform and the Artist/Composer, overriding any prior verbal or written discussions.\n\nBy signing below, the Artist/Composer confirms they have read, understood, and accepted the strict liabilities, the zero-compensation terms, and the perpetual nature of this agreement up to infinity.",
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Signature UI logic
                        const Text(
                          "Artist/Composer Signature",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (!widget.isSigned) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: darkShadow,
                                  offset: const Offset(4, 4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: lightShadow,
                                  offset: const Offset(-4, -4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Signature(
                                controller: _signatureController,
                                height: 200,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Date: $todayDate",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _signatureController.clear(),
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.redAccent,
                                ),
                                label: const Text(
                                  "Clear Signature",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildNeumorphicContainer(
                            child:
                                widget.existingSignatureBase64 != null &&
                                    widget.existingSignatureBase64!.isNotEmpty
                                ? Image.memory(
                                    base64Decode(
                                      widget.existingSignatureBase64!,
                                    ),
                                    height: 150,
                                    fit: BoxFit.contain,
                                  )
                                : const Center(
                                    child: Text(
                                      "Signature data unavailable",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Status: Verified & Locked",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),

                        // Action Button
                        GestureDetector(
                          onTap: () {
                            if (widget.isSigned &&
                                widget.existingSignatureBase64 != null) {
                              _generateAndPrintPdf(
                                widget.existingSignatureBase64!,
                              );
                            } else {
                              _submitSignature();
                            }
                          },
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: widget.isSigned
                                  ? Colors.blueGrey
                                  : backgroundColor,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: widget.isSigned
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: darkShadow,
                                        offset: const Offset(5, 5),
                                        blurRadius: 10,
                                      ),
                                      BoxShadow(
                                        color: lightShadow,
                                        offset: const Offset(-5, -5),
                                        blurRadius: 10,
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: Text(
                                widget.isSigned
                                    ? "DOWNLOAD / PRINT PDF"
                                    : "SIGN & AGREE",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isSigned
                                      ? Colors.white
                                      : Colors.black87,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNeumorphicContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: darkShadow,
            offset: const Offset(5, 5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: lightShadow,
            offset: const Offset(-5, -5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: const TextStyle(fontSize: 13, height: 1.5),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "• ",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
