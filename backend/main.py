import os
import json
from fastapi import FastAPI, HTTPException
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

# --- MENU GENERATION (FIXED) ---
@app.post("/generate-menu")
async def generate_menu(request: MenuRequest):
    # FIX: We now actually pass the user's choices into the prompt!
    prompt = f"""
    Act as a professional catering chef.
    Generate a {request.dietary_preference} menu for a {request.event_type}.
    Cuisine: {request.cuisine}
    Guest Count: {request.guest_count}
    Budget per Plate: ₹{request.budget_per_plate}
    Special Requirements: {request.special_requirements}

    IMPORTANT: 
    - If Dietary Preference is 'Veg', DO NOT include any meat, egg, or fish items.
    - If 'Jain', DO NOT include onion, garlic, or root vegetables.
    - Provide 3-5 items per category based on the budget.

    Output strictly in valid JSON format with these exact keys:
    {{
      "starters": ["item1", "item2"],
      "main_course": ["item1", "item2"],
      "breads": ["item1", "item2"],
      "rice": ["item1", "item2"],
      "desserts": ["item1", "item2"],
      "beverages": ["item1", "item2"]
    }}
    Do not add any markdown formatting like ```json ... ```. Just the raw JSON string.
    """

    try:
        model = genai.GenerativeModel('gemini-flash-latest')
        response = model.generate_content(prompt)
        
        # Cleanup potential markdown if the AI adds it anyway
        raw_text = response.text.replace("```json", "").replace("```", "").strip()
        
        return {"menu_data": raw_text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- MENU CRUD ---
@app.post("/save-menu")
def save_menu(menu: SavedMenu):
    with Session(engine) as session:
        session.add(menu)
        session.commit()
        session.refresh(menu)
        return {"status": "success", "id": menu.id}

@app.get("/get-menus")
def get_menus():
    with Session(engine) as session:
        return session.exec(select(SavedMenu)).all()

@app.delete("/delete-menu/{menu_id}")
def delete_menu(menu_id: int):
    with Session(engine) as session:
        menu = session.get(SavedMenu, menu_id)
        if not menu:
            raise HTTPException(status_code=404, detail="Menu not found")
        session.delete(menu)
        session.commit()
        return {"status": "deleted"}

# --- DASHBOARD ---
@app.get("/dashboard-stats")
def get_dashboard_stats():
    with Session(engine) as session:
        menus = session.exec(select(SavedMenu)).all()
        return {
            "total_events": len(menus),
            "total_guests": sum(m.guest_count for m in menus),
            "projected_revenue": "₹0",
            "top_cuisine": "N/A"
        }

# --- PRICING ---
@app.post("/save-pricing")
def save_pricing(pricing: SavedPricing):
    with Session(engine) as session:
        session.add(pricing)
        session.commit()
        return {"status": "success", "id": pricing.id}

@app.post("/save-invoice")
def save_invoice(invoice: SavedInvoice):
    try:
        with Session(engine) as session:
            session.add(invoice)
            session.commit()
            session.refresh(invoice)
            return {"status": "created", "id": invoice.id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- INVOICE & PAYMENTS ---
@app.get("/get-invoices")
def get_invoices():
    with Session(engine) as session:
        return session.exec(select(SavedInvoice)).all()

@app.post("/add-payment")
def add_payment(payment: SavedPayment):
    with Session(engine) as session:
        session.add(payment)
        session.commit()

        invoice = session.get(SavedInvoice, payment.invoice_id)
        payments = session.exec(
            select(SavedPayment).where(SavedPayment.invoice_id == payment.invoice_id)
        ).all()

        total_paid = sum(p.amount for p in payments)
        invoice.is_paid = total_paid >= invoice.grand_total
        session.add(invoice)
        session.commit()

        return {"status": "success"}

@app.get("/get-payments/{invoice_id}")
def get_payments(invoice_id: int):
    with Session(engine) as session:
        return session.exec(
            select(SavedPayment).where(SavedPayment.invoice_id == invoice_id)
        ).all()

@app.post("/update-order-status")
def update_order_status(invoice_id: int, status: str):
    with Session(engine) as session:
        invoice = session.get(SavedInvoice, invoice_id)
        if not invoice:
            raise HTTPException(status_code=404, detail="Order not found")
        invoice.order_status = status
        session.commit()
        return {"status": "updated"}

@app.get("/")
def root():
    return {"status": "Catering Backend Active"}