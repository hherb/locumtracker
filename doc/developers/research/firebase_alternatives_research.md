# Open-Source, Self-Hosted Firebase Alternatives for Swift iOS/macOS Apps

This document researches and documents open-source, self-hosted alternatives to Firebase for Swift iOS/macOS applications that require real-time synchronization, file storage, user authentication, and offline-first architecture without paid APIs or subscriptions.

## Requirements Summary

- **Real-time synchronization** between devices
- **File storage** for receipts (PDFs, images)
- **User authentication**
- **Offline-first architecture**
- **No paid APIs or subscriptions**
- **AGPL-compatible licenses**
- **Self-hosted on personal servers**
- **Apple ecosystem integration**

---

## 1. Supabase

### Overview
Supabase is an open-source Firebase alternative built on PostgreSQL, providing real-time capabilities, authentication, storage, and more.

### License
Apache 2.0 (not AGPL-compatible, but permissive)

### Swift Integration
- **Official Swift SDK**: `supabase-swift`
- **Platform Support**: iOS 13.0+, macOS 10.15+
- **Latest Version**: v2.40.0 (Jan 2026)

### Features
✅ **Real-time sync**: WebSocket-based real-time subscriptions  
✅ **Authentication**: Email/password, OAuth, SSO, MFA  
✅ **File Storage**: Built-in storage service for PDFs/images  
✅ **Offline-first**: Requires custom implementation  
✅ **Self-hosted**: Docker deployment available  

### Implementation Example

```swift
import Supabase

// Initialize client
let client = SupabaseClient(
    supabaseURL: URL(string: "https://your-project.supabase.co")!,
    supabaseKey: "your-anon-key"
)

// Authentication
try await client.auth.signIn(email: email, password: password)

// Real-time subscription
let subscription = client.realtime.channel("receipts")
    .onPostgresChange("INSERT", schema: "public", table: "receipts") { data in
        // Handle new receipt
    }
    .subscribe()

// File upload
let imageData = receiptImage.jpegData(compressionQuality: 0.8)!
let uploadResult = try await client.storage.from("receipts")
    .upload(path: "receipt_\(UUID().uuidString).jpg", data: imageData)
```

### Pros
- Mature Swift SDK with active development
- PostgreSQL backend with powerful querying
- Comprehensive feature set matching Firebase
- Strong documentation and community support

### Cons
- Apache 2.0 license (not AGPL-compatible)
- Offline-first requires custom implementation
- Self-hosting can be complex (multiple services)

---

## 2. Appwrite

### Overview
Appwrite is an open-source Backend-as-a-Service platform with comprehensive features including databases, authentication, storage, and real-time capabilities.

### License
BSD 3-Clause (permissive, not AGPL-compatible)

### Swift Integration
- **Official Apple SDK**: Available for iOS, macOS, watchOS, tvOS
- **Latest Version**: 13.5.0 (Dec 2025)
- **Status**: Beta but actively maintained

### Features
✅ **Real-time sync**: WebSocket-based subscriptions  
✅ **Authentication**: Multiple providers including OAuth  
✅ **File Storage**: Built-in storage with size limits  
✅ **Offline-first**: Limited support, requires custom sync  
✅ **Self-hosted**: Docker Compose deployment  

### Implementation Example

```swift
import Appwrite

// Initialize client
let client = Client()
    .setEndpoint("https://your-server.com/v1")
    .setProject("your-project-id")
    .setKey("your-api-key")

// Authentication
let account = Account(client)
try await account.create(email: email, password: password)
let session = try await account.createEmailSession(email: email, password: password)

// Real-time subscription
let realtime = Realtime(client)
realtime.subscribe(channels: ["receipts"]) { response in
    // Handle real-time updates
}

// File upload
let storage = Storage(client)
let result = try await storage.createFile(
    bucketId: "receipts",
    fileId: ID.unique(),
    file: InputFile.fromData(imageData, filename: "receipt.jpg")
)
```

### Pros
- Official Swift SDK for Apple platforms
- All-in-one solution with integrated services
- Type-safe models with Swift
- Good documentation and examples

### Cons
- BSD license (not AGPL-compatible)
- Real-time features can be challenging to implement
- Smaller community compared to Supabase
- Offline capabilities limited

