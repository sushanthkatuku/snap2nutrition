# 🥗 Snap2Nutrition

> AI-powered food photo analysis — upload a meal photo and instantly get dish identification, calories, protein, carbohydrates, fat, and a health score out of 100.

**Built at University of Nebraska Omaha | Research Project under Professor Chun-Hua Tsai**

**Live Demo:** http://34.224.159.186

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| Single Meal Analysis | Upload one or more food photos, get AI-powered dish identification and exact macronutrient breakdown |
| Health Score | Each meal receives a health score 0-100 with animated circular ring |
| Progress Bars | Protein, carbs, fat shown as % of recommended daily intake |
| Weekly Meal Tracker | Track meals Sun-Sat with real calendar that auto-updates |
| Week Navigation | Arrow buttons to go to past and future weeks |
| Analyze Full Week | One-click button to analyze all days at once |
| Multiple Images | Upload multiple photos per meal, each analyzed separately with combined totals |
| Meal History | All analyzed meals stored permanently with real food photo thumbnails |
| Filter by Period | Filter history by All Time, Today, This Week, This Month |
| Health Trends | Weekly nutrition overview with totals and average health score |
| Hamburger Navigation | Top-right menu for Analyze, History, and Trends pages |
| Persistent Storage | SQLite database — meals survive restarts and page refreshes |
| Food Photo Storage | Uploaded photos saved on server and served as thumbnails |
| Auto-start Service | Runs as systemd service — starts automatically on every boot |

---

## 🏗️ Architecture

```
User Browser
      │
      ▼  Port 80 / 8000
┌─────────────────────────┐
│  snap2nutrition-webapp   │
│  EC2 t3.medium (4GB)    │
│  FastAPI + SQLite       │
│  uploads/ (photos)      │
└──────────┬──────────────┘
           │ Private VPC 172.31.x.x:11434
           ▼
┌─────────────────────────┐
│  nutriponserver          │
│  EC2 r7.large (16GB)    │
│  Ollama + LLaVA model   │
└─────────────────────────┘
```

---

## 📋 Prerequisites

**AI Server (nutriponserver)**
- EC2 r7.large or equivalent — 16GB RAM minimum
- Amazon Linux 2023, 20GB storage
- Ports open: 22, 11434

**Web Server (snap2nutrition-webapp)**
- EC2 t3.medium or equivalent
- Amazon Linux 2023, 15GB storage
- Ports open: 22, 80, 8000

---

## 🚀 Installation

### Option A — Automated via EC2 User Data (Easiest)

When launching your EC2 instances, paste the script into the User Data field under Advanced Details.

**AI server:** paste contents of `setup_ollama.sh`

**Web server:** paste contents of `userdata.sh`

Both scripts fully automate installation and start services on boot.

---

### Option B — Manual Installation

#### Step 1 — AI Server Setup

```bash
sudo dnf update -y && sudo dnf install curl -y
curl -fsSL https://ollama.com/install.sh | sh

# Configure Ollama to accept external connections
sudo nano /etc/systemd/system/ollama.service
# Add under [Service]: Environment="OLLAMA_HOST=0.0.0.0"

sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl start ollama

ollama pull llava
ollama pull gemma3:4b
ollama list
```

Verify:
```bash
curl http://localhost:11434
# Ollama is running
```

#### Step 2 — Web Server Setup

```bash
sudo dnf update -y
sudo dnf install python3-pip sqlite -y
pip3 install fastapi uvicorn python-multipart requests aiofiles

mkdir -p ~/snap2nutrition/uploads
git clone https://github.com/YOUR_USERNAME/snap2nutrition.git
cp snap2nutrition/app.py ~/snap2nutrition/
cp snap2nutrition/index.html ~/snap2nutrition/
```

---

## ⚙️ Configuration

Edit `app.py` line 11 — set your AI server private IP:

```python
OLLAMA_URL = "http://YOUR_AI_SERVER_PRIVATE_IP:11434/api/generate"
```

Find your AI server private IP by running on it:
```bash
hostname -I
```

> Always use private IP when both servers are in the same AWS VPC. Public IP will fail.

---

## ▶️ Running

### Manual (testing)
```bash
cd ~/snap2nutrition
uvicorn app:app --host 0.0.0.0 --port 8000
```

### As a Service (production)
```bash
sudo nano /etc/systemd/system/snap2nutrition.service
```

```ini
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
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable snap2nutrition
sudo systemctl start snap2nutrition
sudo systemctl status snap2nutrition
```

### Remove port number from URL
```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000
```

---

## 📱 Usage Guide

**Single Meal**
1. Click upload area → select food photo(s)
2. Click Analyze All Meals
3. Wait 30-60 seconds
4. View dish name, macros, health score, progress bars

**Weekly Tracker**
1. Click Weekly Tracker tab
2. Select a day (Sun-Sat)
3. Upload meal photos for that day
4. Click Analyze [Day] or Analyze Full Week
5. Use arrows to navigate weeks

