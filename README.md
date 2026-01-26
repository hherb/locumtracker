# LocumTracker

**The smart companion for Australian locum doctors** — track your work, maximise your rural subsidies, and simplify your invoicing.

---

## Why LocumTracker?

As a locum doctor, your time is valuable. You shouldn't spend hours wrestling with spreadsheets, chasing receipts, or worrying about whether you've met your quarterly rural subsidy quota.

**LocumTracker does the heavy lifting for you:**

- **Never miss a subsidy dollar** — Real-time MMM quota tracking ensures you meet your 21-session quarterly requirement
- **Invoicing in seconds** — Generate compliant tax invoices with proper ABN validation and GST calculations
- **Receipts at your fingertips** — Snap photos of expenses and link them to work sessions instantly
- **Works everywhere you do** — Sync seamlessly between your iPhone and Mac

---

## Key Features

### Work Tracking Made Simple

| Feature | What It Does For You |
|---------|---------------------|
| **Smart Sessions** | Log daily/hourly work with flexible rate structures — perfect for varied locum contracts |
| **Session Templates** | Create templates for common session types and batch-create sessions across date ranges |
| **Auto Session Splitting** | Sessions over 5 hours automatically split into two for accurate subsidy tracking |
| **Location Intelligence** | Automatic MMM classification lookup for every workplace with provider numbers and contact info |
| **On-Call Support** | Track regular, on-call, and call-out sessions with appropriate rate calculations |
| **Multi-Location Assignments** | Organise work by contract with multiple locations, date ranges, and rates |

### Rural Subsidy Compliance

Stop guessing — **know exactly where you stand** with your rural incentive payments.

- **Live Quota Dashboard** — See your MMM3-7 hours at a glance
- **Progress Alerts** — Get notified when you're falling behind on quarterly requirements
- **Travel Credits** — Automatically calculate eligible travel time subsidies
- **Vocational/Non-Vocational Rates** — Correct subsidy calculations based on your registration status

### Receipt & Expense Management

- **Camera Capture** (iOS) — Photograph receipts on the go
- **Share Extension** — Import documents directly from Mail, Files, Safari and other apps
- **Attachment Support** — Link PDFs, emails, and images to assignments or receipts
- **Multiple Attachments** — Attach multiple photos, PDFs, and documents to each receipt
- **Share Extension** — Import documents directly from Mail, Files, Safari and other apps
- **Smart Categorisation** — Travel, accommodation, meals, equipment
- **Cloud Backup** — Never lose a receipt again with automatic iCloud sync
- **Tax Time Ready** — Export organised expense reports

### Professional Invoicing

- **Australian Tax Compliant** — Proper GST handling and ABN validation
- **Multiple Export Formats** — PDF for clients, data exports for your accountant
- **Template Support** — Customise invoices with your practice details

---

## Current Status

| Component | Status |
|-----------|--------|
| Core Business Logic | **Complete** — 197 tests passing |
| Rural Subsidy Calculations | **Complete** — Full MMM/FPS support |
| Data Models | **Complete** — All entities defined |
| Receipt OCR Engine | **Complete** — PaddleOCR via ONNX Runtime |
| iOS App UI | **Functional** — All main views implemented |
| iOS Share Extension | **Complete** — Share documents from other apps |
| Storage Layer | **Complete** — Repositories + CloudKit sync |
| macOS App UI | **Planned** |

**What works today:**
- Full work tracking: assignments, sessions, locations, daily records
- Multi-location assignments with session templates for batch session creation
- Automatic session splitting for sessions exceeding 5 hours
- Share Extension to import documents from other apps (PDFs, emails, images)
- Receipt management with camera capture and image cropping
- Receipt management with multiple attachments (photos, PDFs, documents)
- Share Extension to import documents from other apps (PDFs, emails, images)
- OCR text extraction from receipt images (PaddleOCR models)
- Earnings dashboard and quarterly quota tracking
- Profile settings and locum profile management
- Complete rural subsidy (WIP Doctor Stream FPS) calculations

