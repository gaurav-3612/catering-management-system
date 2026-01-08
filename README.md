🍽️ AI Catering Management System (Flutter + FastAPI)

A smart, full-stack mobile application designed to revolutionize the catering business. This app helps caterers automate menu planning using Generative AI, calculate precise costs, generate professional PDF invoices, and track payments—all from a single dashboard.

🚀 Key Features

1. 🤖 AI Menu Generator

Smart Menu Creation: Just enter the Event Type (Wedding, Birthday), Guest Count, and Budget. The AI generates a complete menu categorized into Starters, Mains, Breads, Desserts, etc.

Cost Estimation: The AI estimates the per-plate cost for every item (e.g., "Paneer Tikka - ₹40").

Special Requirements: Prioritizes custom requests like "5 starters" or "Jain food only".

Regenerate Sections: Don't like the desserts? Click refresh to get 5 new options instantly without changing the rest of the menu.

2. 💰 Dynamic Pricing Engine

Automated Costing: Calculates (Guest Count × AI Cost) automatically.

Profit Margin Slider: Adjust your profit margin (e.g., 20%, 30%) and see the final quote update in real-time.

Overhead Management: Add extra costs like Transport, Labor, and Fuel.

3. 🧾 Professional Invoicing

PDF Export: Generates a professional invoice PDF on the fly.

Company Branding: Automatically adds your Company Name, Address, and Logo to the header.

UPI Integration: Embeds a dynamic QR code on the invoice for instant payments.

4. 📒 Payment Ledger & Tracking

Financial Tracking: Tracks Total Amount, Paid Amount, and Balance Due for every event.

Color-Coded Status: Instantly see status: 🟢 Paid, 🟠 Partial, 🔴 Pending.

WhatsApp Reminders: Send a pre-written payment reminder to clients with one tap.

CSV Export: Download the entire ledger as a spreadsheet for accounting.

5. 📊 Operational Dashboard

Business Overview: Real-time stats on Total Revenue (in Lakhs/Crores), Total Events, and Top Performing Cuisine.

Pending Orders: Dedicated dashboard to track upcoming events and mark them as "Completed".

Offline Mode: Built-in SQLite caching allows you to view menus and invoices even without internet access.

🛠️ Tech Stack

Frontend (Mobile App)

Framework: Flutter (Dart)

Architecture: MVC (Model-View-Controller) pattern with API Service layer.

Key Packages:

http: For REST API communication.

sqflite: For offline local database.

pdf & printing: For generating invoices.

google_fonts: For professional typography.

url_launcher: For WhatsApp & Phone integration.

Backend (API Server)

Framework: FastAPI (Python)

AI Model: Google Gemini Flash (google-generativeai)

Database: SQLite (via SQLModel ORM)

Server: Uvicorn (ASGI)

⚙️ Installation Guide

1. Backend Setup

Navigate to the backend folder.

Install dependencies:

pip install fastapi uvicorn sqlmodel google-generativeai


Add your API Key in main.py:

GENAI_API_KEY = "YOUR_GEMINI_API_KEY"


Run the server:

uvicorn main:app --reload --host 0.0.0.0 --port 8000


2. Frontend Setup

Navigate to the project root.

Install Flutter packages:

flutter pub get


Update the Server URL in lib/api_service.dart:

static const String baseUrl = "http://YOUR_LOCAL_IP:8000";


Run the app:

flutter run


📱 Screen Workflow

Login/Register: Secure account creation (data isolated per user).

Dashboard: Quick stats and access to all tools.

Menu Generator: Generate, Edit, and Save menus.

Pricing: Adjust margins and finalize the quote.

Invoice: Generate PDF and share with client.

Ledger: Record payments and track due balances.

🔮 Future Enhancements

Cloud Deployment: Deploy backend to Render/Railway for global access.

Inventory Management: Auto-generate shopping lists based on menu items.

Client Login: Allow clients to view their own invoices and menus.

Developed with ❤️ using Flutter.
