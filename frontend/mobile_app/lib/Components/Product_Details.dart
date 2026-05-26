import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class ProductDetails extends StatefulWidget {
  final Map<String, dynamic> productDetails;
  final String sellerProductId;
  final void Function(String?, String?) onAddToCart;
  final bool isStandalone;
  final VoidCallback? onClose;

  const ProductDetails({
    super.key,
    required this.productDetails,
    required this.sellerProductId,
    required this.onAddToCart,
    this.isStandalone = false,
    this.onClose,
  });

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  String? _selectedColor;
  String? _selectedSize;
  final TextEditingController _customSizeController = TextEditingController();

  final Map<String, Color> _colorMap = {
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Black': Colors.black,
    'White': Colors.white,
    'Yellow': Colors.yellow,
    'Pink': Colors.pink,
    'Purple': Colors.purple,
    'Orange': Colors.orange,
    'Brown': Colors.brown,
    'Grey': Colors.grey,
    'Cyan': Colors.cyan,
    'Magenta': const Color.fromARGB(255, 255, 0, 255),
    'Teal': Colors.teal,
    'Indigo': Colors.indigo,
    'Navy': const Color(0xFF000080),
    'Maroon': const Color(0xFF800000),
  };

  @override
  void initState() {
    super.initState();
    _incrementProductView();

    // Auto-select defaults
    final List<dynamic> availableColors =
        widget.productDetails['availableColors'] ?? [];
    if (availableColors.isNotEmpty) {
      _selectedColor = availableColors.first.toString();
    }

    final List<dynamic> availableSizes =
        widget.productDetails['availableSizes'] ?? [];
    if (availableSizes.isNotEmpty) {
      String firstSize = availableSizes.first.toString();
      if (availableSizes.length == 1 && firstSize == 'All') {
        _selectedSize = null;
      } else {
        _selectedSize = firstSize;
      }
    }
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  Future<void> _incrementProductView() async {}

  void _handleClose() {
    if (widget.isStandalone) {
      widget.onClose?.call();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<dynamic> rawColors =
        widget.productDetails['availableColors'] ?? [];
    final List<String> availableColors = rawColors
        .map((e) => e.toString())
        .toList();

    final List<dynamic> rawSizes =
        widget.productDetails['availableSizes'] ?? [];
    final List<String> availableSizes = rawSizes
        .map((e) => e.toString())
        .toList();

    final bool allSizesAvailable =
        availableSizes.length == 1 && availableSizes[0] == 'All';

    String imageUrl = widget.productDetails['imageUrl'] ?? '';
    bool isValidImage = imageUrl.isNotEmpty && !imageUrl.startsWith('blob:');

    return Container(
      padding: widget.isStandalone
          ? EdgeInsets.zero
          : const EdgeInsets.all(20.0),
      // ⭐️ NEUMORPHIC DETAILS WRAPPER (only if it's the bottom sheet variant)
      decoration: widget.isStandalone
          ? null
          : NeumorphicUtils.decoration(
              context: context,
              radius: 30, // For the top edges of the bottom sheet
            ).copyWith(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            if (widget.isStandalone)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close, color: theme.hintColor),
                  onPressed: _handleClose,
                ),
              )
            else
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.hintColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ⭐️ NEUMORPHIC IMAGE FRAME
            Center(
              child: Container(
                decoration: NeumorphicUtils.decoration(
                  context: context,
                  isPressed: true, // Inset look for the image placeholder
                  radius: 20,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: isValidImage
                      ? Image.network(
                          imageUrl,
                          height: widget.isStandalone ? 200 : 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Product Name
            Text(
              widget.productDetails['productName'] ?? 'Unknown Product',
              style: TextStyle(
                fontSize: widget.isStandalone ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),

            // Price
            Row(
              children: [
                Text(
                  'R${(widget.productDetails['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: widget.isStandalone ? 22 : 24,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                if ((widget.productDetails['discountPercentage'] as num? ?? 0) >
                    0)
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(widget.productDetails['discountPercentage'] as num).toInt()}% OFF',
                        style: TextStyle(
                          fontSize: widget.isStandalone ? 14 : 16,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              widget.productDetails['description'] ??
                  'No description provided.',
              style: TextStyle(
                fontSize: widget.isStandalone ? 14 : 16,
                color: theme.hintColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Colors
            if (availableColors.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Colors:',
                    style: TextStyle(
                      fontSize: widget.isStandalone ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 12.0,
                    children: availableColors.map((color) {
                      final bool isSelected = (_selectedColor == color);
                      final Color chipColor = _colorMap[color] ?? Colors.grey;

                      // ⭐️ NEUMORPHIC COLOR CHIP
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = isSelected ? null : color;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration:
                              NeumorphicUtils.decoration(
                                context: context,
                                isPressed: isSelected, // Pressed when selected
                                radius: 12,
                              ).copyWith(
                                color: isSelected
                                    ? theme.primaryColor.withOpacity(0.1)
                                    : null,
                                border: isSelected
                                    ? Border.all(
                                        color: theme.primaryColor,
                                        width: 1,
                                      )
                                    : null,
                              ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: chipColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.toLowerCase() == 'white'
                                        ? Colors.grey
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                color,
                                style: TextStyle(
                                  color: isSelected
                                      ? theme.primaryColor
                                      : theme.hintColor,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),

            // Sizes
            if (availableSizes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Sizes:',
                    style: TextStyle(
                      fontSize: widget.isStandalone ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (allSizesAvailable)
                    // ⭐️ NEUMORPHIC TEXT FIELD
                    Container(
                      decoration: NeumorphicUtils.decoration(
                        context: context,
                        isPressed: true, // Inset text box
                        radius: 12,
                      ),
                      child: TextField(
                        controller: _customSizeController,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.all(16),
                          hintText: "Enter your size (e.g., M, 32, 7)",
                          hintStyle: TextStyle(
                            color: theme.hintColor.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedSize = value.trim();
                          });
                        },
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12.0,
                      runSpacing: 12.0,
                      children: availableSizes.map((size) {
                        final bool isSelected = (_selectedSize == size);

                        // ⭐️ NEUMORPHIC SIZE CHIP
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSize = isSelected ? null : size;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration:
                                NeumorphicUtils.decoration(
                                  context: context,
                                  isPressed:
                                      isSelected, // Pressed when selected
                                  radius: 12,
                                ).copyWith(
                                  color: isSelected
                                      ? theme.primaryColor.withOpacity(0.1)
                                      : null,
                                  border: isSelected
                                      ? Border.all(
                                          color: theme.primaryColor,
                                          width: 1,
                                        )
                                      : null,
                                ),
                            child: Text(
                              size,
                              style: TextStyle(
                                color: isSelected
                                    ? theme.primaryColor
                                    : theme.hintColor,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 30),
                ],
              ),

            // ⭐️ NEUMORPHIC ADD TO CART BUTTON
            GestureDetector(
              onTap: () {
                final bool colorRequired = availableColors.isNotEmpty;
                final bool sizeRequired = availableSizes.isNotEmpty;

                if (colorRequired && _selectedColor == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a color.')),
                  );
                  return;
                }

                if (sizeRequired &&
                    (_selectedSize == null || _selectedSize!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select or enter a size.'),
                    ),
                  );
                  return;
                }

                widget.onAddToCart(_selectedColor, _selectedSize);
                _handleClose();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: NeumorphicUtils.decoration(
                  context: context,
                  radius: 15,
                ).copyWith(color: theme.primaryColor),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_shopping_cart,
                      color: theme.scaffoldBackgroundColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Add to Cart',
                      style: TextStyle(
                        color: theme.scaffoldBackgroundColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: widget.isStandalone ? 200 : 250,
      width: double.infinity,
      color: Theme.of(context).hintColor.withOpacity(0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 50,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: 8),
          Text(
            "Image Unavailable",
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}
