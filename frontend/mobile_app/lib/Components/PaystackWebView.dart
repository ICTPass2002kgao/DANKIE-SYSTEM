import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// --- 2. WEBVIEW SCREEN (Keep this) ---
class PaystackWebView extends StatefulWidget {
  final String authUrl;
  final VoidCallback onSuccess;

  const PaystackWebView({super.key, required this.authUrl, required this.onSuccess});

  @override
  State<PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<PaystackWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('standard.paystack.co/close') || 
                request.url.contains('success')) {
              widget.onSuccess(); 
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Payment")),
      body: WebViewWidget(controller: _controller),
    );
  }
}