---

## 3. CloudKit + SwiftData (Apple Native)

### Overview
CloudKit is Apple's native cloud storage solution, integrated with SwiftData for local persistence and automatic synchronization.

### License
Apple's terms (free for development, paid for high usage)

### Swift Integration
- **Native Framework**: Built into iOS/macOS
- **SwiftData Integration**: Modern replacement for Core Data
- **Platform Support**: All Apple platforms

### Features
✅ **Real-time sync**: Automatic via CloudKit  
✅ **Authentication**: Apple ID integration  
✅ **File Storage**: CloudKit assets for PDFs/images  
✅ **Offline-first**: Native local-first architecture  
✅ **Self-hosted**: No - Apple's infrastructure  

### Implementation Example

```swift
import SwiftData
import CloudKit

// Model definition
@Model
final class Receipt {
    var id: UUID
    var title: String
    var amount: Double
    var createdAt: Date
    var imageData: Data?
    
    init(title: String, amount: Double) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.createdAt = Date()
    }
}

// Container configuration with CloudKit
let container = ModelContainer(for: Receipt.self, configurations: [
    .cloudKitApp(identifier: "iCloud.com.yourapp.receipts")
])

// Real-time sync monitoring
NotificationCenter.default.addObserver(
    forName: .NSPersistentStoreRemoteChange,
    object: container.persistentStore,
    queue: .main
) { _ in
    // Handle remote changes
}
```

### Pros
- Perfect Apple ecosystem integration
- True offline-first architecture
- No server maintenance required
- Seamless sync across Apple devices
- Type-safe with SwiftData

### Cons
- **Not self-hosted** - Apple's infrastructure only
- Apple ecosystem lock-in
- Complex CloudKit pricing for high usage
- Limited to Apple platforms

---

## 4. Parse Server

### Overview
Parse Server is an open-source backend that can be self-hosted, providing database, authentication, file storage, and real-time capabilities.

### License
MIT License (permissive, not AGPL-compatible)

### Swift Integration
- **Multiple Swift SDKs**: Parse-Swift, community versions
- **Platform Support**: iOS, macOS, watchOS, tvOS
- **Active Development**: Community maintained

### Features
✅ **Real-time sync**: LiveQuery subscriptions  
✅ **Authentication**: Multiple providers  
✅ **File Storage**: Built-in file handling  
✅ **Offline-first**: Requires custom implementation  
✅ **Self-hosted**: Node.js server deployment  

### Implementation Example

```swift
import ParseSwift

// Initialize Parse
ParseSwift.initialize(applicationId: "your-app-id", 
                      clientKey: "your-client-key",
                      serverURL: URL(string: "https://your-parse-server.com")!)

// Authentication
let user = User(username: email, email: email, password: password)
try await user.signup()

// Real-time subscription
let query = Receipt.query()
    .subscribe { event in
        switch event {
        case .created(let receipt):
            // Handle new receipt
        case .updated(let receipt):
            // Handle updated receipt
        case .deleted(let objectId):
            // Handle deleted receipt
        }
    }

// File upload
let file = ParseFile(name: "receipt.jpg", data: imageData)
try await file.save()
```

### Pros
- Mature platform with proven track record
- Self-hosted with full control
- Multiple Swift SDK options
- Flexible database options (PostgreSQL, MongoDB)
- Good documentation and examples

### Cons
- MIT license (not AGPL-compatible)
- Requires Node.js server setup
- Real-time features need LiveQuery server
- Offline sync requires custom implementation

---

## 5. PowerSync + PostgreSQL

### Overview
PowerSync is a sync engine that enables offline-first applications by keeping PostgreSQL databases in sync with on-device SQLite databases.

### License
Commercial (with free tier) - not fully open source

### Swift Integration
- **PowerSync Swift SDK**: Available
- **Latest Version**: 1.8.2 (Dec 2025)
- **Platform Support**: iOS, macOS

### Features
✅ **Real-time sync**: Automatic PostgreSQL ↔ SQLite sync  
✅ **Authentication**: Custom implementation required  
✅ **File Storage**: Separate solution needed  
✅ **Offline-first**: Core feature  
✅ **Self-hosted**: Self-hosted PowerSync available  

