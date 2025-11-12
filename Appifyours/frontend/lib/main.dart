import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:provider/provider.dart';

// Dynamic Configuration Manager for Live Updates
class DynamicConfigManager extends ChangeNotifier {
  static const String baseUrl = 'http://192.168.1.5:5000';
  static const String userId = '69021d2a2b0d7cd49d0bf5b4'; // Replace with actual user ID
  
  Map<String, dynamic>? _appConfig;
  List<Map<String, dynamic>> _productCards = [];
  Map<String, dynamic> _storeInfo = {};
  String _gstNumber = '18';
  String _selectedCategory = 'Piece';
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  
  // Getters
  Map<String, dynamic>? get appConfig => _appConfig;
  List<Map<String, dynamic>> get productCards => _productCards;
  Map<String, dynamic> get storeInfo => _storeInfo;
  String get gstNumber => _gstNumber;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  DynamicConfigManager() {
    _loadConfig();
    _startAutoRefresh();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  // Start auto-refresh every 5 seconds
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _loadConfig(showLoading: false);
    });
  }
  
  // Load configuration from backend
  Future<void> _loadConfig({bool showLoading = true}) async {
    try {
      if (showLoading) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/app/dynamic/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _appConfig = data['config'];
          
          // Extract dynamic data from config
          if (_appConfig?['pages'] != null) {
            _extractDynamicData(_appConfig!['pages']);
          }
          
          _isLoading = false;
          _error = null;
          notifyListeners();
          print('✅ Dynamic config loaded successfully');
        } else {
          throw Exception(data['message'] ?? 'Failed to load config');
        }
      } else if (response.statusCode == 404) {
        // No config found, use default values
        _isLoading = false;
        _error = null;
        notifyListeners();
        print('ℹ️ No dynamic config found, using defaults');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading dynamic config: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Extract dynamic data from pages
  void _extractDynamicData(List<dynamic> pages) {
    _productCards.clear();
    
    for (var page in pages) {
      if (page['widgets'] != null) {
        for (var widget in page['widgets']) {
          // Extract product cards
          if (widget['name'] == 'Catalog View Card' || widget['name'] == 'Product Detail Card') {
            final productCards = widget['properties']?['productCards'];
            if (productCards != null && productCards is List) {
              _productCards.addAll(List<Map<String, dynamic>>.from(productCards));
            }
          }
          
          // Extract store info
          if (widget['name'] == 'Store Info' && widget['properties'] != null) {
            _storeInfo = Map<String, dynamic>.from(widget['properties']);
          }
          
          // Extract GST number
          if (widget['properties']?['gstNumber'] != null) {
            _gstNumber = widget['properties']['gstNumber'].toString();
          }
          
          // Extract category
          if (widget['properties']?['selectedCategory'] != null) {
            _selectedCategory = widget['properties']['selectedCategory'].toString();
          }
        }
      }
    }
  }
  
  // Manual refresh
  Future<void> refresh() async {
    await _loadConfig();
  }
}

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

void main() => runApp(const DynamicMyApp());

class DynamicMyApp extends StatefulWidget {
  const DynamicMyApp({super.key});

  @override
  _DynamicMyAppState createState() => _DynamicMyAppState();
}

class _DynamicMyAppState extends State<DynamicMyApp> {
  late DynamicConfigManager configManager;

  @override
  void initState() {
    super.initState();
    configManager = DynamicConfigManager();
  }

