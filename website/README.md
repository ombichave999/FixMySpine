# FixMySpine Website (Frontend & Backend)

This directory contains the complete full-stack web infrastructure for **FixMySpine**.

```
website/
├── frontend/                     # High-performance Apple Pro Dark Mode Landing Page
│   ├── index.html                # Single-page interactive app with SVG Spine kinematics
│   ├── AppIcon.png               # Official app icon asset
│   ├── MenuBarIcon.png           # White menubar spine glyph asset
│   ├── FixMySpine.dmg            # Universal DMG binary download
│   └── package.json              # Frontend scripts & static server config
└── backend/                      # REST API & Telemetry Backend Service
    ├── server.js                 # Express server with health, stats, subscribe & feedback
    ├── package.json              # Backend dependencies (express, cors, morgan, dotenv)
    ├── .env.example              # Environment variables template
    ├── data/                     # Local JSON persistence store (subscribers, feedback)
    └── README.md                 # Detailed backend API reference
```

---

## ⚡ Quick Start

### 1. Install Backend Dependencies
```bash
cd backend
npm install
```

### 2. Run Backend API
```bash
npm run dev
# Running on http://localhost:5001
```

### 3. Run Frontend
```bash
cd ../frontend
npx serve . -p 3000
# Running on http://localhost:3000
```

---

## 🌐 Production Deployment
- **Frontend (Vercel)**: Point Vercel root directory to `website/frontend`
- **Backend (Node / Express)**: Deploy `website/backend` to any Node host (Render, Railway, Fly.io, Vercel Serverless Functions)
