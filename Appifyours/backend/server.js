const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// MongoDB connection - Connect to main Appifyours database for dynamic data
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb+srv://appifyours:appifyours123@cluster0.mongodb.net/appifyours?retryWrites=true&w=majority';

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(() => {
  console.log('✅ Connected to MongoDB - Appifyours Database');
  console.log('📱 Admin ID: 690dc087abc99370793b9150');
}).catch(err => {
  console.error('❌ MongoDB connection error:', err);
});

// Admin Element Screen Schema - For fetching app configuration dynamically
const adminElementScreenSchema = new mongoose.Schema({
  userId: String,
  shopName: String,
  appName: String,
  category: String,
  pages: [{ name: String, widgets: [{ name: String, properties: mongoose.Schema.Types.Mixed }] }],
  dynamicFields: {
    gstNumber: String,
    selectedCategory: String,
    productCards: [mongoose.Schema.Types.Mixed],
    storeInfo: mongoose.Schema.Types.Mixed,
    orderSummary: mongoose.Schema.Types.Mixed
  },
  screenConfig: {
    screenName: String,
    fields: [mongoose.Schema.Types.Mixed]
  },
  status: String,
  createdAt: Date,
  updatedAt: Date
}, { collection: 'adminelementscreens' });

const AdminElementScreen = mongoose.model('AdminElementScreen', adminElementScreenSchema);

// Users Create Account Schema - For end-user authentication
const usersCreateAccountSchema = new mongoose.Schema({
  adminObjectId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true, ref: 'AdminElementScreen' },
  firstName: { type: String, required: true, trim: true },
  lastName: { type: String, required: true, trim: true },
  email: { type: String, required: true, lowercase: true, trim: true },
  password: { type: String, required: true },
  phone: { type: String, required: true, trim: true },
  countryCode: { type: String, default: '+91' },
  fullName: String,
  purchaseHistory: [{ productId: String, productName: String, quantity: Number, price: Number, purchaseDate: Date }],
  wishlist: [{ productId: String, productName: String, productPrice: Number, addedAt: Date }],
  cart: [{ productId: String, productName: String, quantity: Number, price: Number, addedAt: Date }],
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, { collection: 'users_create_account' });

usersCreateAccountSchema.index({ adminObjectId: 1, email: 1 }, { unique: true });
const UsersCreateAccount = mongoose.model('UsersCreateAccount', usersCreateAccountSchema);

// JWT Secret
const JWT_SECRET = process.env.JWT_SECRET || 'appifyours-secret-key-change-in-production';

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ success: false, error: 'Access token required' });
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ success: false, error: 'Invalid or expired token' });
    req.user = user;
    next();
  });
};

// API Routes

