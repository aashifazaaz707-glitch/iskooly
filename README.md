# ISKOOL — Multi-Tenant School ERP & Campus Operating System
### Built with Flutter (Unified Codebase) + Supabase (PostgreSQL with RLS)

ISKOOL is an enterprise-grade multi-tenant SaaS School ERP platform. It enables you (as Platform Owner / Super Admin) to license and sell the software to different schools under their own branding, enforce student admission quotas per subscription plan, and deliver unified access across **Web**, **Windows Desktop**, and **Android Mobile**.

---

## 🎯 Target Platforms & Access Architecture

```
                               ┌─────────────────────────────────┐
                               │     UNIFIED FLUTTER CODEBASE    │
                               │          lib/main.dart          │
                               └────────────────┬────────────────┘
                                                │
                 ┌──────────────────────────────┼──────────────────────────────┐
                 ▼                              ▼                              ▼
      ┌─────────────────────┐        ┌─────────────────────┐        ┌─────────────────────┐
      │     WEB PORTAL      │        │   WINDOWS DESKTOP   │        │   ANDROID MOBILE    │
      ├─────────────────────┤        ├─────────────────────┤        ├─────────────────────┤
      │ • Super Admin SaaS  │        │ • School Admin App  │        │ • Teacher Portal    │
      │ • School Admin Web  │        │   (.exe)            │        │ • Parent/Student App│
      │   (Browser Access)  │        │ • Direct A4 Printer │        │ (Strict Sign-in Only│
      │                     │        │   hardware access   │        │  NO public signup)  │
      └─────────────────────┘        └─────────────────────┘        └─────────────────────┘
```

- **School Admin Dual-Access:** Admins can manage operations through the **Windows desktop software** OR via the **Web browser**.
- **Teachers, Parents & Students:** Access mobile workflows via the **Android app** with strict **Sign-In ONLY** (no public registration).

---

## 🔐 Multi-Tenancy & Student Limit Guardrail

1. **Brand White-Labeling:** Every document (ID cards, cash fee receipts, admit cards) automatically renders the school's custom name, code, contact details, and address.
2. **Database-Level Admission Quota:** A PostgreSQL trigger (`trg_enforce_student_quota`) validates that active student count cannot exceed `max_students` defined in the school's subscription plan.
3. **Row-Level Security (RLS):** Supabase RLS policies guarantee complete data isolation between schools.

---

## 🚀 Key Features Implemented (eSkooly Reference ERP)

