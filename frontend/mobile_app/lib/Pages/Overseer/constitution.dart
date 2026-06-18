import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:ttact/Components/API.dart';

class Constitution extends StatelessWidget {
  const Constitution({super.key});

  final String documentUrl =
      "https://firebasestorage.googleapis.com/v0/b/tact-3c612.firebasestorage.app/o/Constitutions%2F2025%20%5BFinal%5D%20The%20TACTYO%20Constitution%20-%2014%20April%202025.pdf?alt=media&token=5ff111a1-82c1-4e28-828b-409f79154f2d";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Api().neumoBaseColor(context),
      body: SfPdfViewer.network(
        canShowPageLoadingIndicator: false,
        documentUrl,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
