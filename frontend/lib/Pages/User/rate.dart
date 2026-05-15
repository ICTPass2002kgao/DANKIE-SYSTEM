import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:ttact/Components/API.dart';

class RateUsDialog extends StatefulWidget {
  @override
  _RateUsDialogState createState() => _RateUsDialogState();
}

class _RateUsDialogState extends State<RateUsDialog> {
  int _rating = 0;

  void _submitRating() async {
    Navigator.of(context).pop(); // Close dialog

    // Capture context-dependent values before async gap
    final BuildContext dialogContext = context;
    final Color primaryColorDark = Theme.of(context).primaryColorDark;

    final InAppReview inAppReview = InAppReview.instance;
    try {
      if (await inAppReview.isAvailable()) {
        inAppReview.requestReview();
      } else {
        // Provide a valid appStoreId for iOS, and a valid microsoftStoreId for Windows if needed
        await inAppReview.openStoreListing(
          appStoreId:
              'YOUR_APP_STORE_ID', // Replace with your actual App Store ID
          microsoftStoreId: null,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Api().showMessage(dialogContext, e.toString(), '', primaryColorDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return AlertDialog(
      title: Text('Rate Us'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Would you mind taking a moment to rate us?'
            ' A 5-star rating from you inspires us to serve you better.',
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: color.primaryColor,
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
              );
            }),
          ),
        ],
      ),
      actions: [
        CupertinoButton(
          child: Text('Later'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        CupertinoButton(
          child: Text('Rate Now'),
          onPressed: _rating > 0 ? _submitRating : null,
        ),
      ],
    );
  }
}
