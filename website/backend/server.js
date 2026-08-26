import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import dotenv from 'dotenv';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = path.join(__dirname, 'data');

import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';

async function atomicWrite(filePath, data) {
  const tmp = filePath + '.tmp';
  await fs.writeFile(tmp, JSON.stringify(data, null, 2));
  await fs.rename(tmp, filePath);
}

const app = express();
const PORT = process.env.PORT || 5001;

// Middleware
const ALLOWED_ORIGINS = (process.env.FRONTEND_URL || 'http://localhost:3000').split(',').map(s => s.trim());
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.includes(origin)) cb(null, true);
    else cb(new Error('CORS: origin not allowed'));
  }
}));
app.disable('x-powered-by');
app.use(helmet());
app.use(compression());
app.use(express.json({ limit: '10kb' }));
app.use(morgan('dev'));

const readLimiter = rateLimit({ windowMs: 60_000, max: 60, standardHeaders: true, legacyHeaders: false });
const writeLimiter = rateLimit({ windowMs: 60_000, max: 20, standardHeaders: true, legacyHeaders: false });

// Ensure data directory exists
async function initDataStorage() {
  try {
    await fs.mkdir(DATA_DIR, { recursive: true });
    const subsPath = path.join(DATA_DIR, 'subscribers.json');
    const feedbackPath = path.join(DATA_DIR, 'feedback.json');
    
    try {
      await fs.access(subsPath);
    } catch {
      await fs.writeFile(subsPath, JSON.stringify([]));
    }
    
    try {
      await fs.access(feedbackPath);
    } catch {
      await fs.writeFile(feedbackPath, JSON.stringify([]));
    }
  } catch (err) {
    console.error('Error initializing data storage:', err);
  }
}

// ----------------------------------------------------
// 1. Health & Telemetry Status API
// ----------------------------------------------------
app.get('/api/health', readLimiter, (req, res) => {
  res.json({
    status: 'healthy',
    app: 'FixMySpine API',
    version: '5.0.4',
    timestamp: new Date().toISOString()
  });
});

// ----------------------------------------------------
// 2. App Version & Release Info
// ----------------------------------------------------
app.get('/api/version', readLimiter, (req, res) => {
  res.json({
    version: '5.0.4',
    buildNumber: 504,
    channel: 'release',
    minOS: 'macOS 14.0 (Sonoma)',
    architecture: 'Universal Binary (Apple Silicon & Intel)',
    supportedHardware: [
      'AirPods Pro (1st & 2nd Generation)',
      'AirPods Max',
      'AirPods (3rd Generation)',
      'Beats Fit Pro',
      'Beats Solo 4'
    ],
    downloadUrl: 'https://fixmyspine-theta.vercel.app/FixMySpine.dmg',
    changelog: [
      'Added high-precision biomorphic 14-vertebrae spinal kinematics',
      'Integrated Web Audio API tactile calibration feedback',
      'Reduced memory footprint to <15MB idle RAM on Apple Silicon',
      'Added Sparkle 2 Ed25519 cryptographic auto-updates'
    ]
  });
});

// ----------------------------------------------------
// 3. Ergonomic Insights Generator API
// ----------------------------------------------------
const INSIGHTS_POOL = [
  {
    category: 'Ergonomics',
    insight: 'Aligning your top monitor bezel directly with eye level reduces cervical spine compression by up to 35%.',
    impact: 'High',
    author: 'FixMySpine Ergonomic Engine'
  },
  {
    category: 'Kinematics',
    insight: 'A 15-degree forward neck tilt increases cervical load on the spine from 10 lbs to over 27 lbs.',
    impact: 'Critical',
    author: 'Kinematic Research Model'
  },
  {
    category: 'Micro-Breaks',
    insight: 'Every 45 minutes of continuous desk focus, perform 3 slow chin tucks to recalibrate deep neck flexors.',
    impact: 'Moderate',
    author: 'Physical Therapy Guidelines'
  },
  {
    category: 'Sensors',
    insight: 'AirPods CoreMotion IMUs sample 60Hz gyroscopic quaternions, eliminating the need for battery-draining camera tracking.',
    impact: 'Telemetry',
    author: 'CoreMotion Hardware Layer'
  },
  {
    category: 'Habit Loop',
    insight: 'Gentle audio haptic reminders trigger conscious spinal realignment before neuromuscular fatigue sets in.',
    impact: 'High',
    author: 'Behavioral Habit Loop'
  }
];

app.get('/api/insights/random', readLimiter, (req, res) => {
  const randomItem = INSIGHTS_POOL[Math.floor(Math.random() * INSIGHTS_POOL.length)];
  res.json({
    success: true,
    data: randomItem,
    timestamp: new Date().toISOString()
  });
});

