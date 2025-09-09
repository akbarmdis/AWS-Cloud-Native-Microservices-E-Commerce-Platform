import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
const failureRate = new Rate('failed_requests');
const loginDuration = new Trend('login_duration', true);
const orderCreationDuration = new Trend('order_creation_duration', true);
const productSearchDuration = new Trend('product_search_duration', true);
const businessTransactions = new Counter('business_transactions');

// Test configuration
export const options = {
  stages: [
    // Ramp up
    { duration: '5m', target: 10 },   // Ramp up to 10 users over 5 minutes
    { duration: '10m', target: 50 },  // Increase to 50 users over 10 minutes
    { duration: '15m', target: 100 }, // Increase to 100 users over 15 minutes
    
    // Steady state
    { duration: '20m', target: 100 }, // Stay at 100 users for 20 minutes
    
    // Peak load
    { duration: '5m', target: 200 },  // Spike to 200 users over 5 minutes
    { duration: '10m', target: 200 }, // Stay at 200 users for 10 minutes
    
    // Scale down
    { duration: '5m', target: 50 },   // Scale down to 50 users
    { duration: '5m', target: 0 },    // Ramp down to 0 users
  ],
  
  thresholds: {
    // Overall performance requirements
    http_req_duration: ['p(95)<2000', 'p(99)<5000'], // 95% of requests under 2s, 99% under 5s
    http_req_failed: ['rate<0.05'], // Error rate should be less than 5%
    
    // Business transaction requirements
    login_duration: ['p(95)<1000'], // 95% of logins under 1s
    product_search_duration: ['p(95)<500'], // 95% of searches under 500ms
    order_creation_duration: ['p(95)<3000'], // 95% of orders under 3s
    
    // System stability
    checks: ['rate>0.95'], // 95% of checks should pass
    failed_requests: ['rate<0.05'], // Less than 5% failure rate
  },
};

// Base URL from environment variable or default
const BASE_URL = __ENV.BASE_URL || 'http://localhost';

// User data generator
function generateUserData() {
  const randomId = Math.floor(Math.random() * 10000);
  return {
    username: `testuser${randomId}`,
    email: `testuser${randomId}@example.com`,
    password: 'TestPassword123!',
    firstName: `Test${randomId}`,
    lastName: 'User',
  };
}

// Product data
const sampleProducts = [
  { name: 'Laptop', category: 'electronics', minPrice: 500, maxPrice: 2000 },
  { name: 'Book', category: 'books', minPrice: 10, maxPrice: 50 },
  { name: 'Shirt', category: 'clothing', minPrice: 20, maxPrice: 100 },
  { name: 'Phone', category: 'electronics', minPrice: 300, maxPrice: 1200 },
];

