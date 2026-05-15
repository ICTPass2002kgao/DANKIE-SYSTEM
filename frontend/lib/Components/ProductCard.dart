import 'package:flutter/material.dart';
import 'package:ttact/Components/NeumorphicUtils.dart'; // ⭐️ IMPORTED NEUMORPHIC UTILS

class Product_Card extends StatefulWidget {
  final String? imageUrl;
  final String? categoryName;
  final String? productName;
  final double? price; 
  final VoidCallback onCartPressed;
  final String location;
  final bool isAvailable;
  final double? discountPercentage;
  final List<dynamic>? availableColors; 
  final bool isSellerProduct; 
  final Border? cardBorder; 

  const Product_Card({
    super.key,
    this.imageUrl,
    this.categoryName,
    this.productName,
    this.price,
    required this.location,
    required this.isAvailable,
    required this.onCartPressed,
    this.discountPercentage,
    required this.availableColors,
    required this.isSellerProduct, 
    this.cardBorder, 
  });

  @override
  State<Product_Card> createState() => _Product_CardState();
}

class _Product_CardState extends State<Product_Card> {
  bool _isFavorite = false;
  late double _calculatedOriginalPrice;

  static final Map<String, Color> _colorNameMap = {
    'red': Colors.red,
    'blue': Colors.blue,
    'green': Colors.green,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'brown': Colors.brown,
    'black': Colors.black,
    'white': Colors.white,
    'grey': Colors.grey,
    'teal': Colors.teal,
    'light blue': Colors.lightBlue,
    'light green': Colors.lightGreen,
    'cyan': Colors.cyan,
    'magenta': const Color.fromARGB(255, 255, 0, 255),
    'indigo': Colors.indigo,
  };

  @override
  void initState() {
    super.initState();
    _isFavorite = false;
    _calculateOriginalPrice();
  }

  void _calculateOriginalPrice() {
    if (widget.price == null || widget.price! <= 0) {
      _calculatedOriginalPrice = 0.0;
      return;
    }

    final double effectiveDiscountRate =
        (widget.discountPercentage ?? 0.0) / 100.0;

    if (effectiveDiscountRate >= 1.0 || effectiveDiscountRate < 0) {
      _calculatedOriginalPrice = widget.price!;
    } else {
      _calculatedOriginalPrice = widget.price! / (1 - effectiveDiscountRate);
    }

    if (_calculatedOriginalPrice <= widget.price! + 0.01) {
      _calculatedOriginalPrice = widget.price!;
    }
  }

  Color _getColorFromName(String colorName) {
    return _colorNameMap[colorName.toLowerCase()] ?? Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ⭐️ NEUMORPHIC PRODUCT CARD
    return Container(
      decoration: NeumorphicUtils.decoration(
        context: context,
        radius: 20,
      ).copyWith(
        border: widget.cardBorder,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Image.network(
                    widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                        ? widget.imageUrl!
                        : 'https://via.placeholder.com/150',
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.hintColor.withOpacity(0.1),
                        child: Icon(
                          Icons.broken_image,
                          color: theme.hintColor,
                          size: 50,
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFavorite = !_isFavorite;
                        if (_isFavorite) {
                          print('${widget.productName ?? 'Product'} liked!');
                        } else {
                          print('${widget.productName ?? 'Product'} unliked!');
                        }
                      });
                    },
                    // ⭐️ NEUMORPHIC FAVORITE BUTTON
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: NeumorphicUtils.decoration(
                        context: context,
                        isPressed: _isFavorite, // Inset when favorited
                        radius: 20, // Circular
                      ),
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : theme.primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.productName ?? 'Product Name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From: ${widget.location}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.primaryColor,
                      fontStyle: FontStyle.normal,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAvailable ? 'Available' : 'Unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: widget.isAvailable
                                    ? Colors.green[600]
                                    : Colors.red,
                              ),
                            ),
                            if (widget.availableColors != null &&
                                widget.availableColors!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: widget.availableColors!
                                        .map(
                                          (colorName) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 4.0,
                                            ),
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: _getColorFromName(
                                                  colorName,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      colorName.toLowerCase() ==
                                                              'white'
                                                          ? Colors.grey.shade400
                                                          : Colors.transparent,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_calculatedOriginalPrice >
                                    (widget.price ?? 0.0) &&
                                (widget.discountPercentage ?? 0.0) > 0)
                              Text(
                                'R${_calculatedOriginalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: theme.hintColor,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: theme.hintColor,
                                ),
                              ),
                            if (widget.discountPercentage != null &&
                                widget.discountPercentage! > 0)
                              Text(
                                '${widget.discountPercentage!}% OFF',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              widget.price != null
                                  ? 'R${widget.price!.toStringAsFixed(2)}'
                                  : 'Price N/A',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
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
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PRODUCT DETAILS COMPONENT
// -----------------------------------------------------------------------------
