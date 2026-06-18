import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:ttact/Components/API.dart';

class TactsoContitution extends StatelessWidget {
  const TactsoContitution({super.key});

  // Point directly to your local file path
  final String documentPath = "https://firebasestorage.googleapis.com/v0/b/tact-3c612.firebasestorage.app/o/Constitutions%2FThe%20TACTSO%20Draft%20Constitution%20'25.pdf?alt=media&token=9f9fb04d-5628-40cd-886e-39524b97622c";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Api().neumoBaseColor(context),
      body: SizedBox.expand(
        child: SfPdfViewer.network(
          documentPath,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            print("PDF Load Error: ${details.error}");
            print("PDF Load Description: ${details.description}");
          },
        ),
      ),
    );
  }
}
