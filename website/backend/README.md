# FixMySpine Backend API

A lightweight, fast Node.js/Express REST API service supporting the FixMySpine marketing site and telemetry sync services.

---

## 🛠 Tech Stack
- **Runtime**: Node.js 18+ (ES Modules)
- **Framework**: Express.js 4.x
- **Middleware**: CORS, Morgan (HTTP logging), Dotenv

---

## 🚀 Getting Started

### 1. Install Dependencies
```bash
npm install
```

### 2. Start Development Server
```bash
npm run dev
```

### 3. Start Production Server
```bash
npm start
```
The server will boot at `http://localhost:5001`.

---

## 📡 API Endpoints Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Service uptime, status, and server timestamp |
| `GET` | `/api/version` | Current release metadata, changelog, and DMG links |
| `GET` | `/api/insights/random` | Random ergonomic posture tips & kinematic facts |
| `GET` | `/api/stats/weekly` | Procedural 7-day posture performance distributions |
| `POST` | `/api/subscribe` | Register user for newsletter & beta updates (`{ email }`) |
| `POST` | `/api/feedback` | Submit bug reports and feature requests (`{ email, message, hardwareModel }`) |

---

## 🧪 Testing with cURL

```bash
# Healthcheck
curl http://localhost:5001/api/health

# Get Version Info
curl http://localhost:5001/api/version

# Get Random Ergonomic Insight
curl http://localhost:5001/api/insights/random

# Subscribe Email
curl -X POST http://localhost:5001/api/subscribe \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'
```
