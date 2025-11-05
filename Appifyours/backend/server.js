const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/bunny_shop_app', {
  useNewUrlParser: true,
  useUnifiedTopology: true
});

// Product Schema
const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  price: { type: Number, required: true },
  description: { type: String },
  image: { type: String },
  category: { type: String },
  inStock: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now }
});

const Product = mongoose.model('Product', productSchema);

// User Schema
const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phone: { type: String },
  address: {
    street: String,
    city: String,
    state: String,
    zipCode: String
  },
  orders: [{
    orderId: String,
    products: [{
      productId: String,
      name: String,
      price: Number,
      quantity: Number
    }],
    total: Number,
    status: { type: String, default: 'pending' },
    createdAt: { type: Date, default: Date.now }
  }],
  cart: [{
    productId: String,
    name: String,
    price: Number,
    quantity: Number,
    addedAt: { type: Date, default: Date.now }
  }],
  createdAt: { type: Date, default: Date.now }
});

const User = mongoose.model('User', userSchema);

// API Routes

// Get all products
app.get('/api/products', async (req, res) => {
  try {
    const products = await Product.find({ inStock: true });
    res.json({ success: true, data: products });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get product by ID
app.get('/api/products/:id', async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }
    res.json({ success: true, data: product });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Search products
app.get('/api/products/search/:query', async (req, res) => {
  try {
    const query = req.params.query;
    const products = await Product.find({
      $or: [
        { name: { $regex: query, $options: 'i' } },
        { description: { $regex: query, $options: 'i' } },
        { category: { $regex: query, $options: 'i' } }
      ],
      inStock: true
    });
    res.json({ success: true, data: products });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// User registration
app.post('/api/users/register', async (req, res) => {
  try {
    const { name, email, phone, address } = req.body;
    
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'User already exists' });
    }
    
    const user = new User({ name, email, phone, address });
    await user.save();
    
    res.json({ success: true, data: user });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get user profile
app.get('/api/users/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, data: user });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Add to cart
app.post('/api/users/:id/cart', async (req, res) => {
  try {
    const { productId, name, price, quantity } = req.body;
    const user = await User.findById(req.params.id);
    
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    
    const existingItem = user.cart.find(item => item.productId === productId);
    if (existingItem) {
      existingItem.quantity += quantity;
    } else {
      user.cart.push({ productId, name, price, quantity });
    }
    
    await user.save();
    res.json({ success: true, data: user.cart });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get cart
app.get('/api/users/:id/cart', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, data: user.cart });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Place order
app.post('/api/users/:id/orders', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    
    const orderId = 'ORDER_' + Date.now();
    const total = user.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    
    const order = {
      orderId,
      products: user.cart.map(item => ({
        productId: item.productId,
        name: item.name,
        price: item.price,
        quantity: item.quantity
      })),
      total,
      status: 'pending'
    };
    
    user.orders.push(order);
    user.cart = []; // Clear cart after order
    await user.save();
    
    res.json({ success: true, data: order });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get user orders
app.get('/api/users/:id/orders', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, data: user.orders });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Real-time configuration endpoint for mobile app updates
app.get('/api/app-config', async (req, res) => {
  try {
    // Connect to main Appifyours database to get latest configuration
    const mainDbUri = process.env.MAIN_DB_URI || 'mongodb://localhost:27017/appifyours';
    const mainDb = await mongoose.createConnection(mainDbUri, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });
    
    // Define schema for AdminElementScreen
    const adminElementScreenSchema = new mongoose.Schema({}, { strict: false });
    const AdminElementScreen = mainDb.model('AdminElementScreen', adminElementScreenSchema, 'adminElementScreens');
    
    // Fetch the admin configuration
    const adminConfig = await AdminElementScreen.findOne({ userId: '69021d2a2b0d7cd49d0bf5b4' });
    
    if (!adminConfig) {
      await mainDb.close();
      return res.status(404).json({
        success: false,
        error: 'Admin configuration not found'
      });
    }
    
    const config = {
      adminId: '69021d2a2b0d7cd49d0bf5b4',
      shopName: adminConfig.shopName || 'Bunny Shop',
      appName: adminConfig.appName || 'Bunny Shop',
      lastUpdated: adminConfig.updatedAt || new Date().toISOString(),
      features: {
        searchEnabled: true,
        cartEnabled: true,
        userRegistrationEnabled: true,
        orderTrackingEnabled: true,
        wishlistEnabled: true
      },
      theme: adminConfig.designSettings?.theme || {
        primaryColor: '#2196F3',
        secondaryColor: '#FF9800',
        backgroundColor: '#FFFFFF',
        textColor: '#000000'
      },
      storeInfo: adminConfig.dynamicFields?.storeInfo || {},
      gstNumber: adminConfig.dynamicFields?.gstNumber || '18'
    };
    
    await mainDb.close();
    res.json({ success: true, data: config });
  } catch (error) {
    console.error('Error fetching app config:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Dynamic products endpoint - fetches from main Appifyours database
app.get('/api/products/dynamic', async (req, res) => {
  try {
    // Connect to main Appifyours database
    const mainDbUri = process.env.MAIN_DB_URI || 'mongodb://localhost:27017/appifyours';
    const mainDb = await mongoose.createConnection(mainDbUri, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });
    
    // Define schema for AdminElementScreen
    const adminElementScreenSchema = new mongoose.Schema({}, { strict: false });
    const AdminElementScreen = mainDb.model('AdminElementScreen', adminElementScreenSchema, 'adminElementScreens');
    
    // Fetch the admin configuration
    const adminConfig = await AdminElementScreen.findOne({ userId: '69021d2a2b0d7cd49d0bf5b4' });
    
    if (!adminConfig) {
      await mainDb.close();
      return res.status(404).json({
        success: false,
        error: 'Admin configuration not found'
      });
    }
    
    // Extract products from dynamicFields
    const products = adminConfig.dynamicFields?.productCards || [];
    
    // Transform products to API format
    const transformedProducts = products.map((product, index) => ({
      _id: product.id || `product_${index}`,
      name: product.productName || product.name || 'Unknown Product',
      price: parseFloat(product.price || product.discountPrice || 0),
      description: product.description || '',
      image: product.image || '',
      category: product.category || 'General',
      inStock: true,
      productName: product.productName || product.name || 'Unknown Product',
      discountPrice: parseFloat(product.discountPrice || product.price || 0),
      ...product
    }));
    
    await mainDb.close();
    res.json({ success: true, data: transformedProducts });
  } catch (error) {
    console.error('Error fetching dynamic products:', error);
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
