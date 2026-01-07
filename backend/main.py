import os
import json
import sqlite3
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import google.generativeai as genai
from sqlmodel import SQLModel, Field, create_engine, Session, select
from collections import Counter # ✅ Added for Cuisine Counting

# --- CONFIGURATION ---
GENAI_API_KEY = "AIzaSyDDNwfkYt0QCiT85I91zvBylSknAVHzYJw"
genai.configure(api_key=GENAI_API_KEY)

app = FastAPI()

# --- DATABASE SETUP ---
sqlite_file_name = "catering.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"
engine = create_engine(sqlite_url)

# --- MODELS ---
class SavedMenu(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    user_id: int
    event_type: str
    cuisine: str
    guest_count: int
    budget: int
    menu_json: str

class SavedPricing(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    menu_id: int
    user_id: int
    base_cost: float
    labor_cost: float
    transport_cost: float
    profit_margin_percent: float
    final_quote_amount: float

class SavedInvoice(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    user_id: int
    menu_id: int
    client_name: str
    final_amount: float
    tax_percent: float
    discount_amount: float
    grand_total: float
    is_paid: bool = False
    event_date: str = Field(default="2025-01-01")
    order_status: str = Field(default="Pending")

class SavedPayment(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    invoice_id: int
    amount: float
    payment_date: str
    payment_mode: str

class CompanyProfile(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(unique=True)
    company_name: str
    address: str
    phone: str
    email: str | None = None
    gst_number: str | None = None
    logo_base64: str | None = None

class UserLogin(BaseModel):
    username: str
    password: str

# --- DB INIT ---
def init_db():
    SQLModel.metadata.create_all(engine)
    conn = sqlite3.connect("catering.db")
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        username TEXT UNIQUE, 
        password TEXT
    )''')
    conn.commit()
    conn.close()

@app.on_event("startup")
def on_startup():
    init_db()

# --- INPUT MODELS ---
class MenuRequest(BaseModel):
    event_type: str
    cuisine: str
    guest_count: int
    budget_per_plate: int
    dietary_preference: str
    special_requirements: str = "None"

class RegenerateRequest(BaseModel):
    section: str
    event_type: str
    cuisine: str
    dietary: str
    current_items: list[str] = []

# --- MENU GENERATION ---
@app.post("/generate-menu")
async def generate_menu(request: MenuRequest):
    prompt = f"""
    Act as a professional catering chef.
    
    🛑 STRICT CONSTRAINTS (READ FIRST):
    1. **PRICING:** Every item MUST include an estimated cost in this exact format: "Item Name - ₹Cost" (e.g., "Dal Makhani - ₹40").
    2. **BUDGET:** The TOTAL sum of all item costs MUST NOT EXCEED ₹{request.budget_per_plate}.
       - If your selected items are too expensive, replace them with cheaper options to fit the budget.
       - Do NOT output a menu that exceeds the budget.

    Generate a {request.dietary_preference} menu for a {request.event_type}.
    Cuisine: {request.cuisine}
    Guest Count: {request.guest_count}
    Special Requirements: {request.special_requirements}

    DIETARY RULES: 
    - If 'Veg', NO meat/egg/fish.
    - If 'Jain', NO onion/garlic/roots.
    - Provide 3-5 items per category based on the budget.

    Output strictly in valid JSON format with keys: starters, main_course, breads, rice, desserts, beverages.
    Do not add markdown formatting.
    """
    try:
        model = genai.GenerativeModel('gemini-flash-latest')
        response = model.generate_content(prompt)
        raw_text = response.text.replace("```json", "").replace("```", "").strip()
        return {"menu_data": raw_text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- REGENERATE SECTION ---
@app.post("/regenerate-section")
async def regenerate_section(req: RegenerateRequest):
    prompt = f"""
    Act as a professional catering chef.
    
    🛑 STRICT INSTRUCTION:
    - Provide 5 NEW options for the "{req.section}" section.
    - **EVERY ITEM MUST HAVE A PRICE.**
    - Format: "Item Name - ₹Cost"
    - Example: "Hara Bhara Kabab - ₹30"

    Context:
    - Event: {req.event_type}
    - Cuisine: {req.cuisine}
    - Dietary: {req.dietary}
    - DO NOT include: {", ".join(req.current_items)}

    Output strictly a valid JSON List of strings.
    Do not add markdown formatting.
    """
    
    try:
        model = genai.GenerativeModel('gemini-flash-latest')
        response = model.generate_content(prompt)
        raw_text = response.text.replace("```json", "").replace("```", "").strip()
        return {"new_items": json.loads(raw_text)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- CRUD OPERATIONS ---
@app.post("/save-menu")
def save_menu(menu: SavedMenu):
    with Session(engine) as session:
        session.add(menu)
        session.commit()
        session.refresh(menu)
        return {"status": "success", "id": menu.id}

@app.get("/get-menus")
def get_menus(user_id: int = Query(...)):
    with Session(engine) as session:
        return session.exec(select(SavedMenu).where(SavedMenu.user_id == user_id)).all()

@app.delete("/delete-menu/{menu_id}")
def delete_menu(menu_id: int):
    with Session(engine) as session:
        menu = session.get(SavedMenu, menu_id)
        if not menu:
            raise HTTPException(status_code=404, detail="Menu not found")
        session.delete(menu)
        session.commit()
        return {"status": "deleted"}

# ✅ UPDATED DASHBOARD STATS LOGIC
@app.get("/dashboard-stats")
def get_dashboard_stats(user_id: int = Query(...)):
    with Session(engine) as session:
        menus = session.exec(select(SavedMenu).where(SavedMenu.user_id == user_id)).all()
        
        # 1. Basic Counts
        total_events = len(menus)
        total_guests = sum(m.guest_count for m in menus)
        
        # 2. Revenue Logic (Budget * Guests)
        total_revenue = sum(m.budget * m.guest_count for m in menus)
        
        # Formatting Revenue (0.5 L for less than 1L)
        if total_revenue == 0:
            revenue_str = "₹0"
        elif total_revenue < 100000:
            # Convert to Lakhs (e.g., 50000 -> 0.50 L)
            val = total_revenue / 100000
            revenue_str = f"₹{val:.2f} L"
        elif total_revenue < 10000000:
            # Convert to Lakhs (e.g., 150000 -> 1.5 L)
            val = total_revenue / 100000
            revenue_str = f"₹{val:.1f} L"
        else:
            # Convert to Crores
            val = total_revenue / 10000000
            revenue_str = f"₹{val:.2f} Cr"

        # 3. Top Cuisine Logic
        cuisines = [m.cuisine for m in menus]
        if not cuisines:
            top_cuisine = "Multi-Cuisine"
        else:
            # Count occurrences
            counts = Counter(cuisines)
            most_common = counts.most_common()
            
            # Check for Tie
            if len(most_common) > 1 and most_common[0][1] == most_common[1][1]:
                top_cuisine = "Multi-Cuisine"
            else:
                top_cuisine = most_common[0][0]

        return {
            "total_events": total_events,
            "total_guests": total_guests,
            "projected_revenue": revenue_str, 
            "top_cuisine": top_cuisine
        }

@app.post("/save-pricing")
def save_pricing(pricing: SavedPricing):
    with Session(engine) as session:
        session.add(pricing)
        session.commit()
        return {"status": "success", "id": pricing.id}

@app.post("/save-invoice")
def save_invoice(invoice: SavedInvoice):
    with Session(engine) as session:
        session.add(invoice)
        session.commit()
        session.refresh(invoice)
        return {"status": "created", "id": invoice.id}

@app.get("/get-invoices")
def get_invoices(user_id: int = Query(...)):
    with Session(engine) as session:
        return session.exec(select(SavedInvoice).where(SavedInvoice.user_id == user_id)).all()

@app.post("/add-payment")
def add_payment(payment: SavedPayment):
    with Session(engine) as session:
        session.add(payment)
        session.commit()
        invoice = session.get(SavedInvoice, payment.invoice_id)
        payments = session.exec(select(SavedPayment).where(SavedPayment.invoice_id == payment.invoice_id)).all()
        total_paid = sum(p.amount for p in payments)
        invoice.is_paid = total_paid >= invoice.grand_total
        session.add(invoice)
        session.commit()
        return {"status": "success"}

@app.get("/get-payments/{invoice_id}")
def get_payments(invoice_id: int):
    with Session(engine) as session:
        return session.exec(select(SavedPayment).where(SavedPayment.invoice_id == invoice_id)).all()

@app.post("/update-order-status")
def update_order_status(invoice_id: int, status: str):
    with Session(engine) as session:
        invoice = session.get(SavedInvoice, invoice_id)
        if not invoice:
            raise HTTPException(status_code=404, detail="Order not found")
        invoice.order_status = status
        session.commit()
        return {"status": "updated"}

@app.post("/save-profile")
def save_profile(profile: CompanyProfile):
    with Session(engine) as session:
        existing_profile = session.exec(select(CompanyProfile).where(CompanyProfile.user_id == profile.user_id)).first()
        if existing_profile:
            existing_profile.company_name = profile.company_name
            existing_profile.address = profile.address
            existing_profile.phone = profile.phone
            existing_profile.email = profile.email
            existing_profile.gst_number = profile.gst_number
            existing_profile.logo_base64 = profile.logo_base64
            session.add(existing_profile)
        else:
            session.add(profile)
        session.commit()
        return {"status": "success"}

@app.get("/get-profile")
def get_profile(user_id: int = Query(...)):
    with Session(engine) as session:
        profile = session.exec(select(CompanyProfile).where(CompanyProfile.user_id == user_id)).first()
        if not profile:
            return {} 
        return profile

# --- AUTH ---
@app.post("/register")
def register_user(user: UserLogin):
    conn = sqlite3.connect("catering.db")
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO users (username, password) VALUES (?, ?)", (user.username, user.password))
        conn.commit()
        return {"message": "User registered successfully"}
    except sqlite3.IntegrityError:
        raise HTTPException(status_code=400, detail="Username already exists")
    finally:
        conn.close()

@app.post("/login")
def login_user(user: UserLogin):
    conn = sqlite3.connect("catering.db")
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE username = ? AND password = ?", (user.username, user.password))
    data = cursor.fetchone()
    conn.close()
    
    if data:
        return {"message": "Login successful", "user_id": data[0], "username": data[1]}
    else:
        raise HTTPException(status_code=401, detail="Invalid credentials")