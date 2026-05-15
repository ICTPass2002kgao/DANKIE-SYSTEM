// functions/firebase.js
const admin = require('firebase-admin');

// Initialize the app with a service account or from the environment
admin.initializeApp();

// Export the database instance
const db = admin.firestore();

module.exports = { db };