// Get screen configuration dynamically
app.get('/api/get-screen-config', async (req, res) => {
  try {
    const { screen, adminObjectId } = req.query;
    if (!adminObjectId || !mongoose.Types.ObjectId.isValid(adminObjectId)) {
      return res.status(400).json({ success: false, error: 'Valid adminObjectId is required' });
    }
    const appConfig = await AdminElementScreen.findById(adminObjectId);
    if (!appConfig) {
      return res.status(404).json({ success: false, error: 'Screen configuration not found' });
    }
    // Return screen config with default fields if not configured
    const screenConfig = appConfig.screenConfig || {
      screenName: screen || 'form_screen',
      fields: [
        { type: 'text', label: 'First Name', key: 'firstName', required: true },
        { type: 'text', label: 'Last Name', key: 'lastName', required: true },
        { type: 'email', label: 'Email', key: 'email', required: true },
        { type: 'phone', label: 'Phone', key: 'phone', required: true },
        { type: 'password', label: 'Password', key: 'password', required: true },
        { type: 'button', label: 'Create Account' }
      ]
    };
    res.json({ success: true, data: screenConfig });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get app configuration by adminObjectId (for splash screen and dynamic data)
app.get('/api/app-config/:adminObjectId', async (req, res) => {
  try {
    const { adminObjectId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(adminObjectId)) {
      return res.status(400).json({ success: false, error: 'Invalid adminObjectId' });
    }
    const appConfig = await AdminElementScreen.findById(adminObjectId);
    if (!appConfig) {
      return res.status(404).json({ success: false, error: 'App configuration not found' });
    }
    const userCount = await UsersCreateAccount.countDocuments({ adminObjectId: new mongoose.Types.ObjectId(adminObjectId) });
    res.json({
      success: true,
      data: {
        appName: appConfig.appName || appConfig.shopName || 'My App',
        shopName: appConfig.shopName,
        category: appConfig.category,
        pages: appConfig.pages,
        dynamicFields: appConfig.dynamicFields,
        userCount: userCount,
        lastUpdated: appConfig.updatedAt
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get all products (from dynamicFields.productCards)
app.get('/api/products/:adminObjectId', async (req, res) => {
  try {
    const { adminObjectId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(adminObjectId)) {
      return res.status(400).json({ success: false, error: 'Invalid adminObjectId' });
    }
    const appConfig = await AdminElementScreen.findById(adminObjectId);
    if (!appConfig) {
      return res.status(404).json({ success: false, error: 'App configuration not found' });
    }
    const products = appConfig.dynamicFields?.productCards || [];
    res.json({ success: true, data: products });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Search products
app.get('/api/products/search/:adminObjectId/:query', async (req, res) => {
  try {
    const { adminObjectId, query } = req.params;
    if (!mongoose.Types.ObjectId.isValid(adminObjectId)) {
      return res.status(400).json({ success: false, error: 'Invalid adminObjectId' });
    }
    const appConfig = await AdminElementScreen.findById(adminObjectId);
    if (!appConfig) {
      return res.status(404).json({ success: false, error: 'App configuration not found' });
    }
    const products = appConfig.dynamicFields?.productCards || [];
    const filteredProducts = products.filter(p => 
      (p.productName && p.productName.toLowerCase().includes(query.toLowerCase())) ||
      (p.description && p.description.toLowerCase().includes(query.toLowerCase()))
    );
    res.json({ success: true, data: filteredProducts });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Create user - Dynamic endpoint for form submission
app.post('/api/create-user', async (req, res) => {
  try {
    const { adminObjectId, fullName, firstName, lastName, email, password, phone, countryCode } = req.body;
    if (!adminObjectId || !email || !password) {
      return res.status(400).json({ success: false, error: 'adminObjectId, email, and password are required' });
    }
    if (!mongoose.Types.ObjectId.isValid(adminObjectId)) {
      return res.status(400).json({ success: false, error: 'Invalid adminObjectId' });
    }
    const existingUser = await UsersCreateAccount.findOne({ 
      adminObjectId: new mongoose.Types.ObjectId(adminObjectId), 
      email: email.toLowerCase() 
    });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'User already exists with this email' });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new UsersCreateAccount({
      adminObjectId: new mongoose.Types.ObjectId(adminObjectId),
      firstName: firstName || fullName?.split(' ')[0] || '',
      lastName: lastName || fullName?.split(' ').slice(1).join(' ') || '',
      fullName: fullName || `${firstName} ${lastName}`,
      email: email.toLowerCase(),
      password: hashedPassword,
      phone: phone || '',
      countryCode: countryCode || '+91'
    });
    await user.save();
    const token = jwt.sign({ userId: user._id, email: user.email, adminObjectId }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ 
      success: true, 
      message: 'User created successfully',
      data: { userId: user._id, fullName: user.fullName, firstName: user.firstName, lastName: user.lastName, email: user.email, phone: user.phone, token }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// User registration (Create Account)
app.post('/api/users/register', async (req, res) => {
  try {
    const { adminObjectId, firstName, lastName, email, password, phone, countryCode } = req.body;
    if (!adminObjectId || !firstName || !lastName || !email || !password || !phone) {
      return res.status(400).json({ success: false, error: 'All fields are required' });
    }
    if (!mongoose.Types.ObjectId.isValid(adminObjectId)) {
      return res.status(400).json({ success: false, error: 'Invalid adminObjectId' });
    }
    const existingUser = await UsersCreateAccount.findOne({ 
      adminObjectId: new mongoose.Types.ObjectId(adminObjectId), 
      email: email.toLowerCase() 
    });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'User already exists with this email' });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new UsersCreateAccount({
      adminObjectId: new mongoose.Types.ObjectId(adminObjectId),
      firstName, lastName,
      fullName: `${firstName} ${lastName}`,
      email: email.toLowerCase(),
      password: hashedPassword,
      phone,
      countryCode: countryCode || '+91'
    });
    await user.save();
    const token = jwt.sign({ userId: user._id, email: user.email, adminObjectId }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ 
      success: true, 
      message: 'Account created successfully',
      data: { userId: user._id, firstName: user.firstName, lastName: user.lastName, email: user.email, phone: user.phone, token }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// User login (Sign In)
app.post('/api/users/login', async (req, res) => {
  try {
    const { adminObjectId, email, password } = req.body;
    if (!adminObjectId || !email || !password) {
      return res.status(400).json({ success: false, error: 'All fields are required' });
    }
    if (!mongoose.Types.ObjectId.isValid(adminObjectId)) {
      return res.status(400).json({ success: false, error: 'Invalid adminObjectId' });
    }
    const user = await UsersCreateAccount.findOne({ 
      adminObjectId: new mongoose.Types.ObjectId(adminObjectId), 
      email: email.toLowerCase() 
    });
    if (!user) {
      return res.status(401).json({ success: false, error: 'Invalid email or password' });
    }
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ success: false, error: 'Invalid email or password' });
    }
    const token = jwt.sign({ userId: user._id, email: user.email, adminObjectId }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ 
      success: true, 
      message: 'Login successful',
      data: { userId: user._id, firstName: user.firstName, lastName: user.lastName, email: user.email, phone: user.phone, token }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Check if user exists
app.post('/api/users/check', async (req, res) => {
  try {
    const { adminObjectId, email } = req.body;
    if (!adminObjectId || !email) {
      return res.status(400).json({ success: false, error: 'adminObjectId and email are required' });
    }
    if (!mongoose.Types.ObjectId.isValid(adminObjectId)) {
      return res.status(400).json({ success: false, error: 'Invalid adminObjectId' });
    }
    const user = await UsersCreateAccount.findOne({ 
      adminObjectId: new mongoose.Types.ObjectId(adminObjectId), 
      email: email.toLowerCase() 
    });
    res.json({ success: true, exists: !!user });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get user profile (protected route)
app.get('/api/users/profile', authenticateToken, async (req, res) => {
  try {
    const user = await UsersCreateAccount.findById(req.user.userId).select('-password');
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, data: user });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Add to cart (protected route)
app.post('/api/users/cart', authenticateToken, async (req, res) => {
  try {
    const { productId, productName, price, quantity } = req.body;
    const user = await UsersCreateAccount.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    const existingItem = user.cart.find(item => item.productId === productId);
    if (existingItem) {
      existingItem.quantity += quantity || 1;
    } else {
      user.cart.push({ productId, productName, price, quantity: quantity || 1 });
    }
    user.updatedAt = new Date();
    await user.save();
    res.json({ success: true, data: user.cart });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get cart (protected route)
app.get('/api/users/cart', authenticateToken, async (req, res) => {
  try {
    const user = await UsersCreateAccount.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, data: user.cart });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Add to wishlist (protected route)
app.post('/api/users/wishlist', authenticateToken, async (req, res) => {
  try {
    const { productId, productName, productPrice } = req.body;
    const user = await UsersCreateAccount.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    const existingItem = user.wishlist.find(item => item.productId === productId);
    if (!existingItem) {
      user.wishlist.push({ productId, productName, productPrice });
      user.updatedAt = new Date();
      await user.save();
    }
    res.json({ success: true, data: user.wishlist });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get wishlist (protected route)
app.get('/api/users/wishlist', authenticateToken, async (req, res) => {
  try {
    const user = await UsersCreateAccount.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, data: user.wishlist });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Place order (protected route)
app.post('/api/users/orders', authenticateToken, async (req, res) => {
  try {
    const user = await UsersCreateAccount.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    if (!user.cart || user.cart.length === 0) {
      return res.status(400).json({ success: false, error: 'Cart is empty' });
    }
    const orderId = 'ORDER_' + Date.now();
    const total = user.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    const purchaseItems = user.cart.map(item => ({
      productId: item.productId,
      productName: item.productName,
      price: item.price,
      quantity: item.quantity,
      purchaseDate: new Date()
    }));
    user.purchaseHistory.push(...purchaseItems);
    user.cart = [];
    user.updatedAt = new Date();
    await user.save();
    res.json({ 
      success: true, 
      message: 'Order placed successfully',
      data: { orderId, items: purchaseItems, total } 
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get user purchase history (protected route)
app.get('/api/users/orders', authenticateToken, async (req, res) => {
  try {
    const user = await UsersCreateAccount.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, data: user.purchaseHistory });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Real-time configuration endpoint for mobile app updates
app.get('/api/app-config', async (req, res) => {
  try {
    // This would connect to your main database to get latest configuration
    const config = {
      adminId: '690dc087abc99370793b9150',
      shopName: 'Bunny Shop',
      lastUpdated: new Date().toISOString(),
      // Add dynamic configuration based on your app structure
      features: {
        searchEnabled: true,
        cartEnabled: true,
        userRegistrationEnabled: true,
        orderTrackingEnabled: true
      }
    };
    res.json({ success: true, data: config });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Bunny Shop Backend Server running on port ${PORT}`);
});

module.exports = app;
