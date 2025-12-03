const http = require('http');

const data = JSON.stringify({
  email: 'mohguanseng@gmail.com'
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/user/generate-referral',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('Testing referral code generation...');
console.log('Request:', { email: 'mohguanseng@gmail.com' });

const req = http.request(options, (res) => {
  let responseData = '';

  res.on('data', (chunk) => {
    responseData += chunk;
  });

  res.on('end', () => {
    console.log('\nResponse Status:', res.statusCode);
    console.log('Response:', JSON.parse(responseData));
  });
});

req.on('error', (error) => {
  console.error('Error:', error);
});

req.write(data);
req.end();