// Main test scenario
export default function() {
  const userData = generateUserData();
  let authToken = null;
  let userId = null;

  // Test group: User Authentication Flow
  group('User Authentication', function() {
    // 1. Register new user
    const registerPayload = JSON.stringify(userData);
    const registerParams = {
      headers: { 'Content-Type': 'application/json' },
    };

    const registerStart = new Date();
    const registerResponse = http.post(
      `${BASE_URL}/api/auth/register`,
      registerPayload,
      registerParams
    );
    
    const registerCheck = check(registerResponse, {
      'register status is 201': (r) => r.status === 201,
      'register response has token': (r) => r.json('token') !== '',
      'register response time OK': (r) => r.timings.duration < 2000,
    });
    
    failureRate.add(!registerCheck);
    
    if (registerResponse.status === 201) {
      const registerData = registerResponse.json();
      authToken = registerData.token;
      userId = registerData.user.id;
      businessTransactions.add(1, { transaction: 'user_registration' });
    }

    sleep(1);

    // 2. Login user
    const loginPayload = JSON.stringify({
      email: userData.email,
      password: userData.password,
    });

    const loginStart = new Date();
    const loginResponse = http.post(
      `${BASE_URL}/api/auth/login`,
      loginPayload,
      registerParams
    );
    const loginEnd = new Date();
    
    loginDuration.add(loginEnd - loginStart);
    
    const loginCheck = check(loginResponse, {
      'login status is 200': (r) => r.status === 200,
      'login response has token': (r) => r.json('token') !== '',
      'login response time OK': (r) => r.timings.duration < 1000,
    });
    
    failureRate.add(!loginCheck);
    
    if (loginResponse.status === 200) {
      authToken = loginResponse.json('token');
      businessTransactions.add(1, { transaction: 'user_login' });
    }

    sleep(1);
  });

  // Skip remaining tests if authentication failed
  if (!authToken) {
    console.log('Authentication failed, skipping remaining tests');
    return;
  }

  const authHeaders = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authToken}`,
    },
  };

  // Test group: Product Catalog Operations
  group('Product Catalog', function() {
    // 3. Search products
    const searchStart = new Date();
    const searchResponse = http.get(
      `${BASE_URL}/api/products/search?q=laptop&limit=20`,
      authHeaders
    );
    const searchEnd = new Date();
    
    productSearchDuration.add(searchEnd - searchStart);
    
    const searchCheck = check(searchResponse, {
      'search status is 200': (r) => r.status === 200,
      'search returns products': (r) => r.json('products').length > 0,
      'search response time OK': (r) => r.timings.duration < 500,
    });
    
    failureRate.add(!searchCheck);
    
    if (searchCheck) {
      businessTransactions.add(1, { transaction: 'product_search' });
    }

    sleep(1);

    // 4. Get product details
    const productId = Math.floor(Math.random() * 100) + 1; // Random product ID
    const productResponse = http.get(
      `${BASE_URL}/api/products/${productId}`,
      authHeaders
    );
    
    check(productResponse, {
      'product details status is 200 or 404': (r) => r.status === 200 || r.status === 404,
      'product details response time OK': (r) => r.timings.duration < 1000,
    });

    sleep(1);

    // 5. Get product categories
    const categoriesResponse = http.get(
      `${BASE_URL}/api/products/categories`,
      authHeaders
    );
    
    check(categoriesResponse, {
      'categories status is 200': (r) => r.status === 200,
      'categories response time OK': (r) => r.timings.duration < 500,
    });

    sleep(1);
  });

  // Test group: Order Management
  group('Order Management', function() {
    // 6. Get user cart
    const cartResponse = http.get(`${BASE_URL}/api/orders/cart`, authHeaders);
    
    check(cartResponse, {
      'cart status is 200': (r) => r.status === 200,
      'cart response time OK': (r) => r.timings.duration < 1000,
    });

    sleep(1);

    // 7. Add item to cart
    const randomProduct = sampleProducts[Math.floor(Math.random() * sampleProducts.length)];
    const cartItemPayload = JSON.stringify({
      productId: Math.floor(Math.random() * 100) + 1,
      quantity: Math.floor(Math.random() * 3) + 1,
      price: Math.floor(Math.random() * (randomProduct.maxPrice - randomProduct.minPrice)) + randomProduct.minPrice,
    });

    const addToCartResponse = http.post(
      `${BASE_URL}/api/orders/cart/items`,
      cartItemPayload,
      authHeaders
    );
    
    check(addToCartResponse, {
      'add to cart status is 200 or 201': (r) => r.status === 200 || r.status === 201,
      'add to cart response time OK': (r) => r.timings.duration < 1500,
    });

    sleep(1);

    // 8. Create order (simulate checkout)
    const orderPayload = JSON.stringify({
      shippingAddress: {
        street: '123 Test Street',
        city: 'Test City',
        state: 'TS',
        zipCode: '12345',
        country: 'US',
      },
      paymentMethod: {
        type: 'credit_card',
        cardNumber: '4111111111111111',
        expiryMonth: '12',
        expiryYear: '2025',
        cvv: '123',
      },
    });

    const orderStart = new Date();
    const orderResponse = http.post(
      `${BASE_URL}/api/orders`,
      orderPayload,
      authHeaders
    );
    const orderEnd = new Date();
    
    orderCreationDuration.add(orderEnd - orderStart);
    
    const orderCheck = check(orderResponse, {
      'order creation status is 201': (r) => r.status === 201,
      'order has order ID': (r) => r.json('orderId') !== '',
      'order response time OK': (r) => r.timings.duration < 3000,
    });
    
    failureRate.add(!orderCheck);
    
    if (orderCheck) {
      businessTransactions.add(1, { transaction: 'order_creation' });
    }

    sleep(2);

    // 9. Get order history
    const orderHistoryResponse = http.get(
      `${BASE_URL}/api/orders/history?limit=10`,
      authHeaders
    );
    
    check(orderHistoryResponse, {
      'order history status is 200': (r) => r.status === 200,
      'order history response time OK': (r) => r.timings.duration < 1000,
    });

    sleep(1);
  });

  // Test group: User Profile Operations
  group('User Profile', function() {
    // 10. Get user profile
    const profileResponse = http.get(`${BASE_URL}/api/users/profile`, authHeaders);
    
    check(profileResponse, {
      'profile status is 200': (r) => r.status === 200,
      'profile has user data': (r) => r.json('user.email') === userData.email,
      'profile response time OK': (r) => r.timings.duration < 1000,
    });

    sleep(1);

    // 11. Update user profile
    const updatePayload = JSON.stringify({
      firstName: userData.firstName + '_Updated',
      lastName: userData.lastName + '_Updated',
    });

    const updateResponse = http.put(
      `${BASE_URL}/api/users/profile`,
      updatePayload,
      authHeaders
    );
    
    check(updateResponse, {
      'profile update status is 200': (r) => r.status === 200,
      'profile update response time OK': (r) => r.timings.duration < 1500,
    });

    sleep(1);
  });

  // Test group: Health Checks (simulate monitoring)
  group('Health Checks', function() {
    // 12. Service health checks
    const services = ['user-service', 'product-service', 'order-service', 'payment-service'];
    
    services.forEach(service => {
      const healthResponse = http.get(`${BASE_URL}/api/${service}/health`);
      
      check(healthResponse, {
        [`${service} health check status is 200`]: (r) => r.status === 200,
        [`${service} health check response time OK`]: (r) => r.timings.duration < 500,
      });
    });

    sleep(1);
  });

  // Random think time to simulate real user behavior
  sleep(Math.random() * 5 + 1);
}

// Setup function runs once per VU at the beginning
export function setup() {
  console.log('Setting up load test...');
  console.log(`Base URL: ${BASE_URL}`);
  console.log(`Test duration: ~75 minutes`);
  console.log(`Max concurrent users: 200`);
  
  // Warm up the system
  const warmupResponse = http.get(`${BASE_URL}/health`);
  console.log(`Warmup response status: ${warmupResponse.status}`);
  
  return { baseUrl: BASE_URL };
}

// Teardown function runs once at the end
export function teardown(data) {
  console.log('Load test completed!');
  console.log('Check the results for performance metrics and SLA compliance.');
}

// Handle summary to provide custom output
export function handleSummary(data) {
  const failedRequestsRate = data.metrics.failed_requests?.values?.rate || 0;
  const p95ResponseTime = data.metrics.http_req_duration?.values?.['p(95)'] || 0;
  const checksPassRate = data.metrics.checks?.values?.rate || 0;

  const summary = {
    'Load Test Summary': {
      'Test Duration': `${Math.round(data.state.testRunDurationMs / 1000 / 60)} minutes`,
      'Total Requests': data.metrics.http_reqs?.values?.count || 0,
      'Failed Requests Rate': `${(failedRequestsRate * 100).toFixed(2)}%`,
      'Average Response Time': `${Math.round(data.metrics.http_req_duration?.values?.avg || 0)}ms`,
      'P95 Response Time': `${Math.round(p95ResponseTime)}ms`,
      'Checks Pass Rate': `${(checksPassRate * 100).toFixed(2)}%`,
      'Business Transactions': data.metrics.business_transactions?.values?.count || 0,
    }
  };

  console.log(JSON.stringify(summary, null, 2));

  return {
    'stdout': JSON.stringify(summary, null, 2),
    'summary.json': JSON.stringify(data, null, 2),
  };
}