| Module / Section | Deep Customization & Capabilities |
| :--- | :--- |
| **Super Admin SaaS Hub** | • Full tenant lifecycle: Onboard, Customize, Edit Quotas, Activate/Suspend, Delete.<br>• Customization fields: Quota Cap, Currency Symbol (\$, ₹, ₨, £, €), Admission Prefix, Receipt Prefix, Academic Year, Tagline, Due Day.<br>• **Direct Admin Launch:** 1-Click "Open Admin" workspace impersonation to operate any tenant directly.<br>• SaaS KPIs: Total Institutes, Active Licenses, Total Capacity, Platform Est. MRR. |
| **Academic Structure** | • Classes Management: Custom monthly tuition fee & admission fee per class, room number, sections.<br>• Sections Management: Multiple sections per class with max student capacity and assigned rooms. |
| **Student Info System (SIS)** | • Real-time auto-generated sequential Admission Numbers (`SCH-2026-0004`).<br>• Unique Roll Number validation strictly per class & section.<br>• Full student profiles: DOB, Gender, Blood Group, Address, Parent/Guardian, emergency phone.<br>• Actions: Edit student, collect fee, view ID card, view report card, bulk CSV upload with quota protection. |
| **Staff & HR Directory** | • Complete staff directory across 4 roles: Teacher, Accountant, Librarian, Administrator.<br>• Salary compensation tracking, designations, academic departments, qualifications & specializations. |
| **Smart Attendance** | • **4-State Interactive Grid:** Instant single-tap state cycling: **Present ➔ Absent ➔ Late ➔ Half-Day**.<br>• Date validation: Strict enforcement of past/today dates (`date <= CURRENT_DATE`, future blocked).<br>• 1-Tap "Mark All Present" shortcut & real-time turnout telemetry counters.<br>• **Biometric Webhook Simulator:** Hardware punch receiver (`POST /api/v1/attendance/biometric`).<br>• Automated absentee WhatsApp alert queuing. |
| **Double-Entry Finance** | • **Fee Invoicing Engine:** 1-Click monthly invoice generation based on class tuition fee.<br>• **Counter Cash Collections:** Settle invoices with cash, apply waivers/discounts, auto-generate sequential receipts.<br>• **Operating Expense Tracker:** Log vouchers (Salaries, Utilities, Maintenance, Supplies), with live Cash-in-Drawer balance (`Total Collections - Total Expenses = Net Cash`). |
| **Examinations Engine** | • Custom Grading Scales: define custom score bands (A+, A, B, C, D, F) and grade points.<br>• **Weighted Mark Computations:** $\text{Final} = (\text{Assignments} \times 0.20) + (\text{MidTerms} \times 0.30) + (\text{FinalExam} \times 0.50)$.<br>• Auto-calculation of percentage, GPA, and term promotion status. |
| **A4 Bulk Print Hub** | • Configurable ID Cards: 4, 8, or 10 cards per A4 sheet with QR codes & school branding.<br>• Configurable Cash Receipts: 1, 2, or 3 receipts per A4 page with dotted tear-off cutting guides.<br>• Admit Cards with anti-cheating seat allocations and barcodes.<br>• Holistic A4 Term Progress Report Cards with school seal and grading key. |
| **Academic & Campus Operations Suite** | • **Interactive Timetable Grid:** Period scheduling (1 to 6) per weekday with room numbers and class dropdowns.<br>• **Lesson Planning:** Syllabus coverage tracking, lesson objectives, target completion dates, and status.<br>• **Teaching Logbook:** Daily lecture recording with activities covered and assigned homework.<br>• **PTM Appointment Hub:** Slot scheduling and booking system for parent-teacher progress reviews.<br>• **Conduct & Disciplinary Records:** Incident tracking (Behavioral, Academic, Merit/Award) with severity and action logs.<br>• **Campus Notice Board:** School-wide announcements, urgent alerts, and target audience filters.<br>• **Inventory & Asset Register:** Physical equipment, IT hardware, and classroom furniture tracking with cost & condition audit. |
| **Institute Settings** | • Full Admin Customization: edit School Name, Code, Logo, Tagline, Address, Contacts, Currency Symbol, Admission/Receipt Prefixes, Academic Session, and Monthly Fee Due Day. |

---

## 🔑 Demo Login Credentials for All 4 Profiles

On the live sign-in screen, tapping any role tab will **automatically pre-fill** the demo credentials for that profile:

| Profile / Persona | Institution | Login ID / Email | Password | Primary Workflow / Access |
| :--- | :--- | :--- | :--- | :--- |
| **Super Admin (You)** | *(Platform Owner)* | `master@iskool.erp` | `superadmin2026` | SaaS management: Onboard schools, set student quotas & pricing tiers, toggle license status. |
| **School Admin** | *Greenwood International Academy* | `admin@greenwood.edu` | `admin2026` | **Windows Desktop & Web:** Single & bulk CSV student admission, Cash Fee counter with instant receipts, A4 Print Hub (ID cards, admit cards). |
| **Teacher** | *Greenwood International Academy* | `teacher@greenwood.edu` | `teacher2026` | **Android Mobile:** 30-sec roll call (Present, Absent, Late), 1-tap "Mark All Present", QR ID scanner, automated absentee WhatsApp alerts. |
| **Parent / Student** | *Greenwood International Academy* | `ADM-2026-001` | `parent2026` | **Android Mobile:** View live child attendance, cash payment receipts download, timetable, and exam hall ticket with desk assignment. |

---

## 🌐 Live Web Preview

The web version is compiled and actively running:
- **Local Access:** `http://localhost:8080/`
- **Network Access:** `http://10.121.188.95:8080/`

---

## 🛠️ How to Run & Build

### 1. Web
```bash
# Development
flutter run -d chrome

# Production Build
flutter build web --release
```

### 2. Windows Desktop (.exe)
```bash
# Development
flutter run -d windows

# Production Binary
flutter build windows --release
```
Output: `build/windows/x64/runner/Release/iskool.exe`

### 3. Android Mobile (.apk)
```bash
# Development
flutter run -d android

# Production APK
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`
