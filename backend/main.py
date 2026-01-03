import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import google.generativeai as genai
from sqlmodel import SQLModel

# --- CONFIGURATION ---
# Your API Key is set directly here
GENAI_API_KEY = "..."

# Configure Gemini DIRECTLY (No if-statements needed)
genai.configure(api_key=GENAI_API_KEY)

app = FastAPI()

# --- DATA MODELS ---
class MenuRequest(BaseModel):
    event_type: str       # e.g., Wedding
    cuisine: str          # e.g., South Indian
    guest_count: int      # e.g., 500
    budget_per_plate: int # e.g., 800
    dietary_preference: str # e.g., Veg
    special_requirements: str # e.g., "Need live dosa counter"

# --- AI LOGIC ---
@app.post("/generate-menu")
async def generate_menu(request: MenuRequest):
    # I removed the "if" check here. It will just run now.

    # [cite_start]1. Construct the Prompt based on the PDF Document [cite: 163-171]
    prompt = f"""
    Generate a complete catering menu.
    Event: {request.event_type}
    Cuisine: {request.cuisine}
    Guests: {request.guest_count}
    Budget: {request.budget_per_plate}
    Restrictions: {request.dietary_preference}
    Special Notes: {request.special_requirements}

    Required sections: Starters, Main Course, Breads, Rice, Desserts, Beverages.
    
    IMPORTANT: Return the result ONLY as a raw JSON object. Do not add markdown formatting.
    Structure:
    {{
        "starters": ["item1", "item2"],
        "main_course": ["item1", "item2"],
        "breads": ["item1"],
        "desserts": ["item1"]
    }}
    """

    try:
        # [cite_start]2. Call Gemini API [cite: 45]
        # Use 'gemini-pro' or 'gemini-1.5-flash'
        model = genai.GenerativeModel('gemini-flash-latest')
        response = model.generate_content(prompt)
        
        # [cite_start]3. Return the text [cite: 66]
        return {"menu_data": response.text}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def read_root():
    return {"status": "Catering Backend is Active"}