### Implementation Example

```swift
import PowerSync

// Database setup
let db = SQLiteDatabase()
let syncConnector = PostgresSyncConnector()

// PowerSync setup
let powersync = PowerSyncDatabase(
    db: db,
    syncConnector: syncConnector
)

// Sync rules
powersync.registerSyncRule("SELECT * FROM receipts WHERE user_id = $user_id")

// Real-time updates
powersync.onChange { [weak self] in
    DispatchQueue.main.async {
        // Update UI with synced data
    }
}

// Offline operations
try await powersync.execute("INSERT INTO receipts (title, amount) VALUES (?, ?)", 
                          ["Coffee", 4.50])
```

### Pros
- True offline-first architecture
- Automatic conflict resolution
- PostgreSQL backend power
- Reactive Swift API
- Good performance

### Cons
- Commercial license (not fully open source)
- Authentication and file storage require separate solutions
- Relatively new technology
- Limited community compared to established options

---

## 6. Custom Vapor + PostgreSQL Solution

### Overview
Building a custom backend using Vapor (Swift web framework) with PostgreSQL database and custom sync logic.

### License
MIT License (Vapor) + PostgreSQL License

### Swift Integration
- **Vapor Framework**: Swift server-side framework
- **Client SDK**: Custom Swift implementation
- **Full Control**: Complete customization

### Features
✅ **Real-time sync**: Custom WebSocket implementation  
✅ **Authentication**: Custom JWT-based auth  
✅ **File Storage**: MinIO S3-compatible storage  
✅ **Offline-first**: Custom sync logic  
✅ **Self-hosted**: Complete control  

### Implementation Example

```swift
// Server-side (Vapor)
import Vapor
import VaporPostgreSQL

struct Receipt: Content, Model {
    var id: UUID?
    var title: String
    var amount: Double
    var userId: UUID
    var createdAt: Date
}

// WebSocket for real-time sync
app.webSocket("sync") { req, ws in
    // Handle real-time updates
}

// Client-side
import Foundation

class ReceiptSyncService {
    private let baseURL: String
    private let localDB: SQLiteDatabase
    
    func syncReceipts() async throws {
        // Custom sync logic
    }
    
    func uploadReceipt(_ receipt: Receipt, imageData: Data) async throws {
        // Upload to MinIO S3-compatible storage
    }
}
```

### Pros
- Complete control over implementation
- AGPL-compatible possible with custom licensing
- Tailored to specific requirements
- Swift ecosystem on both client and server
- No vendor lock-in

### Cons
- Significant development effort
- Must implement all features from scratch
- Maintenance responsibility
- Complex real-time sync implementation

---

## File Storage Solutions

### MinIO (S3-Compatible)
- **License**: AGPL v3
- **Integration**: AWS SDK for Swift with custom endpoint
- **Features**: S3-compatible API, self-hosted, scalable

```swift
import AWSS3

let config = try S3Client.S3ClientConfiguration(
    region: "us-east-1",
    endpoint: "https://your-minio-server.com"
)
let client = S3Client(config: config)
```

### Nextcloud
- **License**: AGPL v3
- **Integration**: WebDAV or custom API
- **Features**: File sharing, sync, mobile apps

### Paperless-ngx
- **License**: GPL v3
- **Integration**: REST API
- **Features**: Document management, OCR, receipt processing

---

## Authentication Solutions

### Authentik
- **License**: GPL v3
- **Features**: OAuth2, SAML, LDAP integration
- **Self-hosted**: Docker deployment

### Keycloak
- **License**: Apache 2.0
- **Features**: OpenID Connect, SAML, user management
- **Self-hosted**: Quarkus-based deployment

### Custom JWT Implementation
- **License**: Custom (AGPL-compatible)
- **Features**: Complete control
- **Integration**: Vapor + Swift JWT

---

## Database Options

### PostgreSQL
- **License**: PostgreSQL License (permissive)
- **Features**: Powerful, reliable, extensible
- **AGPL-Compatible**: Can be used in AGPL projects

### SQLite
- **License**: Public Domain
- **Features**: Embedded, serverless, perfect for offline-first
- **Integration**: GRDB.swift for Swift

