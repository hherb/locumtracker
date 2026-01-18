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
| **Location Intelligence** | Automatic MMM classification lookup for every workplace |
| **On-Call Support** | Track regular, on-call, and call-out sessions with appropriate rate calculations |
| **Assignment Management** | Organise work by contract with date ranges, rates, and locations |

### Rural Subsidy Compliance

Stop guessing — **know exactly where you stand** with your rural incentive payments.

- **Live Quota Dashboard** — See your MMM3-7 hours at a glance
- **Progress Alerts** — Get notified when you're falling behind on quarterly requirements
- **Travel Credits** — Automatically calculate eligible travel time subsidies
- **Vocational/Non-Vocational Rates** — Correct subsidy calculations based on your registration status

### Receipt & Expense Management

- **Camera Capture** (iOS) — Photograph receipts on the go
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
| Core Business Logic | **Complete** — 29 tests passing |
| Rural Subsidy Calculations | **Complete** — Full MMM support |
| Data Models | **Complete** — All entities defined |
| iOS App UI | **In Development** |
| macOS App UI | **In Development** |
| CloudKit Sync | **Scaffolded** |

**Ready to use:** The calculation engine is fully tested and production-ready. UI development is actively underway.

---

## Platform Availability

### Available Now (In Development)

| Platform | Status | Features |
|----------|--------|----------|
| **iOS** (iPhone/iPad) | Active Development | Mobile-first design, camera receipt capture, quick daily entry |
| **macOS** | Active Development | Desktop power features, advanced reporting, bulk operations |

### Coming Soon

| Platform | Timeline | Notes |
|----------|----------|-------|
| **Android** | Future Release | Full feature parity with iOS |
| **Windows & Linux** | Future Release | Cross-platform Python/PySide6 implementation |

---

## Roadmap

### Now
- iOS and macOS app interfaces
- CloudKit synchronisation
- Receipt capture workflow

### Next
- Invoice generation and PDF export
- Calendar integration
- Quota progress notifications
- **LLM-powered receipt scanning** — Automatically extract merchant, amount, date, and category from receipt photos

### Future
- **Android app** — Bring LocumTracker to Android users
- **Windows & Linux apps** — Python/PySide6 cross-platform desktop application
- **Accounting Software Integration** — Export to MYOB, Xero, QuickBooks
- **Spreadsheet Export** — CSV/Excel for custom reporting
- **Multi-country Support** — Expand beyond Australia

---

## The Rural Subsidy Problem We Solve

Australia's Modified Monash Model (MMM) provides financial incentives for doctors working in rural and remote areas. But tracking compliance is a nightmare:

- You need **21 sessions per quarter** across MMM3-7 locations (a session is 3-6 hours; a typical 10-hour shift counts as 2 sessions)
- Different locations have different subsidy rates ($15-$65/hour)
- Travel time rules are complex
- Missing the quota means losing significant income

**LocumTracker tracks all of this automatically.** Enter your sessions, and we'll tell you exactly where you stand.

| MMM Level | Location Type | Vocational Rate |
|-----------|---------------|-----------------|
| MMM3 | Large rural towns | $0/hr (qualifying hours) |
| MMM4 | Medium rural towns | $15/hr |
| MMM5 | Small rural towns | $25/hr |
| MMM6 | Remote communities | $45/hr |
| MMM7 | Very remote communities | $65/hr |

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
- **LocumTrackerCore** — Pure business logic (complete & tested)
- **LocumTrackerStorage** — SwiftData + CloudKit persistence
- **LocumTrackerUI** — Shared SwiftUI components

See [CLAUDE.md](CLAUDE.md) for detailed development documentation.

---

## Support

- **Repository**: https://github.com/hherb/locumtracker
- **Maintainer**: [@hherb](https://github.com/hherb)

---

*Built with care for the doctors who travel far to care for rural Australia.*