---

## Platform Availability

### Available Now

| Platform | Status | Features |
|----------|--------|----------|
| **iOS** (iPhone/iPad) | Functional | Work tracking, receipt capture with OCR, earnings dashboard, quota tracking |

### In Development

| Platform | Status | Features |
|----------|--------|----------|
| **macOS** | Planned | Desktop power features, advanced reporting, bulk operations |

### Coming Later

| Platform | Notes |
|----------|-------|
| **Android** | Full feature parity with iOS |
| **Windows & Linux** | Cross-platform Python/PySide6 implementation |

---

## Roadmap

### Recently Completed
- ✅ Multiple receipt attachments (photos, PDFs, documents per receipt)
- ✅ iOS Share Extension for importing documents from other apps
- ✅ Multi-location assignments with session templates
- ✅ Automatic session splitting for long sessions (>5 hours)
- ✅ Enhanced location management with provider numbers and contact info
- ✅ Auto-dismiss date pickers and improved date range selection
- ✅ Session editing with automatic earnings calculation
- ✅ iOS app with full work tracking UI
- ✅ Receipt capture with camera integration and image cropping
- ✅ OCR engine with PaddleOCR models for receipt text extraction
- ✅ CloudKit sync infrastructure
- ✅ Storage layer with repositories

### In Progress
- LLM-powered receipt data extraction (merchant, amount, date, category from OCR text)
- macOS app interface

### Next
- Invoice generation and PDF export
- Calendar integration
- Quota progress notifications

### Future
- **Android app** — Bring LocumTracker to Android users
- **Windows & Linux apps** — Python/PySide6 cross-platform desktop application
- **Accounting Software Integration** — Export to MYOB, Xero, QuickBooks
- **Spreadsheet Export** — CSV/Excel for custom reporting
- **Multi-country Support** — Expand beyond Australia

---

## The Rural Subsidy Problem We Solve

The flexible incentive topup payments system is a complex nightmare and tracking compliance is timeconsuming:

- You need **21 sessions per quarter** across MMM3-7 locations 
- a session is a minimum of 3 hours
- maximum 2 sessions per day can be counted
- Different locations have different subsidy rates 
- Travel time rules are complex
- Missing the quota for a quarter means losing significant income that year

**LocumTracker tracks all of this automatically.** Enter your details and sessions, and we'll tell you exactly where you stand. |

---

## Open Source

LocumTracker is **open source** under the AGPL v3 License.


### Contributing

We welcome contributions! Whether you're a developer, a locum doctor with feature ideas, or someone who wants to help with documentation.

- **Bug Reports & Features**: [GitHub Issues](https://github.com/hherb/locumtracker/issues)
- **Questions**: [GitHub Discussions](https://github.com/hherb/locumtracker/discussions)
- **Code Contributions**: See [CLAUDE.md](CLAUDE.md) for development guidelines

---

## For Developers

### Quick Start

```bash
git clone https://github.com/hherb/locumtracker.git
cd locumtracker

# Run tests
swift test --package-path Packages/LocumTrackerCore

# Open in Xcode
open LocumTracker.xcodeproj
```

### Architecture

Clean, modular Swift packages:
- **LocumTrackerCore** — Pure business logic with 197 tests
- **LocumTrackerStorage** — SwiftData repositories + CloudKit sync
- **LocumTrackerOCR** — Receipt OCR with PaddleOCR models via ONNX Runtime
- **LocumTrackerUI** — Shared SwiftUI components

See [CLAUDE.md](CLAUDE.md) for detailed development documentation.

---

## Support

- **Repository**: https://github.com/hherb/locumtracker
- **Maintainer**: [@hherb](https://github.com/hherb)

---

*Built with care for the doctors who travel far to care for rural Australia.*
