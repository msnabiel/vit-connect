# iOS Implementation Notes - Based on Android Reference

## Key Architectural Differences to Consider

### 1. WebView HTML Parsing
**Android Approach:**
- Uses WebView's `evaluateJavascript()` to inject JavaScript
- JavaScript parses HTML using jQuery and DOM APIs
- Returns JSON string to native code

**iOS Approach Options:**
1. **WKWebView with JavaScript Execution:**
   - Similar to Android - inject JavaScript code
   - Use `evaluateJavaScript()` to get results
   - Parse returned JSON

2. **URLSession + HTML Parsing:**
   - Direct HTTP requests using URLSession
   - Parse HTML responses using SwiftSoup or similar
   - More lightweight than WebView

3. **WKWebView Hybrid:**
   - Use WKWebView for complex login flow (CAPTCHA)
   - Use URLSession for regular data fetching (with session cookies)

**Recommendation:** Hybrid approach - WKWebView for login/CAPTCHA, URLSession for data fetching after login

---

## Session Management

### Cookie Handling
- **Android:** WebView automatically manages cookies
- **iOS:** 
  - Store cookies from login response
  - Use `HTTPCookieStorage.shared` to maintain session
  - Include cookies in subsequent URLSession requests

### CSRF Token Management
- **Pattern:** Extract from form after each page load
- **Storage:** Keep in memory during session
- **Update:** Re-extract if token changes

### AuthorizedID (Session ID)
- **Pattern:** Extract from form after login
- **Persistence:** Store in memory during session
- **Usage:** Required for all data-fetching endpoints

---

## Data Models to Implement

### Core Models
```
Course {
  id: Int
  code: String
  title: String
  type: String (lab|theory|project)
  credits: Int
  venue: String
  faculty: String
  slots: [Slot]
}

Slot {
  id: Int
  slot: String (e.g., "L45")
  courseId: Int
}

Timetable {
  id: Int
  startTime: String (HH:mm)
  endTime: String (HH:mm)
  sunday: Int? (SlotId)
  monday: Int? (SlotId)
  tuesday: Int? (SlotId)
  wednesday: Int? (SlotId)
  thursday: Int? (SlotId)
  friday: Int? (SlotId)
  saturday: Int? (SlotId)
}

Attendance {
  id: Int
  courseId: Int
  attended: Int
  total: Int
  percentage: Int
}

Mark {
  id: Int
  courseId: Int
  title: String
  score: Double
  maxScore: Double?
  weightage: Double
  maxWeightage: Double?
  average: Double?
  status: String
  isRead: Bool = false
  signature: Int
}

CumulativeMark {
  id: Int
  courseCode: String
  theoryTotal: Double?
  theoryMax: Double?
  labTotal: Double?
  labMax: Double?
  projectTotal: Double?
  projectMax: Double?
  grandTotal: Double?
  grandMax: Double?
  grade: String?
}

Exam {
  id: Int
  courseId: Int
  title: String
  startTime: Int64? (Timestamp)
  endTime: Int64? (Timestamp)
  venue: String?
  seatLocation: String?
  seatNumber: Int?
}

Staff {
  id: Int
  type: String (proctor|dean|hod)
  key: String
  value: String
}

Spotlight {
  id: Int
  announcement: String
  category: String
  link: String?
  isRead: Bool = false
  signature: Int
}

Receipt {
  number: Int
  amount: Double
  date: Int64 (Timestamp)
}
```

### User Preferences Storage
```
UserDefaults Keys:
- "name": String - Student Name
- "cgpa": Double - CGPA
- "totalCredits": Double - Total Credits Earned
- "gpa": String - Semester GPA
- "overallAttendance": Int - Overall attendance percentage
- "semester": String - Selected semester name
- "semesterId": String - Selected semester ID
- "authorisedUserAgent": String - Current working user agent
```

---

## Data Fetching Flow

### Sequential Order (Must Follow)
1. **Student Profile Data** (Name, CGPA, Credits)
2. **Courses** (extracted from timetable HTML)
3. **Timetable** (day-wise schedule)
4. **Attendance** (per course)
5. **Marks** (assessment scores)
6. **Grades** (letter grades)
7. **Exam Schedule** (exam dates and venues)
8. **Proctor Info** (staff member)
9. **Dean & HOD Info** (staff members)
10. **Spotlight/Announcements**
11. **Payment Receipts**

### Important Constraints
- All numeric IDs must be unique across relationships
- Timestamp conversion: 12-hour to 24-hour format
- Date parsing: Always expect "DD-MMM-YYYY" format
- Null handling: Empty cells should be nil, not empty string

---

## Database Solution

### Options for iOS
1. **CoreData:**
   - Built-in, no external dependencies
   - Complex relationships possible
   - Good for offline-first apps

2. **Realm:**
   - Modern, easier syntax
   - Real-time notifications
   - Better for complex queries

3. **SwiftData (iOS 17+):**
   - Modern Apple framework
   - Simpler than CoreData
   - If iOS 17+ is acceptable

**Recommendation:** CoreData for broad compatibility, or Realm for better performance

### Relationships to Model
- Course -> Slots (1 to Many)
- Course -> Attendance (1 to Many)
- Course -> Marks (1 to Many)
- Course -> Exam (1 to Many)
- Timetable -> Slots (Many to Many through day fields)

