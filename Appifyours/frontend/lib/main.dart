import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Define PriceUtils class
class PriceUtils {
  static String formatPrice(double price, {String currency = '\$'}) {
    return '$currency\${price.toStringAsFixed(2)}';
  }
  
  // Extract numeric value from price string with any currency symbol
  static double parsePrice(String priceString) {
    if (priceString.isEmpty) return 0.0;
    // Remove all currency symbols and non-numeric characters except decimal point
    String numericString = priceString.replaceAll(RegExp(r'[^\\d.]'), '');
    return double.tryParse(numericString) ?? 0.0;
  }
  
  // Detect currency symbol from price string
  static String detectCurrency(String priceString) {
    if (priceString.contains('₹')) return '₹';
    if (priceString.contains('\$')) return '\$';
    if (priceString.contains('€')) return '€';
    if (priceString.contains('£')) return '£';
    if (priceString.contains('¥')) return '¥';
    if (priceString.contains('₩')) return '₩';
    if (priceString.contains('₽')) return '₽';
    if (priceString.contains('₦')) return '₦';
    if (priceString.contains('₨')) return '₨';
    return '\$'; // Default to dollar
  }
  
  static double calculateDiscountPrice(double originalPrice, double discountPercentage) {
    return originalPrice * (1 - discountPercentage / 100);
  }
  
  static double calculateTotal(List<double> prices) {
    return prices.fold(0.0, (sum, price) => sum + price);
  }
  
  static double calculateTax(double subtotal, double taxRate) {
    return subtotal * (taxRate / 100);
  }
  
  static double applyShipping(double total, double shippingFee, {double freeShippingThreshold = 100.0}) {
    return total >= freeShippingThreshold ? total : total + shippingFee;
  }
}

// Cart item model
class CartItem {
  final String id;
  final String name;
  final double price;
  final double discountPrice;
  int quantity;
  final String? image;
  
  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.discountPrice = 0.0,
    this.quantity = 1,
    this.image,
  });
  
  double get effectivePrice => discountPrice > 0 ? discountPrice : price;
  double get totalPrice => effectivePrice * quantity;
}

// Cart manager
class CartManager extends ChangeNotifier {
  final List<CartItem> _items = [];
  
  List<CartItem> get items => List.unmodifiable(_items);
  
  void addItem(CartItem item) {
    final existingIndex = _items.indexWhere((i) => i.id == item.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }
  
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
  
  void updateQuantity(String id, int quantity) {
    final item = _items.firstWhere((i) => i.id == id);
    item.quantity = quantity;
    notifyListeners();
  }
  
  void clear() {
    _items.clear();
    notifyListeners();
  }
  
  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }
  
  double get totalWithTax {
    final tax = PriceUtils.calculateTax(subtotal, 8.0); // 8% tax
    return subtotal + tax;
  }
  
  double get totalDiscount {
    return _items.fold(0.0, (sum, item) => 
      sum + ((item.price - item.effectivePrice) * item.quantity));
  }
  
  double get gstAmount {
    return PriceUtils.calculateTax(subtotal, 18.0); // 18% GST
  }
  
  double get finalTotal {
    return subtotal + gstAmount;
  }
  
  double get finalTotalWithShipping {
    return PriceUtils.applyShipping(totalWithTax, 5.99); // $5.99 shipping
  }
}

// Wishlist item model
class WishlistItem {
  final String id;
  final String name;
  final double price;
  final double discountPrice;
  final String? image;
  
  WishlistItem({
    required this.id,
    required this.name,
    required this.price,
    this.discountPrice = 0.0,
    this.image,
  });
  
  double get effectivePrice => discountPrice > 0 ? discountPrice : price;
}

// Wishlist manager
class WishlistManager extends ChangeNotifier {
  final List<WishlistItem> _items = [];
  
  List<WishlistItem> get items => List.unmodifiable(_items);
  
  void addItem(WishlistItem item) {
    if (!_items.any((i) => i.id == item.id)) {
      _items.add(item);
      notifyListeners();
    }
  }
  
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
  
