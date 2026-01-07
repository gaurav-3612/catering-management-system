from typing import Optional
from sqlmodel import Field, SQLModel, create_engine
from datetime import datetime

# Database Connection
sqlite_file_name = "catering.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"
engine = create_engine(sqlite_url)

# 1. Events Table [cite: 153]
class Event(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    event_type: str  # Wedding, Birthday, etc.
    client_name: str
    event_date: datetime
    guest_count: int
    budget: float
    status: str = "Pending"

# 2. Menus Table [cite: 154]
class Menu(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    event_id: int = Field(foreign_key="event.id")
    menu_json: str # We will store the AI response as a big string here [cite: 160]
    created_at: datetime = Field(default_factory=datetime.utcnow)

# Function to create tables
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

if __name__ == "__main__":
    create_db_and_tables()
    print("Database and Tables Created Successfully!")