// ----------------------------------------------------
// 4. Procedural 7-Day Performance Analytics API
// ----------------------------------------------------
app.get('/api/stats/weekly', readLimiter, (req, res) => {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday (Today)'];
  const weekData = days.map((day, idx) => {
    const isWeekend = idx >= 5;
    const score = Math.floor(Math.random() * (isWeekend ? 20 : 16)) + (isWeekend ? 78 : 82);
    const hours = Number((Math.random() * (isWeekend ? 3.0 : 4.0) + (isWeekend ? 2.5 : 4.5)).toFixed(1));
    const tilt = Number((Math.random() * 2.0 + 2.1).toFixed(1));
    return {
      day,
      dayShort: day.charAt(0),
      postureScore: score,
      trackedHours: hours,
      avgTiltDegrees: tilt,
      status: score >= 88 ? 'Optimal' : score >= 78 ? 'Good' : 'Moderate'
    };
  });

  const avgScore = Math.round(weekData.reduce((acc, d) => acc + d.postureScore, 0) / weekData.length);
  const avgTilt = Number((weekData.reduce((acc, d) => acc + d.avgTiltDegrees, 0) / weekData.length).toFixed(1));
  const totalHours = Number(weekData.reduce((acc, d) => acc + d.trackedHours, 0).toFixed(1));

  res.json({
    success: true,
    weeklyAverageScore: avgScore,
    weeklyAverageTilt: avgTilt,
    totalTrackedHours: totalHours,
    activeStreakDays: 5,
    trendVsLastWeek: '+6%',
    days: weekData
  });
});

// ----------------------------------------------------
// 5. Newsletter & Beta Access Signup API
// ----------------------------------------------------
app.post('/api/subscribe', writeLimiter, async (req, res) => {
  try {
    const { email, source = 'website' } = req.body;

    if (typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email.trim()) || email.length > 254) {
      return res.status(400).json({
        success: false,
        error: 'Please provide a valid email address.'
      });
    }

    const subsFile = path.join(DATA_DIR, 'subscribers.json');
    let subscribers = [];
    try {
      const data = await fs.readFile(subsFile, 'utf8');
      subscribers = JSON.parse(data);
    } catch (readErr) {
      console.error('Failed to read data file:', readErr.message);
      return res.status(503).json({ success: false, error: 'Service temporarily unavailable. Please try again.' });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const existing = subscribers.find(s => s.email === normalizedEmail);

    if (existing) {
      return res.json({
        success: true,
        message: 'You are already registered for FixMySpine updates!',
        isNew: false
      });
    }

    const newSub = {
      id: `sub_${Date.now()}`,
      email: normalizedEmail,
      source,
      subscribedAt: new Date().toISOString()
    };

    subscribers.push(newSub);
    await atomicWrite(subsFile, subscribers);

    res.status(201).json({
      success: true,
      message: 'Successfully subscribed to FixMySpine release notes and beta builds.',
      isNew: true
    });
  } catch (err) {
    console.error('Subscription error:', err);
    res.status(500).json({ success: false, error: 'Internal server error processing subscription.' });
  }
});

// ----------------------------------------------------
// 6. User Feedback & Telemetry Bug Report API
// ----------------------------------------------------
app.post('/api/feedback', writeLimiter, async (req, res) => {
  try {
    const { email, message, type = 'general', hardwareModel = 'AirPods Pro' } = req.body;

    if (typeof message !== 'string' || message.trim().length < 5 || message.length > 2000) {
      return res.status(400).json({ success: false, error: 'Message must be 5-2000 characters.' });
    }
    const safeType = ['general', 'bug', 'feature', 'ergonomic'].includes(type) ? type : 'general';
    const safeModel = typeof hardwareModel === 'string' ? hardwareModel.slice(0, 50) : 'Unknown';

    const feedbackFile = path.join(DATA_DIR, 'feedback.json');
    let feedbackList = [];
    try {
      const data = await fs.readFile(feedbackFile, 'utf8');
      feedbackList = JSON.parse(data);
    } catch (readErr) {
      console.error('Failed to read data file:', readErr.message);
      return res.status(503).json({ success: false, error: 'Service temporarily unavailable. Please try again.' });
    }

    const feedbackEntry = {
      id: `fb_${Date.now()}`,
      email: email ? email.trim() : 'anonymous',
      message: message.trim(),
      type: safeType,
      hardwareModel: safeModel,
      createdAt: new Date().toISOString()
    };

    feedbackList.push(feedbackEntry);
    await atomicWrite(feedbackFile, feedbackList);

    res.status(201).json({
      success: true,
      message: 'Thank you for your feedback! The FixMySpine engineering team will review it.'
    });
  } catch (err) {
    console.error('Feedback error:', err);
    res.status(500).json({ success: false, error: 'Failed to record feedback.' });
  }
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: `Route ${req.originalUrl} not found on FixMySpine API.`
  });
});

// Global error handler
app.use((err, req, res, _next) => {
  console.error('Unhandled error:', err.message);
  res.status(err.status || 500).json({
    success: false,
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message
  });
});

// Start Server
initDataStorage().then(() => {
  const server = app.listen(PORT, () => {
    console.log(`🚀 FixMySpine Backend API running on http://localhost:${PORT}`);
    console.log(`📡 Healthcheck: http://localhost:${PORT}/api/health`);
    console.log(`📊 Weekly Stats: http://localhost:${PORT}/api/stats/weekly`);
  });

  const shutdown = (signal) => {
    console.log(`\n${signal} received. Shutting down gracefully...`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 5000);
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
});