  @override
  void dispose() {
    configManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DynamicConfigManager>.value(
      value: configManager,
      child: Consumer<DynamicConfigManager>(
        builder: (context, config, child) {
          // Dynamic theme color from config
          Color primaryColor = Colors.blue;
          try {
            if (config.appConfig?['themeColor'] != null) {
              primaryColor = Color(int.parse(
                config.appConfig!['themeColor'].replaceAll('#', '0xFF')
              ));
            }
          } catch (e) {
            primaryColor = Colors.blue; // Fallback
          }

          return MaterialApp(
            title: config.appConfig?['appName'] ?? 'Dynamic E-commerce App',
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorSchemeSeed: primaryColor,
              appBarTheme: AppBarTheme(
                elevation: 4,
                shadowColor: Colors.black38,
                backgroundColor: primaryColor,
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
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
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
            home: const DynamicSplashScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// API Configuration
class ApiConfig {
  static const String baseUrl = 'http://192.168.1.5:5000';
  static const String adminObjectId = '690dc087abc99370793b9150';
}

// Dynamic Splash Screen - Uses DynamicConfigManager
class DynamicSplashScreen extends StatefulWidget {
  const DynamicSplashScreen({super.key});

  @override
  State<DynamicSplashScreen> createState() => _DynamicSplashScreenState();
}

class _DynamicSplashScreenState extends State<DynamicSplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DynamicSignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicConfigManager>(
      builder: (context, config, child) {
        String appName = config.appConfig?['appName'] ?? 'Dynamic App';
        if (config.isLoading) {
          appName = 'Loading...';
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon with animation
                  TweenAnimationBuilder(
                    duration: const Duration(seconds: 2),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shopping_bag,
                            size: 60,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  
                  // App Name
                  Text(
                    appName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Subtitle
                  const Text(
                    'Dynamic E-commerce Experience',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // Loading indicator
                  if (config.isLoading)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            config.error == null ? Icons.check_circle : Icons.error,
                            color: config.error == null ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            config.error == null ? 'Connected' : 'Offline Mode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Dynamic Sign In Page - Uses DynamicConfigManager
class DynamicSignInPage extends StatefulWidget {
  const DynamicSignInPage({super.key});

  @override
  State<DynamicSignInPage> createState() => _DynamicSignInPageState();
}

class _DynamicSignInPageState extends State<DynamicSignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.5:5000/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DynamicHomePage()),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Login failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicConfigManager>(
      builder: (context, config, child) {
        String appName = config.appConfig?['appName'] ?? 'Dynamic App';
        Color primaryColor = Colors.blue;
        
        try {
          if (config.appConfig?['themeColor'] != null) {
            primaryColor = Color(int.parse(
              config.appConfig!['themeColor'].replaceAll('#', '0xFF')
            ));
          }
        } catch (e) {
          primaryColor = Colors.blue;
        }

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primaryColor.withOpacity(0.8), primaryColor],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App branding
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shopping_bag,
                        size: 50,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Login form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Sign In', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const DynamicSignUpPage()),
                              );
                            },
                            child: Text(
                              'Don\'t have an account? Sign Up',
                              style: TextStyle(color: primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Live sync indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            config.error == null ? Icons.sync : Icons.sync_problem,
                            color: config.error == null ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            config.error == null ? 'Live Sync Active' : 'Offline Mode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Dynamic Sign Up Page
class DynamicSignUpPage extends StatefulWidget {
  const DynamicSignUpPage({super.key});

  @override
  State<DynamicSignUpPage> createState() => _DynamicSignUpPageState();
}

class _DynamicSignUpPageState extends State<DynamicSignUpPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_firstNameController.text.isEmpty || 
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.5:5000/api/user/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'phone': _phoneController.text.trim(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Account created successfully! Welcome ${_firstNameController.text}!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context); // Go back to sign in
          }
        } else {
          throw Exception(data['message'] ?? 'Signup failed');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Signup failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicConfigManager>(
      builder: (context, config, child) {
        String appName = config.appConfig?['appName'] ?? 'Dynamic App';
        Color primaryColor = Colors.blue;
        
        try {
          if (config.appConfig?['themeColor'] != null) {
            primaryColor = Color(int.parse(
              config.appConfig!['themeColor'].replaceAll('#', '0xFF')
            ));
          }
        } catch (e) {
          primaryColor = Colors.blue;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Sign Up - $appName'),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email ID *',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Create Account', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Dynamic Home Page - Uses DynamicConfigManager for live product updates
class DynamicHomePage extends StatefulWidget {
  const DynamicHomePage({super.key});

  @override
  State<DynamicHomePage> createState() => _DynamicHomePageState();
}

class _DynamicHomePageState extends State<DynamicHomePage> {
  final CartManager _cartManager = CartManager();
  final WishlistManager _wishlistManager = WishlistManager();

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicConfigManager>(
      builder: (context, config, child) {
        String appName = config.appConfig?['appName'] ?? 'Dynamic App';
        Color primaryColor = Colors.blue;
        
        try {
          if (config.appConfig?['themeColor'] != null) {
            primaryColor = Color(int.parse(
              config.appConfig!['themeColor'].replaceAll('#', '0xFF')
            ));
          }
        } catch (e) {
          primaryColor = Colors.blue;
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.shopping_bag, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(appName, style: const TextStyle(color: Colors.white))),
                // Live sync indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: config.error == null ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        config.error == null ? Icons.sync : Icons.sync_problem,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        config.error == null ? 'LIVE' : 'OFFLINE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            actions: [
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await config.refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ Data refreshed successfully!'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                tooltip: 'Refresh Data',
              ),
              // Cart icon
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () {
                      _showCartBottomSheet(context);
                    },
                  ),
                  if (_cartManager.items.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${_cartManager.items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await config.refresh();
            },
            child: config.isLoading && config.productCards.isEmpty
                ? _buildLoadingState()
                : config.productCards.isEmpty
                    ? _buildEmptyState(config)
                    : _buildProductGrid(config, primaryColor),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading products...'),
          SizedBox(height: 8),
          Text(
            'Fetching latest data from server',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(DynamicConfigManager config) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            config.error != null ? Icons.cloud_off : Icons.inventory_2,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            config.error != null ? 'Connection Error' : 'No Products Available',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            config.error != null 
                ? 'Unable to fetch latest products. Using offline mode.'
                : 'Products will appear here when added to your store.',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await config.refresh();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(DynamicConfigManager config, Color primaryColor) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: config.productCards.length,
      itemBuilder: (context, index) {
        final product = config.productCards[index];
        return _buildProductCard(product, primaryColor);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, Color primaryColor) {
    final String name = product['name'] ?? 'Unknown Product';
    final String price = product['price'] ?? '0';
    final String image = product['image'] ?? '';
    final String description = product['description'] ?? '';
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[200],
              ),
              child: image.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image_not_supported, size: 50, color: Colors.grey);
                        },
                      ),
                    )
                  : const Icon(Icons.shopping_bag, size: 50, color: Colors.grey),
            ),
          ),
          
          // Product Details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price.startsWith('₹') ? price : '₹$price',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final wishlistItem = WishlistItem(
                                id: product['id'] ?? name,
                                name: name,
                                price: double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0,
                                image: image,
                              );
                              
                              if (_wishlistManager.isInWishlist(wishlistItem.id)) {
                                _wishlistManager.removeItem(wishlistItem.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Removed from wishlist')),
                                );
                              } else {
                                _wishlistManager.addItem(wishlistItem);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Added to wishlist')),
                                );
                              }
                            },
                            child: Icon(
                              _wishlistManager.isInWishlist(product['id'] ?? name)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final cartItem = CartItem(
                                id: product['id'] ?? name,
                                name: name,
                                price: double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0,
                                image: image,
                              );
                              
                              _cartManager.addItem(cartItem);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added $name to cart'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Shopping Cart',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _cartManager.items.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Your cart is empty', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _cartManager.items.length,
                        itemBuilder: (context, index) {
                          final item = _cartManager.items[index];
                          return ListTile(
                            leading: item.image?.isNotEmpty == true
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item.image!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.image_not_supported),
                                        );
                                      },
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.shopping_bag),
                                  ),
                            title: Text(item.name),
                            subtitle: Text('₹${item.effectivePrice.toStringAsFixed(2)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
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
                                Text('${item.quantity}'),
                                IconButton(
                                  onPressed: () {
                                    _cartManager.updateQuantity(item.id, item.quantity + 1);
                                  },
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_cartManager.items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            '₹${_cartManager.finalTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Checkout functionality coming soon!'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          child: const Text('Checkout'),
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
}

// Original Splash Screen - First screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _appName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchAppNameAndNavigate();
  }

  Future<void> _fetchAppNameAndNavigate() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin-element-screen/${ApiConfig.adminObjectId}/shop-name'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _appName = data['shopName'] ?? 'AppifyYours';
          });
        }
      }
    } catch (e) {
      print('Error fetching shop name: \$e');
      if (mounted) {
        setState(() {
          _appName = 'AppifyYours';
        });
      }
    }
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade400, Colors.blue.shade800],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(
                Icons.shopping_bag,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                _appName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: Colors.white),
              const Spacer(),
              const Text(
                'Powered by AppifyYours',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Sign In Page
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          throw Exception(data['error'] ?? 'Sign in failed');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Invalid credentials');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: \${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Icon(
                Icons.shopping_bag,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign In', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateAccountPage(),
                    ),
                  );
                },
                child: const Text('Create Your Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Create Account Page
class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+.[a-zA-Z]{2,4}$').hasMatch(email);
  }

  bool _validatePhone(String phone) {
    return RegExp(r'^[0-9]{10}$').hasMatch(phone);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  Future<void> _createAccount() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (!_validateEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    if (!_validatePhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    if (!_validatePassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.5:5000/api/user/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully! Please sign in.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to create account');
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create account');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: 2.718281828459045'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Join Us Today',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your account to get started',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  hintText: '10 digit number',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email ID',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                        const Icon(Icons.store, size: 32, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'jeeva jeevsss',
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
                            hintText: 'Search names and prices',
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
                    height: 160,
                    child: Stack(
                      children: [
                        Container(color: Color(0xFFBDBDBD)),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'jiji',
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
                                child: Text('Shop Now', style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // Log out and navigate to sign in page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignInPage(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Log Out',
                      style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.w600),
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
