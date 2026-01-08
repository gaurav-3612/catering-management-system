import os
import json
import sqlite3
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import google.generativeai as genai
from sqlmodel import SQLModel, Field, create_engine, Session, select
from collections import Counter 

# --- CONFIGURATION ---
GENAI_API_KEY = ""
genai.configure(api_key=GENAI_API_KEY)

app = FastAPI()

# --- DATABASE SETUP ---
sqlite_file_name = "catering.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"
engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})

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

@app.post("/generate-menu")
async def generate_menu(request: MenuRequest):
    prompt = f"""
    Act as a professional catering chef.
    
    ⭐⭐⭐ **PRIORITY INSTRUCTION (MUST FOLLOW):**
    The client has specific requirements: "{request.special_requirements}".
    - If they ask for a specific number of items (e.g. "5 dishes in starter"), you MUST provide exactly that number.
    - Fulfill this requirement EVEN IF it makes the budget tight (choose cheaper items to fit).
    
    🛑 **FINANCIAL CONSTRAINTS:**
    1. **TOTAL COST:** Try to keep total cost under ₹{request.budget_per_plate} per plate.
    2. **PRICING:** Every item MUST include an estimated cost per person: "Item Name - ₹Cost".
    3. **QUANTITY:** Suggest the TOTAL quantity/serving size needed for {request.guest_count} guests (e.g., "15 Kg", "100 Pcs").

    Generate a {request.dietary_preference} menu for a {request.event_type} ({request.cuisine}).
    
    Output strictly in valid JSON format with keys: starters, main_course, breads, rice, desserts, beverages.
    Format: "Item Name (Total Quantity for {request.guest_count} guests) - ₹CostPerPlate"
    """
    try:
        model = genai.GenerativeModel('gemini-flash-latest')
        response = model.generate_content(prompt)
        
        # Robust Cleaning
        raw_text = response.text.strip()
        if raw_text.startswith("```json"):
            raw_text = raw_text[7:]
        if raw_text.startswith("```"):
            raw_text = raw_text[3:]
        if raw_text.endswith("```"):
            raw_text = raw_text[:-3]
        raw_text = raw_text.strip()

        return {"menu_data": raw_text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- SCREEN 5: ORDER MANAGEMENT ---

# 1. Pending Orders (Joins Invoice + Menu to fix NULL values)
@app.get("/orders/pending")
def get_pending_orders(user_id: int = Query(...)):
    """Fetches Pending orders sorted by upcoming Event Date"""
    with Session(engine) as session:
        results = session.exec(
            select(SavedInvoice, SavedMenu)
            .where(SavedInvoice.menu_id == SavedMenu.id)
            .where(SavedInvoice.user_id == user_id)
            .where(SavedInvoice.order_status == "Pending")
            .order_by(SavedInvoice.event_date)
        ).all()
        
        final_list = []
        for invoice, menu in results:
            item = invoice.dict()
            item["event_type"] = menu.event_type 
            item["guest_count"] = menu.guest_count 
            final_list.append(item)
            
        return final_list

# 2. Update Status
@app.post("/orders/update-status")
def update_order_status(invoice_id: int, status: str):
    """Updates the status of a specific order"""
    with Session(engine) as session:
        invoice = session.get(SavedInvoice, invoice_id)
        if not invoice:
            raise HTTPException(status_code=404, detail="Order not found")
        invoice.order_status = status
        session.commit()
        return {"status": "updated", "new_status": status}

# 3. Get Single Order Details (For View Menu)
@app.get("/orders/get/{invoice_id}")
def get_order_details(invoice_id: int):
    """Fetches a single order with its full Menu details"""
    with Session(engine) as session:
        result = session.exec(
            select(SavedInvoice, SavedMenu)
            .where(SavedInvoice.menu_id == SavedMenu.id)
            .where(SavedInvoice.id == invoice_id)
        ).first()
        
        if not result:
            raise HTTPException(status_code=404, detail="Order not found")
            
        invoice, menu = result
        details = invoice.dict()
        details["menu_details"] = json.loads(menu.menu_json)
        details["event_type"] = menu.event_type
        details["guest_count"] = menu.guest_count
        
        return details

# --- SCREEN 4: PAYMENT TRACKING ---

# 1. Add Payment
@app.post("/payment/add")
def add_payment(payment: SavedPayment):
    """Adds a payment and auto-updates the Invoice status"""
    with Session(engine) as session:
        session.add(payment)
        session.commit()
        
        # Auto-sync logic: Recalculate Invoice Status
        invoice = session.get(SavedInvoice, payment.invoice_id)
        if invoice:
            all_payments = session.exec(
                select(SavedPayment).where(SavedPayment.invoice_id == invoice.id)
            ).all()
            total_paid = sum(p.amount for p in all_payments)
            invoice.is_paid = total_paid >= invoice.grand_total
            session.add(invoice)
            session.commit()
            
        return {"status": "success", "total_paid": total_paid}

# 2. Update Payment
@app.put("/payment/update")
def update_payment(payment_id: int, new_amount: float, new_mode: str):
    """Edits an existing payment record"""
    with Session(engine) as session:
        payment = session.get(SavedPayment, payment_id)
        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found")
        
        payment.amount = new_amount
        payment.payment_mode = new_mode
        session.add(payment)
        session.commit()
        
        invoice = session.get(SavedInvoice, payment.invoice_id)
        if invoice:
            all_payments = session.exec(select(SavedPayment).where(SavedPayment.invoice_id == invoice.id)).all()
            total_paid = sum(p.amount for p in all_payments)
            invoice.is_paid = total_paid >= invoice.grand_total
            session.add(invoice)
            session.commit()

        return {"status": "updated"}

# 3. Get Specific Status
@app.get("/payment/status/{invoice_id}")
def get_payment_status(invoice_id: int):
    """Returns exact status details for one invoice"""
    with Session(engine) as session:
        invoice = session.get(SavedInvoice, invoice_id)
        if not invoice:
            raise HTTPException(status_code=404, detail="Invoice not found")
            
        payments = session.exec(select(SavedPayment).where(SavedPayment.invoice_id == invoice_id)).all()
        total_paid = sum(p.amount for p in payments)
        
        if total_paid >= invoice.grand_total: status = "Paid"
        elif total_paid > 0: status = "Partial"
        else: status = "Pending"
            
        return {
            "invoice_id": invoice_id,
            "total": invoice.grand_total,
            "paid": total_paid,
            "balance": invoice.grand_total - total_paid,
            "status": status
        }

# 4. Smart Ledger
@app.get("/payment/ledger")
def get_payment_ledger(user_id: int = Query(...)):
    with Session(engine) as session:
        invoices = session.exec(select(SavedInvoice).where(SavedInvoice.user_id == user_id)).all()
        ledger_data = []
        for inv in invoices:
            payments = session.exec(select(SavedPayment).where(SavedPayment.invoice_id == inv.id)).all()
            total_paid = sum(p.amount for p in payments)
            
            if total_paid >= inv.grand_total: status = "Paid"
            elif total_paid > 0: status = "Partial"
            else: status = "Pending"
                
            ledger_data.append({
                "invoice_id": inv.id,
                "client_name": inv.client_name,
                "event_date": inv.event_date,
                "total_amount": inv.grand_total,
                "amount_paid": total_paid,
                "balance_due": inv.grand_total - total_paid,
                "status": status,
                "order_status": inv.order_status
            })
        return ledger_data

@app.get("/get-payments/{invoice_id}")
def get_payments(invoice_id: int):
    with Session(engine) as session:
        return session.exec(select(SavedPayment).where(SavedPayment.invoice_id == invoice_id)).all()

# --- REGENERATE SECTION (FIXED JSON PARSING) ---
@app.post("/regenerate-section")
async def regenerate_section(req: RegenerateRequest):
    prompt = f"""
    Act as a professional catering chef.
    Task: Provide 5 NEW options for the menu section: "{req.section}".
    
    STRICT OUTPUT RULES:
    1. Return ONLY a valid JSON list of strings.
    2. Format: "Item Name - ₹Cost".
    3. Do NOT use markdown code blocks (no ```json).
    4. Do NOT add introductory text.
    
    Context:
    - Event: {req.event_type}
    - Cuisine: {req.cuisine}
    - Dietary: {req.dietary}
    - Avoid these existing items: {", ".join(req.current_items)}
    """
    try:
        model = genai.GenerativeModel('gemini-flash-latest')
        response = model.generate_content(prompt)
        
        raw_text = response.text.strip()
        if raw_text.startswith("```json"):
            raw_text = raw_text[7:]
        if raw_text.startswith("```"):
            raw_text = raw_text[3:]
        if raw_text.endswith("```"):
            raw_text = raw_text[:-3]
        
        raw_text = raw_text.strip()
        
        return {"new_items": json.loads(raw_text)}
    except Exception as e:
        print(f"Regenerate Error: {e}") 
        return {"new_items": [f"Error regenerating {req.section}. Please try again."]}

@app.get("/dashboard-stats")
def get_dashboard_stats(user_id: int = Query(...)):
    with Session(engine) as session:
        menus = session.exec(select(SavedMenu).where(SavedMenu.user_id == user_id)).all()
        total_events = len(menus)
        total_guests = sum(m.guest_count for m in menus)
        total_revenue = sum(m.budget * m.guest_count for m in menus)
        
        if total_revenue == 0: revenue_str = "₹0"
        elif total_revenue < 10000000: revenue_str = f"₹{total_revenue / 100000:.1f} L"
        else: revenue_str = f"₹{total_revenue / 10000000:.2f} Cr"

        cuisines = [m.cuisine for m in menus]
        top_cuisine = Counter(cuisines).most_common(1)[0][0] if cuisines else "Multi-Cuisine"

        return {
            "total_events": total_events,
            "total_guests": total_guests,
            "projected_revenue": revenue_str, 
            "top_cuisine": top_cuisine
        }

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
        if not menu: raise HTTPException(status_code=404, detail="Menu not found")
        session.delete(menu)
        session.commit()
        return {"status": "deleted"}

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
        return profile if profile else {}

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