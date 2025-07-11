const express = require('express');
const cors = require('cors');
const { initiateAirtelPayment } = require('./airtel/payment');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// Test Route
app.get('/', (req, res) => {
  res.send('🔗 Airtel backend running!');
});

// Airtel Payment Endpoint
app.post('/api/pay', async (req, res) => {
  const { phoneNumber, amount, reference } = req.body;

  try {
    const result = await initiateAirtelPayment({ phoneNumber, amount, reference });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Airtel backend listening on http://localhost:${PORT}`);
});
