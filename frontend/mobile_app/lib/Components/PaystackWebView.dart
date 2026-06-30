// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ttact/Components/API.dart';
import 'package:webview_flutter/webview_flutter.dart';

// --- 2. WEBVIEW SCREEN (Keep this) ---
class PaystackWebView extends StatefulWidget {
  final String authUrl;
  final VoidCallback onSuccess;

  const PaystackWebView({
    super.key,
    required this.authUrl,
    required this.onSuccess,
  });

  @override
  State<PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<PaystackWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Removed Expanded here so the AppBar takes only the space it needs
            Api().buildAppBar(context, "Secure Payment") ?? const SizedBox(),

            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const Center(
                      child: CupertinoActivityIndicator(radius: 15),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}