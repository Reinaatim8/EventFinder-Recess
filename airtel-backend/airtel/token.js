const axios = require('axios');
require('dotenv').config();

let cachedToken = null;
let tokenExpiry = null;

async function getAccessToken() {
  const now = Date.now();

  // If token is still valid, return it
  if (cachedToken && tokenExpiry && now < tokenExpiry) {
    return cachedToken;
  }

  const url = `${process.env.AIRTM_BASE_URL}/auth/oauth2/token`;

  const credentials = {
    client_id: process.env.AIRTM_API_KEY,
    client_secret: process.env.AIRTM_API_SECRET,
    grant_type: 'client_credentials',
  };

  try {
    const response = await axios.post(url, credentials, {
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const { access_token, expires_in } = response.data;
    cachedToken = access_token;
    tokenExpiry = now + (expires_in - 60) * 1000; // buffer of 60 seconds

    return cachedToken;
  } catch (error) {
    console.error('❌ Failed to fetch access token:', error.response?.data || error.message);
    throw new Error('Token request failed');
  }
}

module.exports = { getAccessToken };

