const axios = require('axios');
const { getAccessToken } = require('./token');
require('dotenv').config();

async function initiateAirtelPayment({ phoneNumber, amount, reference }) {
  const token = await getAccessToken();
  const url = `${process.env.AIRTM_BASE_URL}/merchant/v1/payments/`;

  const body = {
    reference,
    subscriber: {
      country: process.env.AIRTM_COUNTRY,
      currency: process.env.AIRTM_CURRENCY,
      msisdn: phoneNumber
    },
    transaction: {
      amount,
      country: process.env.AIRTM_COUNTRY,
      currency: process.env.AIRTM_CURRENCY,
      id: `TXN-${Date.now()}`
    }
  };

  try {
    const response = await axios.post(url, body, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });

    return response.data;
  } catch (error) {
    console.error('❌ Payment failed:', error.response?.data || error.message);
    throw new Error('Payment request failed');
  }
}

module.exports = { initiateAirtelPayment };