  void clear() {
    _items.clear();
    notifyListeners();
  }
  
  bool isInWishlist(String id) {
    return _items.any((item) => item.id == id);
  }
}

final List<Map<String, dynamic>> productCards = [
  {
    'productName': 'okok',
    'imageAsset': null,
    'price': '299',
    'discountPrice': '199',
  },
  {
    'productName': 'rasam',
    'imageAsset': 'data:image/png;base64,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',
    'price': '100',
    'discountPrice': '1',
  },
  {
    'productName': 'rr',
    'imageAsset': 'data:image/png;base64,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',
    'price': '34',
    'discountPrice': '1',
  }
];


void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Generated E-commerce App',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: Colors.blue,
      appBarTheme: const AppBarTheme(
        elevation: 4,
        shadowColor: Colors.black38,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        elevation: 3,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        filled: true,
        fillColor: Colors.grey,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
    home: const HomePage(),
    debugShowCheckedModeBanner: false,
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  final CartManager _cartManager = CartManager();
  final WishlistManager _wishlistManager = WishlistManager();
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _filteredProducts = List.from(productCards);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) => setState(() => _currentPageIndex = index);

  void _onItemTapped(int index) {
    setState(() => _currentPageIndex = index);
    _pageController.jumpToPage(index);
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredProducts = List.from(productCards);
      } else {
        _filteredProducts = productCards.where((product) {
          final productName = (product['productName'] ?? '').toString().toLowerCase();
          final price = (product['price'] ?? '').toString().toLowerCase();
          final discountPrice = (product['discountPrice'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return productName.contains(searchLower) || price.contains(searchLower) || discountPrice.contains(searchLower);
        }).toList();
      }
    });
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'favorite':
        return Icons.favorite;
      case 'person':
        return Icons.person;
      default:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _currentPageIndex,
      children: [
        _buildHomePage(),
        _buildCartPage(),
        _buildWishlistPage(),
        _buildProfilePage(),
      ],
    ),
    bottomNavigationBar: _buildBottomNavigationBar(),
  );

  Widget _buildHomePage() {
    return Column(
      children: [
                  Container(
                    color: Color(0xff2196f3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                                                Container(
                          width: 32,
                          height: 32,
                          child: Image.memory(
                                base64Decode('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'),
                                width: 32,
                                height: 32,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.store, size: 32, color: Colors.white),
                              ),
                        ),
                        
                        const SizedBox(width: 8),
                        Text(
                          'jeeva anandh',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Stack(
                          children: [
                            const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                            if (_cartManager.items.isNotEmpty)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${_cartManager.items.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Stack(
                          children: [
                            const Icon(Icons.favorite, color: Colors.white, size: 20),
                            if (_wishlistManager.items.isNotEmpty)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${_wishlistManager.items.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                  Container(
                    height: 160,
                    child: Stack(
                      children: [
                                                Container(
                          width: double.infinity,
                          height: 160,
                          child: Image.memory(
                            base64Decode('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'),
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: Color(0xFFBDBDBD)),
                          ),
                        ),
                        
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Bunny Shop',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4.0,
                                      color: Colors.black,
                                      offset: Offset(1.0, 1.0),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text('Grillland', style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 200,
                            autoPlay: true,
                            autoPlayInterval: Duration(seconds: 3),
                            autoPlayAnimationDuration: const Duration(milliseconds: 800),
                            autoPlayCurve: Curves.fastOutSlowIn,
                            enlargeCenterPage: true,
                            scrollDirection: Axis.horizontal,
                            enableInfiniteScroll: true,
                            viewportFraction: 0.8,
                            enlargeFactor: 0.3,
                          ),
                          items: [
                            Builder(
                              builder: (BuildContext context) => Container(
                                width: 300,
                                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(Icons.image, size: 40, color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                                                const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 6.0, height: 6.0, margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.4))),
                          ],
                        ),
                        
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Color(0xFFFFFFFF),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount:                           _searchQuery.isEmpty 
                              ? productCards.length 
                              : productCards.where((product) {
                                  final productName = (product['productName'] ?? '').toString().toLowerCase();
                                  final price = (product['price'] ?? '').toString().toLowerCase();
                                  final discountPrice = (product['discountPrice'] ?? '').toString().toLowerCase();
                                  return productName.contains(_searchQuery) || price.contains(_searchQuery) || discountPrice.contains(_searchQuery);
                                }).length,
                          itemBuilder: (context, index) {
                            final filteredProducts =                             _searchQuery.isEmpty 
                                ? productCards 
                                : productCards.where((product) {
                                    final productName = (product['productName'] ?? '').toString().toLowerCase();
                                    final price = (product['price'] ?? '').toString().toLowerCase();
                                    final discountPrice = (product['discountPrice'] ?? '').toString().toLowerCase();
                                    return productName.contains(_searchQuery) || price.contains(_searchQuery) || discountPrice.contains(_searchQuery);
                                  }).toList();
                            if (index >= filteredProducts.length) return const SizedBox();
                            final product = filteredProducts[index];
                            final productId = 'product_$index';
                            final isInWishlist = _wishlistManager.isInWishlist(productId);
                            return Card(
                              elevation: 3,
                              color: Color(0xFFFFFFFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                          ),
                                          child:                                           product['imageAsset'] != null
                                              ? (product['imageAsset'] != null && product['imageAsset'].isNotEmpty
                                              ? (product['imageAsset'].startsWith('data:image/')
                                                  ? Image.memory(
                                                      base64Decode(product['imageAsset'].split(',')[1]),
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => Container(
                                                        color: Colors.grey[300],
                                                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                                                      ),
                                                    )
                                                  : Image.network(
                                                      product['imageAsset'],
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => Container(
                                                        color: Colors.grey[300],
                                                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                                                      ),
                                                    ))
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.image, size: 40, color: Colors.grey),
                                                ))
                                              : Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image, size: 40),
                                          )
                                          ,
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            onPressed: () {
                                              if (isInWishlist) {
                                                _wishlistManager.removeItem(productId);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Removed from wishlist')),
                                                );
                                              } else {
                                                final wishlistItem = WishlistItem(
                                                  id: productId,
                                                  name: product['productName'] ?? 'Product',
                                                  price: double.tryParse(product['price']?.replaceAll('\$','') ?? '0') ?? 0.0,
                                                  discountPrice: product['discountPrice'] != null && product['discountPrice'].isNotEmpty
                                                      ? double.tryParse(product['discountPrice'].replaceAll('\$','') ?? '0') ?? 0.0
                                                      : 0.0,
                                                  image: product['imageAsset'],
                                                );
                                                _wishlistManager.addItem(wishlistItem);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Added to wishlist')),
                                                );
                                              }
                                            },
                                            icon: Icon(
                                              isInWishlist ? Icons.favorite : Icons.favorite_border,
                                              color: isInWishlist ? Colors.red : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['productName'] ?? 'Product Name',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Current/Final Price (always without strikethrough)
                                              Text(
                                                                                                product['price'] ?? '$0'
                                                ,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              // Original Price (if discount exists)
                                                                                            if (product['discountPrice'] != null && product['discountPrice'].toString().isNotEmpty)
                                                Text(
                                                  product['discountPrice'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    decoration: TextDecoration.lineThrough,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.star, color: Colors.amber, size: 14),
                                              Icon(Icons.star, color: Colors.amber, size: 14),
                                              Icon(Icons.star, color: Colors.amber, size: 14),
                                              Icon(Icons.star, color: Colors.amber, size: 14),
                                              Icon(Icons.star_border, color: Colors.amber, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                product['rating'] ?? '4.0',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () {
                                                final cartItem = CartItem(
                                                  id: productId,
                                                  name: product['productName'] ?? 'Product',
                                                  price: PriceUtils.parsePrice(product['price'] ?? '0'),
                                                  discountPrice:                                                   product['discountPrice'] != null && product['discountPrice'].toString().isNotEmpty
                                                      ? PriceUtils.parsePrice(product['discountPrice'])
                                                      : 0.0
                                                  ,
                                                  image: product['imageAsset'],
                                                );
                                                _cartManager.addItem(cartItem);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Added to cart')),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  
                                                ),
                                              ),
                                              child: const Text(
                                                'Add to Cart',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.store, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'anandhu',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(child: Text('123 street', style: TextStyle(fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.email, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(child: Text('jeeva@example.com', style: TextStyle(fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(child: Text('9361266129', style: TextStyle(fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                'Â© 2023 My Store. All rights reserved.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        automaticallyImplyLeading: false,
      ),
      body: ListenableBuilder(
        listenable: _cartManager,
        builder: (context, child) {
          return _cartManager.items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _cartManager.items.length,
                    itemBuilder: (context, index) {
                      final item = _cartManager.items[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[300],
                                child: item.image != null && item.image!.isNotEmpty
                                    ? (item.image!.startsWith('data:image/')
                                    ? Image.memory(
                                  base64Decode(item.image!.split(',')[1]),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                                )
                                    : Image.network(
                                  item.image!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                                ))
                                    : const Icon(Icons.image),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    // Show current price (effective price)
                                    Text(
                                      PriceUtils.formatPrice(item.effectivePrice),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    // Show original price if there's a discount
                                    if (item.discountPrice > 0 && item.price != item.discountPrice)
                                      Text(
                                        PriceUtils.formatPrice(item.price),
                                        style: TextStyle(
                                          fontSize: 14,
                                          decoration: TextDecoration.lineThrough,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      if (item.quantity > 1) {
                                        _cartManager.updateQuantity(item.id, item.quantity - 1);
                                      } else {
                                        _cartManager.removeItem(item.id);
                                      }
                                    },
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                                  IconButton(
                                    onPressed: () {
                                      _cartManager.updateQuantity(item.id, item.quantity + 1);
                                    },
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Bill Summary Section
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            Text(PriceUtils.formatPrice(_cartManager.subtotal), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                      ),
                      if (_cartManager.totalDiscount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount', style: TextStyle(fontSize: 14, color: Colors.grey)),
                              Text('-$0.00', style: const TextStyle(fontSize: 14, color: Colors.green)),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GST (18%)', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            Text(PriceUtils.formatPrice(_cartManager.gstAmount), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Divider(thickness: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                            Text(PriceUtils.formatPrice(_cartManager.finalTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
        },
      ),
    );
  }

  Widget _buildWishlistPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        automaticallyImplyLeading: false,
      ),
      body: _wishlistManager.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your wishlist is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _wishlistManager.items.length,
              itemBuilder: (context, index) {
                final item = _wishlistManager.items[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: item.image != null && item.image!.isNotEmpty
                          ? (item.image!.startsWith('data:image/')
                          ? Image.memory(
                        base64Decode(item.image!.split(',')[1]),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                      )
                          : Image.network(
                        item.image!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image),
                      ))
                          : const Icon(Icons.image),
                    ),
                    title: Text(item.name),
                    subtitle: Text(PriceUtils.formatPrice(item.effectivePrice)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            final cartItem = CartItem(
                              id: item.id,
                              name: item.name,
                              price: item.price,
                              discountPrice: item.discountPrice,
                              image: item.image,
                            );
                            _cartManager.addItem(cartItem);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart')),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart),
                        ),
                        IconButton(
                          onPressed: () {
                            _wishlistManager.removeItem(item.id);
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProfilePage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'John Doe',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(250, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // Refund button action
                    },
                    child: const Text(
                      'Refund',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(250, 50),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // Log Out button action
                    },
                    child: const Text(
                      'Log Out',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentPageIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            label: Text('${_cartManager.items.length}'),
            isLabelVisible: _cartManager.items.length > 0,
            child: const Icon(Icons.shopping_cart),
          ),
          label: 'Cart',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            label: Text('${_wishlistManager.items.length}'),
            isLabelVisible: _wishlistManager.items.length > 0,
            child: const Icon(Icons.favorite),
          ),
          label: 'Wishlist',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

}
