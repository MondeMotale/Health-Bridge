Health-Bridge 🏥📱

A unified, real-time ecosystem connecting Community Health Workers (CHWs), Clinic Administrators, and Patients.

📌 Problem Statement

A critical disconnect exists between centralized clinical administration and on-the-ground community healthcare. Fragmented communication channels between Community Health Workers (CHWs) and clinics lead to delayed patient follow-ups, inefficient record-keeping, and security vulnerabilities when handling sensitive patient data in the field.

💡 Solution Overview

Health-Bridge bridges this gap by providing a multi-platform, real-time digital ecosystem:

Mobile Application (Flutter): Empowers CHWs to conduct field visits, manage schedules, capture patient records, and initiate secure telehealth calls. Enables Patients to view treatment plans and participate in remote care consultations.

Web Dashboard (Next.js / TypeScript): Gives Clinic Administrators a high-performance portal to manage staff, track facility metrics, handle appointments, and generate digital referrals.

Secure Telehealth & Signaling Engine: Real-time voice and video integration using the Agora RTC Engine, backed by a custom Node.js token provider for strict security.

🏗️ System Architecture & Tech Stack

Frontend & Mobile

Mobile App: Flutter (Dart)

State Management: Provider

Device Integrations: geolocator (field tracking), image_picker (patient avatars)

Real-Time Calls: Custom floating audio banners & full-screen video overlay widgets

Web Admin Portal: React, Next.js, TypeScript, Tailwind CSS

Backend, Database & Security

Backend BaaS: Firebase (Authentication, Cloud Firestore, Cloud Storage)

Real-Time Token Server: Custom Node.js microservice provisioning time-limited, encrypted Agora RTC tokens

Security & Access Control: Role-Based Access Control (RBAC) and granular Firestore Security Rules for multi-tenant data isolation

🔐 Key Technical Challenges & Engineering Highlights

1. Multi-Tenant Data Isolation & Security Rules

Challenge: Ensuring clinic administrators can only view data associated with their specific facility, while strictly isolating sensitive patient records across clinics.

Engineering Solution: Authored custom Firebase Security Rules enforcing strict tenancy constraints and validating user tokens against assigned roles before granting read/write operations.

2. Secure Real-Time Telehealth Signaling

Challenge: Preventing channel eavesdropping or unauthorized participation in patient-CHW telehealth calls.

Engineering Solution: Built a dedicated Node.js signaling service that dynamic generates short-lived, encrypted Agora RTC tokens. Access tokens are bound to specific channel IDs and validated against authenticated user session tokens.

3. Native-Quality Audio/Video UX in Flutter

Challenge: Maintaining background audio accessibility and seamless UI state switching during telehealth sessions on mobile devices.

Engineering Solution: Designed custom, state-aware Flutter overlay widgets—including a floating banner for active audio calls and responsive overlays for full-screen video transitions.

🚀 Key Features

For Community Health Workers (CHWs)

📋 Manage daily patient visit schedules and field logs.

📍 Track visit locations using device GPS.

📞 Initiate real-time voice and video consultations with patients or clinic leads.

📷 Capture and upload patient profiles securely.

For Clinic Administrators

📊 Real-time facility metrics and workforce dashboard.

🧑‍⚕️ Staff and CHW account provisioning.

📄 Digital referral creation and patient history auditing.

For Patients

📅 View upcoming appointments and care plans.

🔐 Securely receive telehealth consultations directly from assigned healthcare providers.

🛠️ Local Development Setup

Prerequisites

Flutter SDK (v3.0+)

Node.js (v18+)

Firebase CLI (npm install -g firebase-tools)

1. Clone the Repository

git clone https://github.com/MondeMotale/Health-Bridge.git
cd Health-Bridge


2. Mobile Setup (Flutter)

cd mobile
flutter pub get
flutter run


3. Web Admin Setup (Next.js)

cd web
npm install
npm run dev


4. Token Server Setup (Node.js)

cd server
npm install
npm start


👤 Author

Monde Motale

Final-Year ICT Student | Software Developer

GitHub: @MondeMotale

LinkedIn: Monde Motale

Developed as part of a final-year ICT portfolio showcase.