---

## JSON Parsing Strategy

### For WKWebView Approach
```swift
// 1. Inject JavaScript
let jsCode = """
$.ajax({
  type: 'POST',
  url: 'endpoint',
  data: params,
  async: false,
  success: function(res) {
    var doc = new DOMParser().parseFromString(res, 'text/html');
    // Parse HTML and build JSON
  }
});
return JSON.stringify(response);
"""

webView.evaluateJavaScript(jsCode) { (result, error) in
  if let jsonString = result as? String {
    // Parse JSON
  }
}
```

### For URLSession Approach
```swift
// Use libraries like SwiftSoup
let doc = try SwiftSoup.parse(htmlResponse)
let tables = try doc.select("table")
// Parse DOM directly in Swift
```

---

## Error Handling

### Common Scenarios
1. **Network Errors:** Handle URLSession timeouts, no connection
2. **HTML Parse Errors:** Log and provide fallback empty data
3. **Session Expired:** Re-login required
4. **User Agent Blocked:** Fetch new user agent from server
5. **Invalid Credentials:** Force logout and re-login

### Error Detection Patterns
```
"not authorized" -> User Agent blocked
"invalid captcha" -> Wrong CAPTCHA entered
"invalid user name/login id/user id / password" -> Wrong credentials
"account is locked" -> Account locked
"maximum fail attempts reached" -> Too many login attempts
```

---

## Performance Considerations

### Caching Strategy
1. **Course List:** Cache until semester changes
2. **Timetable:** Cache until semester changes
3. **Attendance/Marks:** Refresh every sync
4. **Profile Data:** Cache until manual refresh
5. **Announcements:** Refresh every sync
6. **Exam Schedule:** Cache until dates pass

### Background Sync
- Schedule daily/weekly data refresh
- Use background task APIs (BackgroundTasks framework)
- Graceful handling if offline
- Store last sync timestamp

### Data Size Optimization
- Don't store full HTML responses
- Store only parsed JSON
- Use compression for local storage if needed
- Implement pagination for large lists

---

## UI Components to Build

### Home/Dashboard Screen
- Display student name, CGPA, total credits
- Overall attendance percentage
- Recent announcements/spotlight
- Quick access to other sections

### Courses Screen
- List of courses (Theory, Lab, Project tabs)
- Course code, title, faculty, venue
- Attendance percentage
- Unread marks count

### Timetable Screen
- Weekly view with day-wise slots
- Start/end times
- Course codes/titles
- Filter by course type

### Attendance Screen
- Per-course attendance
- Attended/Total/Percentage
- Overall attendance
- Highlight low attendance

### Marks/Grades Screen
- Courses list with grade
- Per-course marks/assessments
- Score, max score, weightage
- Cumulative marks calculation

### Exam Schedule Screen
- List of upcoming exams
- Date, time, venue
- Seat location and number
- Sort by date

### Announcements Screen
- List of announcements
- Category-wise grouping
- Mark as read/unread
- Links handling

### Profile Screen
- Student name, CGPA, credits, GPA
- Proctor, Dean, HOD information
- Payment receipts
- Last sync timestamp

---

## Security Considerations

### Data Protection
1. **Encrypted Storage:** Credentials in Keychain
2. **HTTPS Only:** All API calls must be HTTPS
3. **Certificate Pinning:** Consider for production
4. **No Logging:** Don't log credentials or sensitive data

### Authentication
1. **Captcha Handling:** User interaction required
2. **Session Timeout:** Re-login after inactivity
3. **Refresh Tokens:** Manage session lifecycle
4. **User Agent Rotation:** Update when blocked

---

## Testing Checklist

- [ ] Login with valid/invalid credentials
- [ ] Captcha solving (default and reCAPTCHA)
- [ ] Data fetching for all 9 data types
- [ ] Semester switching
- [ ] Network error handling
- [ ] Session expiry handling
- [ ] User agent blocking and refresh
- [ ] Offline mode (show cached data)
- [ ] Background sync
- [ ] UI responsiveness during sync

---

## Dependency Recommendations

```swift
// For HTML Parsing
SwiftSoup: "~> 2.4"

// For Keychain
KeychainAccess: "~> 4.2"

// For Networking (if not using URLSession)
Alamofire: "~> 5.8"

// For Local Database
Realm: "~> 10.44" // or CoreData

// For JSON Encoding/Decoding
// Built-in Codable (no dependency needed)

// For Date Parsing
// Built-in Date + ISO8601DateFormatter

// For UI (optional)
SnapKit: "~> 5.6" // For layout
Charts: "~> 5.0" // For data visualization
```

---

## Migration Path from Android

1. **Phases:**
   - Phase 1: Core data models and network layer
   - Phase 2: Database implementation
   - Phase 3: UI screens
   - Phase 4: Error handling and edge cases
   - Phase 5: Performance and testing

2. **Code Reuse:**
   - API endpoint URLs (identical)
   - Data structures (map directly to models)
   - JSON parsing logic (adapt from Android)
   - Error detection patterns (identical)

3. **Testing Data:**
   - Use same sample data as Android reference
   - Same expected API responses
   - Same error scenarios