**Meal History**
1. Hamburger menu → Meal History
2. Browse past meals with photo thumbnails
3. Filter: All Time / Today / This Week / This Month

**Health Trends**
1. Hamburger menu → Health Trends
2. View weekly totals and average health score

---

## 🔌 API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Web application |
| `/analyze-single` | POST | Analyze meal images |
| `/analyze-day` | POST | Analyze meals for a specific day |
| `/history?limit=200` | GET | Meal history from database |
| `/stats` | GET | Weekly nutrition statistics |
| `/uploads/{filename}` | GET | Serve food photo thumbnails |

**Example:**
```bash
curl -X POST http://localhost:8000/analyze-single \
  -F "files=@food.jpg"
```

**Response:**
```json
{
  "results": [{
    "filename": "food.jpg",
    "text": "Dish: Chicken Biryani\nCalories: 520 kcal\nProtein: 28g\nCarbs: 65g\nFat: 14g",
    "success": true,
    "parsed": {"dish": "Chicken Biryani", "calories": 520, "protein": 28, "carbs": 65, "fat": 14},
    "score": 72
  }]
}
```

---

## 📁 Project Structure

```
snap2nutrition/
├── app.py              # FastAPI backend (endpoints, DB, Ollama)
├── index.html          # Complete frontend (all pages in one file)
├── requirements.txt    # Python dependencies
├── userdata.sh         # EC2 User Data script — webapp auto-setup
├── setup_ollama.sh     # EC2 User Data script — AI server auto-setup
├── .gitignore          # Excludes DB and uploads (personal data)
├── README.md           # This file
├── meals.db            # SQLite database (auto-created, gitignored)
└── uploads/            # Food photos (auto-created, gitignored)
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| AI Model | LLaVA vision-language model |
| Model Runner | Ollama |
| Backend | Python 3.9, FastAPI, Uvicorn |
| Database | SQLite |
| Frontend | HTML5, CSS3, Vanilla JavaScript |
| Fonts | Google Fonts — Outfit, Space Grotesk |
| Infrastructure | AWS EC2 x2, Elastic IP |
| OS | Amazon Linux 2023 |
| Process Manager | systemd |

---

## 🗄️ Database Schema

```sql
CREATE TABLE meals (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    filename     TEXT,       -- original uploaded filename
    filepath     TEXT,       -- saved photo path in uploads/
    dish         TEXT,       -- AI-identified dish name
    calories     INTEGER,    -- estimated calories (kcal)
    protein      INTEGER,    -- protein in grams
    carbs        INTEGER,    -- carbohydrates in grams
    fat          INTEGER,    -- fat in grams
    health_score INTEGER,    -- calculated score 0-100
    ai_response  TEXT,       -- full raw AI response text
    meal_date    TEXT,       -- date of meal YYYY-MM-DD
    created_at   TEXT        -- analysis timestamp
);
```

---

## 💡 Health Score Formula

```python
score = 50  # baseline

# Calories
if 0 < cal <= 500:  score += 15
elif cal <= 800:    score += 5
elif cal > 1000:    score -= 15

# Protein
if pro >= 25:   score += 20
elif pro >= 15: score += 10
elif pro < 5:   score -= 10

# Carbs
if carb <= 50:   score += 10
elif carb > 150: score -= 10

# Fat
if fat <= 15:  score += 10
elif fat > 40: score -= 10

return max(0, min(100, score))
```

**Score interpretation:**
- 80-100: Excellent Choice (green)
- 60-79: Pretty Good (blue)
- 40-59: Average Meal (yellow)
- 0-39: Needs Balance (red)

---

## ⚠️ Known Limitations

- **Speed**: 30-60 seconds per image on CPU. A GPU instance would reduce this to 2-5 seconds.
- **Accuracy**: LLaVA provides estimated values based on visual recognition — not lab-verified data. Varies by portion size and cooking method.
- **Storage**: Data stored on EC2. Terminating the instance loses data. Production should use S3 + RDS.

---

## 🔮 Future Improvements

- [ ] Load past meals from DB into weekly tracker automatically
- [ ] Meal Recommendations — AI suggests healthier alternatives based on history
- [ ] Upgrade to Gemma3:12b for better accuracy
- [ ] GPU instance support for faster inference
- [ ] Multi-user authentication
- [ ] React Native mobile app
- [ ] Integration with verified nutrition APIs (Nutritionix)

---

## 👤 Author

**Krishna Sushanth Katuku**
Master of Information Systems — University of Nebraska Omaha (GPA 3.7)
AI/ML and Full Stack Engineer

Research project under **Professor Chun-Hua Tsai**
Department of Information Systems and Quantitative Analysis, UNO

---

## 🙏 Acknowledgments

- Professor Chun-Hua Tsai, UNO — project guidance and AWS resources
- [Ollama](https://ollama.com) — local LLM inference
- [LLaVA](https://llava-vl.github.io) — open source vision model
- [FastAPI](https://fastapi.tiangolo.com) — Python web framework
