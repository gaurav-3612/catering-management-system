import os
import json
import sqlite3
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import google.generativeai as genai
from sqlmodel import SQLModel, Field, create_engine, Session, select

# --- CONFIGURATION ---
GENAI_API_KEY = "AIzaSyBCQfDDOhDfgE8Jk-VAnpiW8TnjQya7dP0"
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

# ✅ NEW INPUT MODEL FOR REGENERATION
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
    Generate a {request.dietary_preference} menu for a {request.event_type}.
    Cuisine: {request.cuisine}
    Guest Count: {request.guest_count}
    Budget per Plate: ₹{request.budget_per_plate}
    Special Requirements: {request.special_requirements}

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

# ✅ NEW ENDPOINT: REGENERATE SECTION
@app.post("/regenerate-section")
async def regenerate_section(req: RegenerateRequest):
    prompt = f"""
    Act as a professional catering chef.
    I am planning a {req.dietary} {req.event_type} with {req.cuisine} cuisine.
    
    The user wants to REFRESH the "{req.section}" section of the menu.
    Provide 5 NEW and DIFFERENT options for "{req.section}".
    
    IMPORTANT:
    - Do NOT include these items (they were already suggested): {", ".join(req.current_items)}
    - Output strictly a valid JSON List of strings.
    
    Example Output:
    ["New Dish A", "New Dish B", "New Dish C", "New Dish D", "New Dish E"]
    Do not add markdown formatting.
    """
    
    try:
        model = genai.GenerativeModel('gemini-flash-latest')
        response = model.generate_content(prompt)
        
        # Clean up JSON
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

@app.get("/dashboard-stats")
def get_dashboard_stats(user_id: int = Query(...)):
    with Session(engine) as session:
        menus = session.exec(select(SavedMenu).where(SavedMenu.user_id == user_id)).all()
        return {
            "total_events": len(menus),
            "total_guests": sum(m.guest_count for m in menus),
            "projected_revenue": "₹0", 
            "top_cuisine": "Multi-Cuisine"
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