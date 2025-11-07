import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

// Define PriceUtils class
class PriceUtils {
  static String formatPrice(double price, {String currency = '\$'}) {
    return '\${currency}\${price.toStringAsFixed(2)}';
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

// Dynamic Data Service for MongoDB Integration
class DynamicDataService {
  static const String baseUrl = 'https://your-backend-url.com'; // Replace with your backend URL
  static const String screenId = 'Bunny Shop'; // Screen identifier
  static Map<String, dynamic>? _cachedData;
  static String? _lastModified;
  
  static Future<Map<String, dynamic>?> fetchConfiguration() async {
    try {
      final response = await http.get(
        Uri.parse('\$baseUrl/api/form-screen-config/\$screenId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _cachedData = data['data'];
          _lastModified = data['data']['lastModified'];
          return _cachedData;
        }
      }
    } catch (e) {
      print('Error fetching configuration: \$e');
    }
    return null;
  }
  
  static Future<bool> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('\$baseUrl/api/form-screen-config/check/\$screenId?lastModified=\$_lastModified'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true && data['hasUpdates'] == true;
      }
    } catch (e) {
      print('Error checking for updates: \$e');
    }
    return false;
  }
  
  static List<Map<String, dynamic>> getProductCards() {
    if (_cachedData != null && _cachedData!['dynamicFields'] != null) {
      final productCards = _cachedData!['dynamicFields']['productCards'];
      if (productCards is List) {
        return List<Map<String, dynamic>>.from(productCards);
      }
    }
    return fallbackProductCards;
  }
  
  static String getGstNumber() {
    if (_cachedData != null && _cachedData!['dynamicFields'] != null) {
      return _cachedData!['dynamicFields']['gstNumber'] ?? '18';
    }
    return '18';
  }
  
  static String getSelectedCategory() {
    if (_cachedData != null && _cachedData!['dynamicFields'] != null) {
      return _cachedData!['dynamicFields']['selectedCategory'] ?? 'Piece';
    }
    return 'Piece';
  }
  
  static Map<String, dynamic> getStoreInfo() {
    if (_cachedData != null && _cachedData!['dynamicFields'] != null) {
      final storeInfo = _cachedData!['dynamicFields']['storeInfo'];
      if (storeInfo is Map<String, dynamic>) {
        return storeInfo;
      }
    }
    return fallbackStoreInfo;
  }
}

// Fallback data (embedded in APK for offline support)
final List<Map<String, dynamic>> fallbackProductCards = [
  {
    'productName': 'Product ',
    'imageAsset': null,
    'price': '299',
    'discountPrice': '199',
  }
];



final Map<String, dynamic> fallbackStoreInfo = {
  'storeName': 'My Store',
  'address': '123 Main St',
  'email': 'support@example.com',
  'phone': '(123) 456-7890',
};


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
  bool _isLoading = true;
  Timer? _pollingTimer;
  
  // Dynamic data variables
  List<Map<String, dynamic>> productCards = [];
  String gstNumber = '';
  String selectedCategory = '';
  Map<String, dynamic> storeInfo = {};
  List<Map<String, dynamic>> fallbackProductCards = [];
  Map<String, dynamic> fallbackStoreInfo = {
    'storeName': 'My Store',
    'address': '123 Main St',
    'email': 'support@example.com',
    'phone': '(123) 456-7890',
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // Initialize fallback data - will be populated from generated code
    fallbackProductCards = [];
    _loadInitialData();
    _startPolling();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // Try to fetch dynamic data first
    final config = await DynamicDataService.fetchConfiguration();
    
    if (config != null) {
      // Update global variables with fetched data
      productCards = DynamicDataService.getProductCards();
      gstNumber = DynamicDataService.getGstNumber();
      selectedCategory = DynamicDataService.getSelectedCategory();
      storeInfo = DynamicDataService.getStoreInfo();
    } else {
      // Use fallback data if API fails
      productCards = List.from(fallbackProductCards);
      gstNumber = DynamicDataService.getGstNumber();
      selectedCategory = DynamicDataService.getSelectedCategory();
      storeInfo = DynamicDataService.getStoreInfo();
    }
    
    setState(() {
      _filteredProducts = List.from(productCards);
      _isLoading = false;
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final hasUpdates = await DynamicDataService.checkForUpdates();
      if (hasUpdates) {
        await _loadInitialData();
      }
    });
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pollingTimer?.cancel();
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
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading configuration...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
                  Container(
                    color: Color(0xff2196f3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.store, size: 32, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'priya',
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (value) {
                            _filterProducts(value);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search products by name or price',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: const Icon(Icons.filter_list),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Search by product name or price (e.g., "Product Name" or "\$299")',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
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
                            final productId = 'product_\$index';
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
                                                  price: double.tryParse(product['price']?.replaceAll('\\\$','') ?? '0') ?? 0.0,
                                                  discountPrice: product['discountPrice'] != null && product['discountPrice'].isNotEmpty
                                                      ? double.tryParse(product['discountPrice'].replaceAll('\\\$','') ?? '0') ?? 0.0
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
                                                                                                product['price'] ?? '\$0'
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode('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'),
                                    width: 300,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: Colors.grey[300],
                                      child: const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)),
                                    ),
                                  ),
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
                ],
              ),
            ),
          ),
        ],
      ),
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
