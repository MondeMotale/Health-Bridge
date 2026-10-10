import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

// Exported so createUser.ts can spin up a throwaway app instance
// when creating patient Auth accounts (without disturbing the admin session).
export const firebaseConfig = {
  apiKey: "AIzaSyCoPpVpq_7QNIdmQQOUMb7-e8OrJ84bAi4",
  authDomain: "health-bridge-7bcff.firebaseapp.com",
  projectId: "health-bridge-7bcff",
  storageBucket: "health-bridge-7bcff.firebasestorage.app",
  messagingSenderId: "450266006529",
  appId: "1:450266006529:web:9a97f6b781cb3c9aa26c00",
  measurementId: "G-GOJRK74CF6",
};

const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApp();
export const auth = getAuth(app);
export const db = getFirestore(app);