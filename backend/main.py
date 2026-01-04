import os
import json
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import google.generativeai as genai
from sqlmodel import SQLModel, Field, create_engine, Session, select

# --- CONFIGURATION ---
GENAI_API_KEY = "AIzaSyByeAkGvkrprPRXLE9Y4JUZWpjQ3Ac1kBQ"
genai.configure(api_key=GENAI_API_KEY)

app = FastAPI()

# --- DATABASE SETUP ---
sqlite_file_name = "catering.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"
engine = create_engine(sqlite_url)

# --- MODELS ---
class SavedMenu(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    event_type: str
    cuisine: str
    guest_count: int
    budget: int
    menu_json: str

class SavedPricing(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    menu_id: int
    base_cost: float
    labor_cost: float
    transport_cost: float
    profit_margin_percent: float
    final_quote_amount: float

class SavedInvoice(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
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

# --- STARTUP ---
@app.on_event("startup")
def on_startup():
    SQLModel.metadata.create_all(engine)

# --- INPUT MODELS ---
class MenuRequest(BaseModel):
    event_type: str
    cuisine: str
    guest_count: int
    budget_per_plate: int
    dietary_preference: str
    special_requirements: str = "None"

# --- API ENDPOINTS ---

@app.post("/generate-menu")
async def generate_menu(request: MenuRequest):
    # STRICT PROMPT: Asking for specific lowercase keys to fix the "Empty List" bug
    prompt = f"""
    You are a professional catering API. Generate a menu in strict JSON format.
    
    Details:
    - Event: {request.event_type}
    - Cuisine: {request.cuisine}
    - Budget: {request.budget_per_plate}
    - Diet: {request.dietary_preference}
    
    RULES:
    1. Output MUST be valid JSON.
    2. keys MUST be exactly: "starters", "main_course", "breads", "rice", "desserts", "beverages".
    3. Values must be simple lists of strings.
    4. Do not wrap in markdown code blocks.
    
    Example Structure:
    {{
        "starters": ["Item A", "Item B"],
        "main_course": ["Item C"],
        "breads": ["Item D"],
        "rice": ["Item E"],
        "desserts": ["Item F"],
        "beverages": ["Item G"]
    }}
    """
    try:
        # RESTORED: Using the model that was working for you
        model = genai.GenerativeModel('gemini-flash-latest') 
        response = model.generate_content(prompt)
        
        # --- CLEANING LOGIC ---
        # This removes ```json and ``` if the AI adds them, preventing errors
        raw_text = response.text
        if "```" in raw_text:
            raw_text = raw_text.replace("```json", "").replace("```", "").strip()
            
        return {"menu_data": raw_text}
        
    except Exception as e:
        print(f"Gemini API Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/save-menu")
def save_menu(menu: SavedMenu):
    try:
        with Session(engine) as session:
            session.add(menu)
            session.commit()
            session.refresh(menu)
            return {"status": "success", "id": menu.id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/get-menus")
def get_menus():
    try:
        with Session(engine) as session:
            return session.exec(select(SavedMenu)).all()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.delete("/delete-menu/{menu_id}")
def delete_menu(menu_id: int):
    try:
        with Session(engine) as session:
            menu = session.get(SavedMenu, menu_id)
            if not menu:
                raise HTTPException(status_code=404, detail="Menu not found")
            session.delete(menu)
            session.commit()
            return {"status": "deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/dashboard-stats")
def get_dashboard_stats():
    try:
        with Session(engine) as session:
            menus = session.exec(select(SavedMenu)).all()
            total_events = len(menus)
            total_guests = sum(m.guest_count for m in menus)
            total_budget = sum(m.budget * m.guest_count for m in menus) // 100000 if menus else 0 
            
            cuisine_counts = {}
            for m in menus:
                cuisine_counts[m.cuisine] = cuisine_counts.get(m.cuisine, 0) + 1
            top_cuisine = max(cuisine_counts, key=cuisine_counts.get) if cuisine_counts else "N/A"

            return {
                "total_events": total_events,
                "total_guests": total_guests,
                "projected_revenue": f"₹{total_budget} L", 
                "top_cuisine": top_cuisine
            }
    except Exception as e:
        return {"total_events": 0, "total_guests": 0, "projected_revenue": "₹0", "top_cuisine": "None"}

@app.post("/save-pricing")
def save_pricing(pricing: SavedPricing):
    try:
        with Session(engine) as session:
            session.add(pricing)
            session.commit()
            return {"status": "success", "id": pricing.id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/save-invoice")
def save_invoice(invoice: SavedInvoice):
    try:
        with Session(engine) as session:
            statement = select(SavedInvoice).where(SavedInvoice.menu_id == invoice.menu_id)
            existing_invoice = session.exec(statement).first()

            if existing_invoice:
                existing_invoice.client_name = invoice.client_name
                existing_invoice.final_amount = invoice.final_amount
                existing_invoice.tax_percent = invoice.tax_percent
                existing_invoice.discount_amount = invoice.discount_amount
                existing_invoice.grand_total = invoice.grand_total
                existing_invoice.event_date = invoice.event_date
                
                pay_statement = select(SavedPayment).where(SavedPayment.invoice_id == existing_invoice.id)
                payments = session.exec(pay_statement).all()
                total_paid = sum(p.amount for p in payments)

                if total_paid >= existing_invoice.grand_total:
                    existing_invoice.is_paid = True
                else:
                    existing_invoice.is_paid = False
                
                session.add(existing_invoice)
                session.commit()
                session.refresh(existing_invoice)
                return {"status": "updated", "id": existing_invoice.id}
            else:
                session.add(invoice)
                session.commit()
                session.refresh(invoice)
                return {"status": "created", "id": invoice.id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/get-invoices")
def get_invoices():
    with Session(engine) as session:
        return session.exec(select(SavedInvoice)).all()

@app.post("/add-payment")
def add_payment(payment: SavedPayment):
    try:
        with Session(engine) as session:
            session.add(payment)
            session.commit()
            
            invoice = session.get(SavedInvoice, payment.invoice_id)
            if not invoice:
                raise HTTPException(status_code=404, detail="Invoice not found")

            statement = select(SavedPayment).where(SavedPayment.invoice_id == payment.invoice_id)
            all_payments = session.exec(statement).all()
            total_paid = sum(p.amount for p in all_payments)
            
            if total_paid >= invoice.grand_total:
                invoice.is_paid = True
            else:
                invoice.is_paid = False
            
            session.add(invoice)
            session.commit()
            
            return {"status": "success", "new_balance": invoice.grand_total - total_paid}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/get-payments/{invoice_id}")
def get_payments(invoice_id: int):
    with Session(engine) as session:
        statement = select(SavedPayment).where(SavedPayment.invoice_id == invoice_id)
        return session.exec(statement).all()

@app.post("/update-order-status")
def update_order_status(invoice_id: int, status: str):
    with Session(engine) as session:
        invoice = session.get(SavedInvoice, invoice_id)
        if invoice:
            invoice.order_status = status
            session.add(invoice)
            session.commit()
            return {"status": "updated"}
        raise HTTPException(status_code=404, detail="Order not found")

@app.get("/")
def read_root():
    return {"status": "Catering Backend is Active"}