importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAzXGrtRFJBVdvFuyTO-VdtecIldcvGing",
  authDomain: "nutri-leche-chat.firebaseapp.com",
  projectId: "nutri-leche-chat",
  storageBucket: "nutri-leche-chat.firebasestorage.app",
  messagingSenderId: "330528185869",
  appId: "1:330528185869:web:2d86a5324d564018923f44"
});

const messaging = firebase.messaging();
