import 'package:flutter/material.dart';

class PaymentOpenedDialog extends StatelessWidget {
  final VoidCallback onPaid;

  const PaymentOpenedDialog({super.key, required this.onPaid});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Icon Animation/Container ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD), // Light Blue background
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade100, width: 1),
              ),
              child: const Icon(
                Icons.open_in_browser_rounded,
                size: 40,
                color: Color(0xFF2962FF), // Primary Blue
              ),
            ),
            const SizedBox(height: 24),

            // --- Title ---
            const Text(
              "Payment Page Opened",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3E50),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // --- Body Text ---
            Text(
              "We've opened a secure payment page in a new browser tab.\n\nPlease complete the payment there, then return here to continue.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // --- Action Button ---
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onPaid,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2962FF), // Primary Blue
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                child: const Text("I Have Paid"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}