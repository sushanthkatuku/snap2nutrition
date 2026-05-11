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
