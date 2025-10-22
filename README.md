# 🏙️ Smart Haryana - AI-Powered Civic Issues Management Platform

<div align="center">

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.109+-green.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Python](https://img.shields.io/badge/Python-3.12+-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-purple.svg)

**A next-generation platform for streamlined civic issue reporting, intelligent assignment, and real-time resolution tracking.**

[Features](#-features) • [Tech Stack](#-tech-stack) • [Installation](#-installation) • [Usage](#-usage) • [API Docs](#-api-documentation) • [Contributing](#-contributing)

</div>

---

## 📋 Table of Contents

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

## 🌟 Overview

**Smart Haryana** is an enterprise-grade civic issue management system that revolutionizes how citizens report problems and how governments respond. Built with cutting-edge AI technology, it features:

- 🤖 **AI-Powered Multi-Agent Chatbot** using Google Gemini & LangGraph
- 📍 **GPS-Based Issue Tracking** with PostGIS spatial queries
- 🎯 **Intelligent Auto-Assignment** based on department, district, and worker availability
- 📊 **Real-Time Analytics Dashboard** for administrators
- 🌐 **Bilingual Support** (English & Hindi) for accessibility
- 🔐 **Enterprise-Grade Security** with JWT authentication & input sanitization

---

## ✨ Features

### For Citizens (Clients)
- 📸 **Report Issues** with photo evidence and GPS location
- 🗺️ **Track Issue Status** in real-time
- 💬 **AI Chatbot Assistant** powered by RAG (Retrieval Augmented Generation)
- ⭐ **Rate & Provide Feedback** on resolved issues
- 📱 **Mobile-First Design** with Android support

### For Workers
- 📋 **View Assigned Tasks** sorted by priority
- ✅ **Complete Tasks** with GPS verification and proof photos
- 📊 **Performance Analytics** with ratings and completion stats
- 🔔 **Real-Time Notifications** for new assignments

### For Administrators
- 👥 **Manage Workers & Departments** with role-based access
- 📈 **View Analytics & KPIs** for district-wide performance
- ✅ **Verify Completed Issues** with proof validation
- 🎯 **Monitor Auto-Assignment** efficiency

### For Super Admins
- 🏢 **Manage District Admins** across multiple regions
- 🌐 **System-Wide Analytics** and oversight
- ⚙️ **Configure System Settings** and policies

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
│  ├─ Priority Calculation Engine (Geospatial)                │
│  ├─ Sentiment Analysis (TextBlob)                           │
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
- **ORM:** SQLAlchemy 2.0 (Async)
- **Authentication:** JWT with bcrypt password hashing
- **AI/ML:**
  - Google Gemini 1.5 Flash (LLM)
  - LangChain 0.1+ & LangGraph 0.0.20+ (Multi-Agent System)
  - ChromaDB (Vector Database for RAG)
  - Sentence Transformers (Embeddings)
  - TextBlob (Sentiment Analysis)
- **Task Scheduling:** APScheduler 3.10+
- **File Storage:** Local filesystem with secure validation
- **Testing:** Pytest (planned)

### Frontend
- **Framework:** Flutter 3.0+ (Dart)
- **State Management:** Provider 6.1+
- **HTTP Client:** http 1.1+ with retry logic
- **Location Services:** Geolocator 10.1+
- **Secure Storage:** flutter_secure_storage 9.0+
- **Image Handling:** image_picker 1.0+

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
- **Google AI Studio API Key** (for Gemini LLM)
- **Tavily API Key** (optional, for web search)

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
# Database Configuration
DATABASE_URL=postgresql+psycopg://username:password@localhost:5432/smart_haryana

# Security (Generate strong 32+ character key)
SECRET_KEY=your-super-secret-key-minimum-32-characters-long-abc123def456
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# AI Configuration
GOOGLE_API_KEY=AIzaSy...  # Get from https://makersuite.google.com/app/apikey
TAVILY_API_KEY=tvly-...   # Optional: Get from https://tavily.com
CHATBOT_MODEL=gemini-1.5-flash
CHATBOT_TEMPERATURE=0.7

# CORS Configuration (Add your laptop IP for mobile testing)
ALLOWED_ORIGINS=http://localhost:3000,http://192.168.1.100:8000

# File Upload Settings
MAX_FILE_SIZE_MB=10
ALLOWED_FILE_TYPES=image/jpeg,image/png,image/jpg,image/webp

# Environment
ENVIRONMENT=development
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
✓ Loaded 45 chunks from knowledge base
INFO: Application startup complete.
INFO: Uvicorn running on http://0.0.0.0:8000
```

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
**First-Time Setup:**
1. Register first user as Super Admin (automatically assigned)
2. Create departments: Roads, Electrical, Water, Sanitation, Transport
3. Create district-level admins

**Responsibilities:**
- Manage district admins
- View system-wide analytics
- Configure global settings

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
- ✅ Role-based access control (RBAC)
- ✅ Token expiration (24 hours default)

### Input Validation
- ✅ Pydantic schemas with strict validation
- ✅ XSS prevention via input sanitization
- ✅ SQL injection prevention (SQLAlchemy ORM)
- ✅ File upload security:
  - Extension whitelist (jpg, png, webp)
  - Size limits (10MB default)
  - Filename sanitization
  - Path traversal prevention

### Network Security
- ✅ CORS with origin whitelist
- ✅ Security headers (X-Frame-Options, CSP, etc.)
- ✅ HTTPS support (production)

### Password Policy
- ✅ Minimum 8 characters
- ✅ At least 1 uppercase letter
- ✅ At least 1 lowercase letter
- ✅ At least 1 digit
- ✅ At least 1 special character

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
# Settings → Apps → Civic Issues → Permissions → Location → Allow
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

## 📞 Support

For support, email support@smartharyana.com or open an issue in the GitHub repository.

---

<div align="center">

**Built with ❤️ for Haryana Citizens**

[⬆ Back to Top](#-smart-haryana---ai-powered-civic-issues-management-platform)

</div>