### DuckDB
- **License**: MIT License
- **Features**: Analytical database, embedded
- **Integration**: Native Swift API available

---

## Recommended Architecture

### Best Overall: Supabase + Custom Offline Layer
```
Swift App
├── Supabase Swift SDK
│   ├── Authentication
│   ├── Real-time subscriptions
│   └── File storage
├── Local SQLite (GRDB)
│   ├── Offline cache
│   ├── Sync queue
│   └── Conflict resolution
└── Custom sync logic
```

### Most Apple-Native: CloudKit + SwiftData
```
Swift App
├── SwiftData
│   ├── Local persistence
│   └── CloudKit sync
├── CloudKit
│   ├── Authentication (Apple ID)
│   ├── Real-time sync
│   └── File storage
└── Custom business logic
```

### Most Self-Hosted: Custom Vapor + PostgreSQL
```
Swift App
├── Custom client SDK
├── Local SQLite (offline-first)
└── WebSocket sync
     ↓
Vapor Server
├── PostgreSQL database
├── JWT authentication
├── MinIO file storage
└── WebSocket real-time
```

---

## Implementation Considerations

### Offline-First Architecture
1. **Local SQLite database** as primary data store
2. **Sync queue** for pending operations
3. **Conflict resolution** strategy (last-write-wins, CRDTs)
4. **Background sync** when network available

### Real-time Synchronization
1. **WebSocket connections** for instant updates
2. **Change data capture** from PostgreSQL
3. **Push notifications** for background updates
4. **Delta sync** to minimize bandwidth

### File Storage Strategy
1. **Local cache** of frequently accessed files
2. **Background upload** queue
3. **Compression** for images/PDFs
4. **Thumbnail generation** for quick previews

### Security Considerations
1. **End-to-end encryption** for sensitive data
2. **Certificate pinning** for API connections
3. **Keychain storage** for authentication tokens
4. **App Transport Security** enforcement

---

## Cost Analysis

### Self-Hosted Solution Costs
- **Server**: $5-20/month (VPS)
- **Database**: Included with server
- **Storage**: $0-10/month (depending on receipts volume)
- **Domain/SSL**: $10-15/year
- **Total**: ~$15-35/month

### CloudKit Costs
- **Free tier**: 1GB database, 250MB storage, 2500 API calls/hour
- **Paid tier**: Usage-based pricing
- **Potential cost**: $0-50/month depending on usage

### Commercial Solutions
- **Supabase Pro**: $25/month starter
- **PowerSync**: Custom pricing
- **Appwrite Cloud**: $15/month starter

---

## Final Recommendations

### For AGPL Compatibility
1. **Custom Vapor + PostgreSQL** solution
2. **MinIO** for file storage (AGPL v3)
3. **Authentik** for authentication (GPL v3)
4. **SQLite** for local database (public domain)

### For Fastest Development
1. **CloudKit + SwiftData** (if Apple ecosystem only)
2. **Supabase** (if AGPL compatibility not required)
3. **Parse Server** (mature alternative)

### For Complete Control
1. **Custom Vapor backend**
2. **PowerSync** for sync (if commercial acceptable)
3. **MinIO** for storage
4. **Custom JWT authentication**

### For Best Offline Experience
1. **CloudKit + SwiftData** (native)
2. **PowerSync + PostgreSQL** (cross-platform)
3. **Custom SQLite + sync logic** (most control)

---

## Conclusion

While no single solution perfectly matches all requirements (especially AGPL compatibility + comprehensive feature set), several viable options exist:

1. **CloudKit + SwiftData** offers the best offline-first experience but isn't self-hosted
2. **Supabase** provides the most Firebase-like experience but uses Apache license
3. **Custom Vapor solution** offers complete control and AGPL compatibility but requires significant development effort
4. **PowerSync** provides excellent offline-first sync but is commercial

The recommended approach depends on your specific priorities:
- **AGPL compatibility**: Custom Vapor stack
- **Development speed**: CloudKit or Supabase
- **Offline-first**: CloudKit or PowerSync
- **Self-hosting**: Parse Server or custom solution

Each option can be customized with additional open-source components to create a comprehensive solution that meets your specific requirements.