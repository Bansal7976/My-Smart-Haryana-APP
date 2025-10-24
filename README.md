# 🏙️ Smart Haryana - AI-Powered Civic Issues Management Platform

<div align="center">

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.109+-green.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Python](https://img.shields.io/badge/Python-3.12+-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-purple.svg)

**A next-generation platform for streamlined civic issue reporting, intelligent assignment, and real-time resolution tracking.**

[Features](#-features) • [Tech Stack](#-tech-stack) • [Installation](#-installation) • [Usage](#-usage) • [API Docs](#-api-documentation) • [Contributing](#-contributing)

### 🎯 Key Highlights

| Feature | Description |
|---------|-------------|
| 🤖 **AI Multi-Agent System** | LangGraph-powered chatbot with Pinecone RAG, analytics, and web search |
| 🎤 **Voice Input** | Report issues and chat in English, Hindi, or Punjabi |
| 🔍 **AI Image Detection** | Automatically rejects AI-generated/fake images |
| 👥 **Auto Admin Setup** | Super Admin + 22 district admins created automatically |
| 📍 **GPS Verification** | Workers must be on-site (500m radius) to complete tasks |
| 📊 **Real-Time Analytics** | District and state-level performance dashboards |
| 🏥 **Production Ready** | Health checks, monitoring, and zero-config deployment |
| ✅ **Fully Tested** | All features verified and working on Android |

</div>

---

## 📋 Table of Contents

- [Recent Updates](#-recent-updates-v20)
- [Overview](#-overview)
- [Key Features](#-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Running the Application](#-running-the-application)
- [User Roles & Workflows](#-user-roles--workflows)
- [API Documentation](#-api-documentation)
- [Database Schema](#-database-schema)
- [Security Features](#-security-features)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎊 Recent Updates (v2.0)

### ✅ **Latest Fixes & Improvements**

| Component | Fix | Status |
|-----------|-----|--------|
| **Backend** | PostGIS location field serialization | ✅ Fixed |
| **Backend** | Verify endpoint eager loading (feedback & assigned_to) | ✅ Fixed |
| **Backend** | Pinecone vector database integration (replaces ChromaDB) | ✅ Implemented |
| **Backend** | Bcrypt compatibility (downgraded to 3.2.2) | ✅ Fixed |
| **Frontend** | Image display with full URL construction | ✅ Fixed |
| **Frontend** | Super Admin analytics UI overflow | ✅ Fixed |
| **Frontend** | Login button text overflow | ✅ Fixed |
| **Frontend** | Worker feedback visibility | ✅ Fixed |
| **Frontend** | Total users calculation (clients + workers + admins) | ✅ Fixed |
| **Features** | Citizens can view uploaded & proof photos | ✅ Working |
| **Features** | Feedback system (star rating + comments) | ✅ Working |
| **Features** | Voice input for chatbot & issue reporting | ✅ Working |
| **Features** | About page in citizen dashboard | ✅ Added |

### 🚀 **Verified & Working Features**
- ✅ Login/Registration (all user types)
- ✅ Issue reporting with voice-to-text
- ✅ Image upload (initial + proof photos)
- ✅ Auto-assignment with priority calculation
- ✅ Worker task completion with GPS verification
- ✅ Feedback system with sentiment analysis
- ✅ Multi-agent chatbot with Pinecone RAG
- ✅ Real-time analytics (district & state-level)
- ✅ AI image detection
- ✅ Multi-language support (English/Hindi)

**Tagline:** *"Every voice matters, every issue counts — powered by AI for a smarter Haryana."*

---

## 🌟 Overview

**Smart Haryana** is an enterprise-grade civic issue management system that revolutionizes how citizens report problems and how governments respond. Built with cutting-edge AI technology, it features:

- 🤖 **AI-Powered Multi-Agent Chatbot** using Google Gemini & LangGraph
- 🎤 **Voice-to-Text Reporting** supporting English, Hindi, and Punjabi
- 🔍 **AI Image Verification** to prevent fake/AI-generated image uploads
- 📍 **GPS-Based Issue Tracking** with PostGIS spatial queries
- 🎯 **Intelligent Auto-Assignment** with priority-based load balancing
- 📊 **Real-Time Analytics Dashboard** with district and state-level insights
- 🌐 **Multi-Language Support** for accessibility across Haryana
- 🔐 **Enterprise-Grade Security** with JWT, input sanitization & image validation
- 🏥 **Production Monitoring** with health check endpoints
- 👥 **Auto-Deployment Ready** with automated admin account creation

---

## ✨ Features

### 🆕 **Latest Features (v2.0)**
- 🎤 **Voice-to-Text** - Report issues using voice (English, Hindi, Punjabi)
- 🤖 **AI Image Detection** - Automatically rejects AI-generated/fake images
- 🏥 **Health Monitoring** - Built-in health check endpoint for uptime monitoring
- 👤 **Auto Admin Seeding** - Automatic creation of Super Admin & 22 District Admins
- 📊 **Enhanced Analytics** - State-wide and district-level performance insights

### For Citizens (Clients)
- 📸 **Report Issues** with photo evidence and GPS location
- 🎤 **Voice Input** - Describe problems using voice recording (multi-language)
- 🗺️ **Track Issue Status** in real-time
- 💬 **AI Chatbot Assistant** powered by RAG (Retrieval Augmented Generation)
- ⭐ **Rate & Provide Feedback** on resolved issues with sentiment analysis
- 📱 **Mobile-First Design** with native Android support

### For Workers
- 📋 **View Assigned Tasks** sorted by intelligent priority algorithm
- ✅ **Complete Tasks** with GPS verification (500m radius) and proof photos
- 📊 **Performance Analytics** with ratings and completion stats
- 🔔 **Real-Time Notifications** for new assignments
- 📍 **GPS Verification** - Must be at location to complete tasks

### For Administrators
- 👥 **Manage Workers & Departments** with role-based access
- 📈 **View Analytics & KPIs** for district-wide performance
- ✅ **Verify Completed Issues** with AI-verified proof photos
- 🎯 **Monitor Auto-Assignment** efficiency with load balancing
- 📊 **Department Analytics** - Track performance by department

### For Super Admins
- 🏢 **Manage District Admins** across all 22 Haryana districts
- 🌐 **System-Wide Analytics** and oversight (state-level dashboard)
- ⚙️ **Configure System Settings** and policies
- 👥 **Auto-Created on First Deploy** - `haryana@gov.in` / `Haryana@4321`

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
│  (Client, Worker, Admin, Super Admin Dashboards)            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ REST API (JWT Auth)
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                  FastAPI Backend Server                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Multi-Agent AI System (LangGraph)                   │   │
│  │  ├─ RAG Agent (Knowledge Base)                       │   │
│  │  ├─ Gemini Agent (Conversational AI)                 │   │
│  │  ├─ Web Search Agent (Tavily)                        │   │
│  │  └─ Analytics Agent (Database Queries)               │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ├─ Auto-Assignment Scheduler (APScheduler)                 │
│  ├─ Priority Calculation Engine (PostGIS Geospatial)       │
│  ├─ Voice-to-Text Service (Google Speech API)              │
│  ├─ AI Image Detection (OpenCV + scikit-image)             │
│  ├─ Sentiment Analysis (TextBlob)                           │
│  ├─ Health Check Endpoint (/health)                         │
│  └─ Security Middleware (CORS, Headers, Validation)         │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│         PostgreSQL + PostGIS (Spatial Database)              │
│  ├─ Users & Roles (RBAC)                                    │
│  ├─ Problems & Media (Images)                               │
│  ├─ Departments & Workers                                   │
│  ├─ Feedback & Ratings                                      │
│  └─ Chat History & Sessions                                 │
└──────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

### Backend
- **Framework:** FastAPI 0.109+
- **Database:** PostgreSQL 15+ with PostGIS extension
- **Database Driver:** psycopg 3.1+ (async with connection pooling)
- **ORM:** SQLAlchemy 2.0 (Async)
- **Authentication:** JWT with bcrypt password hashing
- **AI/ML:**
  - Google Gemini 1.5 Flash (LLM)
  - LangChain 0.1+ & LangGraph 0.0.55+ (Multi-Agent System)
  - Pinecone (Cloud Vector Database for RAG)
  - Sentence Transformers (all-MiniLM-L6-v2) 2.3+ (Embeddings)
  - TextBlob 0.17+ (Sentiment Analysis)
- **Voice Processing:**
  - SpeechRecognition 3.10+ (Audio to text)
  - pydub 0.25+ (Audio manipulation)
  - Google Cloud Speech API (Multi-language support)
- **Image Processing:**
  - OpenCV 4.8+ (Image analysis)
  - scikit-image 0.22+ (AI detection algorithms)
  - Pillow 10.2+ (Image manipulation)
- **Task Scheduling:** APScheduler 3.10+ (Auto-assignment & daily resets)
- **File Storage:** Local filesystem with AI-powered validation
- **Monitoring:** Built-in health check endpoints

### Frontend
- **Framework:** Flutter 3.0+ (Dart)
- **State Management:** Provider 6.1+
- **HTTP Client:** http 1.1+ with multipart upload support
- **Location Services:** Geolocator 10.1+ (GPS tracking)
- **Secure Storage:** flutter_secure_storage 9.0+ (Token management)
- **Image Handling:** image_picker 1.0+ & cached_network_image 3.3+
- **Audio Recording:** record 5.0+ (Voice-to-text feature)
- **Permissions:** permission_handler 11.1+ (Camera, mic, location)
- **File Storage:** path_provider 2.1+ (Temporary audio files)

### DevOps & Infrastructure
- **Web Server:** Uvicorn (ASGI)
- **CORS:** Configurable origin whitelist
- **Logging:** Python logging with structured logs
- **Environment:** python-dotenv for configuration

---

## 📦 Prerequisites

### Backend Requirements
- Python 3.12+
- PostgreSQL 15+ with PostGIS extension
- pip or conda for package management

### Frontend Requirements
- Flutter SDK 3.0+
- Android SDK (for mobile deployment)
- Android device or emulator

### API Keys
- **Google AI Studio API Key** (for Gemini LLM) - Required
- **Pinecone API Key** (for RAG vector storage) - Optional but recommended
- **Tavily API Key** (for web search) - Optional

---

## 💻 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/smart-haryana.git
cd smart-haryana
```

### 2. Backend Setup

#### Install PostgreSQL with PostGIS
```bash
# Windows (using Chocolatey)
choco install postgresql postgis

# macOS
brew install postgresql postgis

# Linux (Ubuntu/Debian)
sudo apt-get install postgresql-15 postgresql-15-postgis-3
```

#### Create Database
```sql
CREATE DATABASE smart_haryana;
\c smart_haryana
CREATE EXTENSION postgis;
```

#### Install Python Dependencies
```bash
cd backend/civic_issues_backend
pip install -r requirements.txt
```

### 3. Frontend Setup

#### Install Flutter Dependencies
```bash
cd frontend/civic_issues_frontend
flutter pub get
```

#### Android Platform Setup
```bash
# Generate Android platform files (if missing)
flutter create --platforms=android .
```

---

## ⚙️ Configuration

### Backend Environment Variables

Create `.env` file in `backend/civic_issues_backend/`:

```env
# ========================================
# SMART HARYANA - PRODUCTION CONFIGURATION
# ========================================

# Database Configuration (PostgreSQL with PostGIS)
DATABASE_URL=postgresql+psycopg://username:password@localhost:5432/civic_issues_db

# Security (Generate with: openssl rand -hex 32)
SECRET_KEY=your-super-secret-key-minimum-32-characters-long-abc123def456
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080  # 7 days

# AI Configuration
GOOGLE_API_KEY=AIzaSy...  # Get from https://aistudio.google.com/
TAVILY_API_KEY=tvly-...   # Optional: Get from https://tavily.com
PINECONE_API_KEY=pcsk_...  # Optional: Get from https://www.pinecone.io/
PINECONE_INDEX_NAME=smart-haryana  # Pinecone index name (auto-created)
CHATBOT_MODEL=gemini-1.5-flash
CHATBOT_TEMPERATURE=0.7
EMBEDDING_MODEL=all-MiniLM-L6-v2

# Worker & Task Settings
MAX_DAILY_TASKS_PER_WORKER=10
PRIORITY_DENSITY_WEIGHT=0.6
PRIORITY_URGENCY_WEIGHT=0.4

# GPS Verification Settings
GPS_VERIFICATION_RADIUS_METERS=100  # Worker must be within 100m

# Rate Limiting (Prevent abuse)
MAX_VOICE_TO_TEXT_PER_HOUR=20
MAX_CHATBOT_MESSAGES_PER_MINUTE=10

# CORS Configuration (Add your server IP for mobile testing)
ALLOWED_ORIGINS=http://localhost:3000,http://192.168.1.100:8000

# File Upload Settings
MAX_FILE_SIZE_MB=5
ALLOWED_FILE_TYPES=image/jpeg,image/png,image/jpg,image/webp

# Environment
ENVIRONMENT=production  # Use 'development' for local testing
```

**Generate a secure SECRET_KEY:**
```bash
openssl rand -hex 32
```

### Frontend Configuration

Update `frontend/civic_issues_frontend/lib/services/api_service.dart`:

```dart
// Line 12: Update with your laptop's IP address
static const String baseUrl = 'http://YOUR_LAPTOP_IP:8000';

// To find your IP:
// Windows: ipconfig (look for IPv4)
// macOS/Linux: ifconfig or ip addr
```

---

## 🚀 Running the Application

### Start Backend Server

```bash
cd backend/civic_issues_backend

# Development mode (auto-reload)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production mode
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

**Expected Output:**
```
✅ Super Admin created: haryana@gov.in
✅ Created 22 district admin(s)
🔐 Admin Credentials:
   Super Admin: haryana@gov.in / Haryana@4321
   District Admins: [district]@gov.in / [District]@4321
✓ Loaded 45 chunks from knowledge base
🚀 Smart Haryana API started successfully!
INFO: Application startup complete.
INFO: Uvicorn running on http://0.0.0.0:8000
```

**🎉 First Time Startup:**
- Super Admin and 22 District Admins are **automatically created**
- No manual database seeding required!
- Ready to use immediately with pre-configured admin accounts

### Start Frontend (Mobile)

```bash
cd frontend/civic_issues_frontend

# Connect your Android device via USB, then:
flutter run

# Or build APK for distribution:
flutter build apk --release
```

### Access Points

- **API Docs (Swagger):** http://localhost:8000/docs
- **API Docs (ReDoc):** http://localhost:8000/redoc
- **Mobile App:** Install on Android device

---

## 👥 User Roles & Workflows

### 1️⃣ Super Admin
**✨ Automatic Setup (No Manual Steps Needed!):**
- **Email:** `haryana@gov.in`
- **Password:** `Haryana@4321`
- **Auto-created** on first backend startup
- All 22 district admins also created automatically

**Pre-Created District Admins:**
```
Ambala@gov.in      / Ambala@4321
Bhiwani@gov.in     / Bhiwani@4321
Gurugram@gov.in    / Gurugram@4321
Sirsa@gov.in       / Sirsa@4321
... (22 districts total)
```

**Responsibilities:**
- Manage district admins (view, create, deactivate)
- View system-wide analytics across all 22 districts
- Configure global settings and policies
- Monitor state-level performance metrics

### 2️⃣ Admin (District-Level)
**Setup:**
1. Created by Super Admin
2. Assigned to specific district

**Workflow:**
1. Create workers and assign to departments
2. Monitor district-wide issues
3. Verify completed tasks
4. View analytics dashboard

### 3️⃣ Worker
**Setup:**
1. Created by Admin with department assignment
2. Receives auto-assigned tasks

**Workflow:**
1. View assigned tasks (sorted by priority)
2. Navigate to issue location
3. Complete task with GPS verification
4. Upload proof photo
5. Mark as completed

### 4️⃣ Client (Citizen)
**Workflow:**
1. Register account
2. Report issue:
   - Capture/upload photo
   - Get GPS location
   - Add description
   - Submit
3. Track issue status
4. Provide feedback on completion
5. Rate worker performance

---

## 📚 API Documentation

### Authentication Endpoints

#### Register User
```http
POST /auth/register
Content-Type: application/json

{
  "full_name": "John Doe",
  "email": "john@example.com",
  "password": "SecurePass@123",
  "district": "Gurugram",
  "pincode": "122001"
}
```

#### Login
```http
POST /auth/login
Content-Type: application/x-www-form-urlencoded

username=john@example.com&password=SecurePass@123
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "bearer"
}
```

### Issue Management

#### Create Issue
```http
POST /users/issues
Authorization: Bearer <token>
Content-Type: multipart/form-data

title=Pothole on Main Road
description=Large pothole causing traffic issues
problem_type=Road Repair
district=Gurugram
latitude=28.4595
longitude=77.0266
file=@photo.jpg
```

#### Get User Issues
```http
GET /users/issues
Authorization: Bearer <token>
```

### Chatbot

#### Send Message
```http
POST /chatbot/chat
Authorization: Bearer <token>
Content-Type: application/json

{
  "message": "How do I report an issue?",
  "session_id": "uuid-here"
}
```

### Voice-to-Text (NEW!)

#### Convert Audio to Text
```http
POST /users/voice-to-text
Authorization: Bearer <token>
Content-Type: multipart/form-data

audio_file=@recording.webm
language=hi-IN  # Options: en-IN, hi-IN, pa-IN, en-US, en-GB
```

**Response:**
```json
{
  "text": "मुख्य सड़क पर गड्ढा है",
  "language": "hi-IN",
  "confidence": 1.0
}
```

#### Get Supported Languages
```http
GET /users/voice-to-text/languages
Authorization: Bearer <token>
```

### Health Check (Monitoring)

#### Check System Health
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "2.0.0",
  "database": "connected",
  "services": {
    "auto_assignment": "active",
    "chatbot": "active",
    "voice_to_text": "active",
    "ai_image_detection": "active"
  }
}
```

**Full API documentation:** http://localhost:8000/docs

---

## 🗄️ Database Schema

### Key Tables

#### Users
```sql
- id (PK)
- full_name
- email (unique)
- hashed_password
- role (client, worker, admin, super_admin)
- district
- pincode
- is_active
- created_at
```

#### Problems
```sql
- id (PK)
- title
- description
- problem_type
- district
- location (PostGIS POINT)
- priority (calculated)
- status (pending, assigned, completed, verified)
- user_id (FK → users)
- assigned_worker_id (FK → worker_profiles)
- created_at
- updated_at
```

#### Departments
```sql
- id (PK)
- name (unique)
```

#### Worker Profiles
```sql
- id (PK)
- user_id (FK → users)
- department_id (FK → departments)
- daily_task_count
```

---

## 🔒 Security Features

### Authentication & Authorization
- ✅ JWT-based stateless authentication
- ✅ Bcrypt password hashing with salt
- ✅ Role-based access control (RBAC) - 4 roles
- ✅ Token expiration (7 days default, configurable)
- ✅ Active user validation on every request
- ✅ Secure token storage (flutter_secure_storage)

### Input Validation
- ✅ Pydantic schemas with strict validation
- ✅ XSS prevention via dangerous pattern filtering
- ✅ SQL injection prevention (SQLAlchemy ORM)
- ✅ Field length constraints and regex validation
- ✅ Email format validation

### File Upload Security 🆕
- ✅ **AI Image Detection** - Rejects AI-generated images
  - EXIF metadata analysis (weight: 3)
  - Noise pattern detection (weight: 2)
  - Compression artifact checking (weight: 1)
  - Suspicion threshold: 4/6
- ✅ Extension whitelist (jpg, jpeg, png, webp only)
- ✅ Size limits (5MB for images, 10MB for audio)
- ✅ Filename sanitization (prevents path traversal)
- ✅ Content-type validation
- ✅ Secure file storage with UUID naming

### Location Security
- ✅ **GPS Verification** - Workers must be within 500m to complete tasks
- ✅ PostGIS spatial queries for accurate distance calculation
- ✅ Location permission checks (Android)

### Network Security
- ✅ CORS with strict origin whitelist
- ✅ Security headers (X-Frame-Options, X-XSS-Protection, etc.)
- ✅ HTTPS support (production)
- ✅ Request body size limits
- ✅ Rate limiting configuration (voice-to-text, chatbot)

### Password Policy
- ✅ Minimum 8 characters
- ✅ At least 1 uppercase letter
- ✅ At least 1 lowercase letter
- ✅ At least 1 digit
- ✅ At least 1 special character (!@#$%^&*)

---

## 🐛 Troubleshooting

### Common Issues

#### Backend won't start
```bash
# Check PostgreSQL is running
sudo service postgresql status  # Linux
# or
brew services list  # macOS

# Check PostGIS extension
psql -d smart_haryana -c "SELECT PostGIS_Version();"

# Verify environment variables
cat .env
```

#### Frontend can't connect to backend
```bash
# Check IP address
ipconfig  # Windows
ifconfig  # macOS/Linux

# Update frontend/civic_issues_frontend/lib/services/api_service.dart:12
static const String baseUrl = 'http://YOUR_IP:8000';

# Verify backend is listening on 0.0.0.0
# Should see: INFO: Uvicorn running on http://0.0.0.0:8000

# Check firewall (Windows)
# Allow inbound TCP port 8000
```

#### Chatbot 404 errors
```bash
# Verify Gemini API key in .env
echo $GOOGLE_API_KEY

# Check model name in config.py
# Should be: CHATBOT_MODEL = "gemini-1.5-flash"

# Test API key:
curl -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"Hello"}]}]}' \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_API_KEY"
```

#### Auto-assignment not working
```bash
# Ensure departments exist
# Department names must match problem types:
# - Roads (for Pothole, Road Repair)
# - Electrical (for Street Light, Electrical)
# - Water (for Water Supply)
# - Sanitation (for Sewage, Drainage, Cleaning)

# Ensure workers exist in the same district as the issue
# Check logs for:
# "Auto-Assignment: No department found..." → Create departments
# "Auto-Assignment: No available workers..." → Create workers
```

#### GPS location not working (Android)
```bash
# Ensure permissions in AndroidManifest.xml:
# - ACCESS_FINE_LOCATION
# - ACCESS_COARSE_LOCATION

# Check location services on device
# Settings → Location → Enable

# Grant app permissions
# Settings → Apps → Smart Haryana → Permissions → Location → Allow
```

#### Voice-to-Text not working
```bash
# 1. Check microphone permission (Android)
# AndroidManifest.xml must have:
# <uses-permission android:name="android.permission.RECORD_AUDIO" />

# 2. Grant microphone permission
# Settings → Apps → Smart Haryana → Permissions → Microphone → Allow

# 3. Test audio recording
# Open app, try voice input - should see recording indicator

# 4. Check supported languages
# GET /users/voice-to-text/languages
# Supported: en-IN, hi-IN, pa-IN, en-US, en-GB

# 5. Verify audio format
# Supported formats: webm, ogg, mp3, wav
# Max size: 10MB
```

#### AI Image Detection rejecting real photos
```bash
# If legitimate photos are being rejected:

# 1. Check image source
# - Use camera to take photo (best results)
# - Avoid heavily edited images
# - Avoid screenshots

# 2. Image requirements
# - Must have EXIF metadata (camera photos have this)
# - Natural noise patterns (not overly smooth)
# - Proper JPEG compression

# 3. Disable verification (development only)
# In app/storage.py:
# Comment out the validate_image_is_real() call

# Note: AI detection has "fail-open" behavior
# If verification encounters errors, upload proceeds
```

#### Admin accounts not created
```bash
# Check backend startup logs
# Should see:
# ✅ Super Admin created: haryana@gov.in
# ✅ Created 22 district admin(s)

# If not appearing:
# 1. Check database connection
psql -U postgres -d civic_issues_db -c "\dt"

# 2. Check seed_admins.py logs
# Should show "Admin already exists" if they were created before

# 3. Manual check
psql -U postgres -d civic_issues_db
SELECT email, role, district FROM users WHERE role IN ('super_admin', 'admin');

# 4. Force re-creation (if needed)
# DELETE FROM users WHERE email LIKE '%@gov.in';
# Then restart backend
```

---

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Standards
- **Backend:** Follow PEP 8 (Python)
- **Frontend:** Follow Effective Dart guidelines
- **Commits:** Use conventional commits (feat:, fix:, docs:, etc.)
- **Tests:** Write tests for new features

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Authors

- **Smart Haryana Team** - *Initial work*

---

## 🙏 Acknowledgments

- Google Gemini API for AI capabilities
- LangChain & LangGraph for multi-agent orchestration
- FastAPI community for the amazing framework
- Flutter team for cross-platform development tools
- PostgreSQL & PostGIS for robust geospatial database

---

## 🌟 What Makes Smart Haryana Unique?

### 🚀 Production-Ready from Day 1
- **Zero Manual Setup**: Super Admin and all 22 district admins auto-created on first startup
- **Health Monitoring**: Built-in `/health` endpoint for uptime monitoring and load balancers
- **Comprehensive Logging**: Structured logs for debugging and audit trails

### 🤖 AI-Powered Features
1. **Multi-Agent Chatbot** (LangGraph + Gemini)
   - RAG Agent: Answers from knowledge base
   - Analytics Agent: Real-time database queries
   - Web Search Agent: Current information via Tavily
   - Gemini Agent: General conversational AI

2. **AI Image Verification**
   - Detects AI-generated images using multi-factor analysis
   - EXIF metadata + noise patterns + compression artifacts
   - Prevents fraudulent issue reports

3. **Voice-to-Text Input**
   - Multi-language support (English, Hindi, Punjabi)
   - Accessibility for non-tech-savvy users
   - Seamless integration with issue reporting

### 🎯 Intelligent Automation
- **Auto-Assignment**: Priority-based, district-matched, load-balanced
- **Priority Calculation**: Geospatial density + problem type urgency
- **Daily Task Reset**: Automatic worker capacity refresh at midnight
- **Sentiment Analysis**: Automatic feedback sentiment classification

### 🔒 Enterprise Security
- **4-Layer File Validation**: Extension + Size + AI Detection + Path Security
- **GPS Verification**: Workers must be on-site (500m radius)
- **Rate Limiting**: Prevents abuse of AI features
- **Role-Based Access**: 4 roles with granular permissions

### 📊 Analytics & Insights
- **District-Level**: Performance metrics per district
- **State-Wide**: Haryana overview for Super Admins
- **Department Analytics**: Track efficiency by department
- **Worker Performance**: Ratings, completion stats, load balancing

---

## 📞 Support

For support, email support@smartharyana.com or open an issue in the GitHub repository.

**Quick Links:**
- 📖 [API Documentation](http://localhost:8000/docs)
- 🏥 [Health Check](http://localhost:8000/health)
- 🤖 [Chatbot Guide](http://localhost:8000/docs#/Chatbot)

---

<div align="center">

**Built with ❤️ for Haryana Citizens**

*Empowering communities through technology*

[⬆ Back to Top](#-smart-haryana---ai-powered-civic-issues-management-platform)

</div>

