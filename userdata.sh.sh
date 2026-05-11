#!/bin/bash
# Snap2Nutrition - Complete Auto Setup Script
# Run as EC2 User Data on a fresh Amazon Linux 2023 instance
# Requirements: t3.medium or larger, port 8000 open in security group

exec > /var/log/snap2nutrition-setup.log 2>&1
set -e

echo "Starting Snap2Nutrition setup..."

# Install dependencies
dnf update -y
dnf install python3-pip sqlite -y
pip3 install fastapi uvicorn python-multipart requests aiofiles

# Create app directory
mkdir -p /home/ec2-user/snap2nutrition/uploads

# Write index.html from compressed base64
python3 << PYBLOCK
import base64, gzip
data = "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"
html = gzip.decompress(base64.b64decode(data))
open("/home/ec2-user/snap2nutrition/index.html","wb").write(html)
print("index.html written!")
PYBLOCK

# Write app.py
cat > /home/ec2-user/snap2nutrition/app.py << 'APPEOF'
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from typing import List
import requests, base64, sqlite3, os, re
from datetime import datetime

app = FastAPI(title="Snap2Nutrition API")

# ---- Configuration ----
OLLAMA_URL = "http://172.31.25.147:11434/api/generate"  # Update to your AI server private IP
MODEL = "llava"
DB_PATH = os.path.join(os.path.dirname(__file__), "meals.db")
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Serve uploaded food photos
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# ---- Database ----
def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute('''CREATE TABLE IF NOT EXISTS meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT, filepath TEXT, dish TEXT,
        calories INTEGER, protein INTEGER, carbs INTEGER, fat INTEGER,
        health_score INTEGER, ai_response TEXT, meal_date TEXT, created_at TEXT
    )''')
    conn.commit()
    conn.close()

init_db()

# ---- AI Prompt ----
PROMPT = """You are a nutrition expert. Look at this food image and provide EXACT numbers only, no ranges.
Format your response exactly like this:
Dish: [dish name]
Calories: [single number] kcal
Protein: [single number]g
Carbs: [single number]g
Fat: [single number]g
Note: [one sentence health note]"""

# ---- Helper Functions ----
def call_ollama(image_bytes: bytes) -> dict:
    img_b64 = base64.b64encode(image_bytes).decode()
    try:
        r = requests.post(OLLAMA_URL, json={
            "model": MODEL,
            "prompt": PROMPT,
            "images": [img_b64],
            "stream": False
        }, timeout=180)
        r.raise_for_status()
        return {"success": True, "text": r.json().get("response", "")}
    except Exception as e:
        return {"success": False, "text": f"Error: {str(e)}"}

def parse_nutrition(text: str) -> dict:
    def num(pattern):
        m = re.search(pattern, text, re.IGNORECASE)
        return int(m.group(1)) if m else 0
    def dish(t):
        m = re.search(r'dish[:\s]+([^\n]+)', t, re.IGNORECASE)
        return m.group(1).strip() if m else "Food Item"
    return {
        "dish": dish(text),
        "calories": num(r'calories?[:\s]+(\d+)') or num(r'(\d+)\s*kcal'),
        "protein": num(r'protein[:\s]+(\d+)'),
        "carbs": num(r'carbs?[:\s]+(\d+)'),
        "fat": num(r'fat[:\s]+(\d+)')
    }

def health_score(cal: int, pro: int, carb: int, fat: int) -> int:
    s = 50
    if 0 < cal <= 500: s += 15
    elif cal <= 800: s += 5
    elif cal > 1000: s -= 15
    if pro >= 25: s += 20
    elif pro >= 15: s += 10
    elif pro < 5: s -= 10
    if carb <= 50: s += 10
    elif carb > 150: s -= 10
    if fat <= 15: s += 10
    elif fat > 40: s -= 10
    return max(0, min(100, s))

def save_meal(filename, filepath, parsed, score, ai_text, meal_date):
    conn = sqlite3.connect(DB_PATH)
    conn.execute('''INSERT INTO meals
        (filename,filepath,dish,calories,protein,carbs,fat,health_score,ai_response,meal_date,created_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
        (filename, filepath, parsed["dish"], parsed["calories"], parsed["protein"],
         parsed["carbs"], parsed["fat"], score, ai_text, meal_date, datetime.now().isoformat()))
    conn.commit()
    conn.close()

# ---- Routes ----
@app.get("/", response_class=HTMLResponse)
async def home():
    with open(os.path.join(os.path.dirname(__file__), "index.html")) as f:
        return f.read()

@app.post("/analyze-single")
async def analyze_single(files: List[UploadFile] = File(...)):
    results = []
    today = datetime.now().strftime("%Y-%m-%d")
    for file in files:
        data = await file.read()
        fname = f"{datetime.now().timestamp()}_{file.filename}"
        filepath = os.path.join(UPLOAD_DIR, fname)
        with open(filepath, "wb") as f:
            f.write(data)
        r = call_ollama(data)
        parsed = parse_nutrition(r["text"])
        score = health_score(parsed["calories"], parsed["protein"], parsed["carbs"], parsed["fat"])
        save_meal(file.filename, fname, parsed, score, r["text"], today)
        results.append({"filename": file.filename, "text": r["text"],
                        "success": r["success"], "parsed": parsed, "score": score})
    return JSONResponse({"results": results})

@app.post("/analyze-day")
async def analyze_day(files: List[UploadFile] = File(...), date: str = None):
    results = []
    meal_date = date or datetime.now().strftime("%Y-%m-%d")
    for file in files:
        data = await file.read()
        fname = f"{datetime.now().timestamp()}_{file.filename}"
        filepath = os.path.join(UPLOAD_DIR, fname)
        with open(filepath, "wb") as f:
            f.write(data)
        r = call_ollama(data)
        parsed = parse_nutrition(r["text"])
        score = health_score(parsed["calories"], parsed["protein"], parsed["carbs"], parsed["fat"])
        save_meal(file.filename, fname, parsed, score, r["text"], meal_date)
        results.append({"filename": file.filename, "text": r["text"],
                        "success": r["success"], "parsed": parsed, "score": score})
    return JSONResponse({"results": results})

@app.get("/history")
async def get_history(limit: int = 200):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    rows = conn.execute('SELECT * FROM meals ORDER BY created_at DESC LIMIT ?', (limit,)).fetchall()
    conn.close()
    meals = []
    for r in rows:
        m = dict(r)
        if m.get("filepath"):
            m["image_url"] = f"/uploads/{os.path.basename(m['filepath'])}"
        meals.append(m)
    return JSONResponse({"meals": meals})

@app.get("/stats")
async def get_stats():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    total = conn.execute('SELECT COUNT(*) as count FROM meals').fetchone()["count"]
    week = conn.execute('''SELECT SUM(calories) as cal, SUM(protein) as pro,
        SUM(carbs) as carb, SUM(fat) as fat, AVG(health_score) as score
        FROM meals WHERE meal_date >= date("now", "-7 days")''').fetchone()
    conn.close()
    return JSONResponse({"total_meals": total, "week": dict(week)})

APPEOF

# Set correct ownership
chown -R ec2-user:ec2-user /home/ec2-user/snap2nutrition

# Create systemd service for auto-start on boot
cat > /etc/systemd/system/snap2nutrition.service << 'SVCEOF'
[Unit]
Description=Snap2Nutrition Web App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/snap2nutrition
ExecStart=/usr/local/bin/uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# Enable and start
systemctl daemon-reload
systemctl enable snap2nutrition
systemctl start snap2nutrition

echo "Snap2Nutrition setup complete! App running on port 8000"
