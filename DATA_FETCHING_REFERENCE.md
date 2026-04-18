# VTOP Data Fetching - Android Reference Implementation Analysis

## Overview
After successful login, the Android app fetches 9 types of data from the VTOP portal. The data fetching is done through a WebView that performs POST requests to various endpoints. All data is parsed from HTML responses and stored locally in a Room database.

## Data Flow
1. User logs in successfully
2. Student profile data is fetched
3. Courses (from timetable) are fetched
4. Timetable data is fetched
5. Attendance data is fetched
6. Marks data is fetched
7. Exam schedule is fetched
8. Staff info (proctor, dean, HOD) is fetched
9. Spotlight/Announcements are fetched
10. Receipts/Payment info is fetched

---

## 1. STUDENT PROFILE DATA
**Function:** `getName()` and `getCreditsCGPA()`

### Endpoint 1: Student Profile
- **Method:** POST
- **URL:** `studentsRecord/StudentProfileAllView`
- **Data Parameters:**
  - `verifyMenu=true`
  - `authorizedID=<student_id>`
  - `_csrf=<csrf_token>`
  - `nocache=<timestamp>`

**Response Data Parsed:**
- Student Name (parsed from HTML table containing "student name")

**Data Structure:**
```
{
  "name": "JOHN DOE"
}
```

### Endpoint 2: Credits & CGPA
- **Method:** POST
- **URL:** `examinations/examGradeView/StudentGradeHistory`
- **Data Parameters:**
  - `verifyMenu=true`
  - `authorizedID=<student_id>`
  - `_csrf=<csrf_token>`
  - `nocache=<timestamp>`

**Response Data Parsed:**
- Total Credits Earned (from table with "credits" and "earned" headers)
- CGPA (from table with "cgpa" header)

**Data Structure:**
```
{
  "cgpa": 8.58,
  "total_credits": 64
}
```

**Stored in:** SharedPreferences
- Key: `"name"` - Value: Student Name
- Key: `"cgpa"` - Value: CGPA (Float)
- Key: `"totalCredits"` - Value: Total Credits (Float)

---

## 2. COURSES DATA
**Function:** `downloadCourses()`

### Endpoint: View Timetable (for course data)
- **Method:** POST
- **URL:** `processViewTimeTable`
- **Data Parameters:**
  - `_csrf=<csrf_token>`
  - `semesterSubId=<semester_id>`
  - `authorizedID=<student_id>`

**Response Data Parsed from Table (id="studentDetailsList"):**
- Course Code (format: CSE1001)
- Course Title
- Course Type (Theory, Lab, Project)
- Credits (extracted from "L T P J C" column)
- Slots (can be multiple, e.g., "L45", "L46")
- Venue
- Faculty Name

**Data Structure:**
```
{
  "courses": [
    {
      "code": "CSE1001",
      "title": "Problem Solving and Programming",
      "type": "lab|project|theory",
      "credits": 3,
      "slots": ["L45", "L46"],
      "venue": "AB2 - 015",
      "faculty": "JOHN DOE"
    },
    ...
  ]
}
```

**Database Model:** Course
```
- id: INTEGER (Primary Key)
- code: TEXT (Course Code)
- title: TEXT (Course Title)
- type: TEXT (lab|theory|project)
- credits: INTEGER
- venue: TEXT
- faculty: TEXT
```

**Related Model:** Slot
```
- id: INTEGER (Primary Key)
- slot: TEXT (Slot Name, e.g., "L45")
- courseId: INTEGER (Foreign Key to Course)
```

---

## 3. TIMETABLE DATA
**Function:** `downloadTimetable()`

### Endpoint: View Timetable
- **Method:** POST
- **URL:** `processViewTimeTable`
- **Data Parameters:**
  - `_csrf=<csrf_token>`
  - `semesterSubId=<semester_id>`
  - `authorizedID=<student_id>`

**Response Data Parsed from Table (id="timeTableStyle"):**
- Start Time (24-hour format, with auto-conversion from 12-hour if needed)
- End Time
- Day-wise slot assignments (Sunday to Saturday)

**Data Structure:**
```
{
  "theory": [
    {
      "start_time": "08:00",
      "end_time": "08:50",
      "sunday": null,
      "monday": "A1",
      "tuesday": "B1",
      "wednesday": null,
      "thursday": "D1",
      "friday": "E1",
      "saturday": "F1"
    },
    ...
  ],
  "lab": [
    {
      "start_time": "09:00",
      "end_time": "10:50",
      "sunday": null,
      ...
    },
    ...
  ]
}
```

**Database Model:** Timetable
```
- id: INTEGER (Primary Key)
- start_time: TEXT (HH:mm format)
- end_time: TEXT (HH:mm format)
- sunday: INTEGER (Foreign Key to Slot, nullable)
- monday: INTEGER (Foreign Key to Slot, nullable)
- tuesday: INTEGER (Foreign Key to Slot, nullable)
- wednesday: INTEGER (Foreign Key to Slot, nullable)
- thursday: INTEGER (Foreign Key to Slot, nullable)
- friday: INTEGER (Foreign Key to Slot, nullable)
- saturday: INTEGER (Foreign Key to Slot, nullable)
```

---

## 4. ATTENDANCE DATA
**Function:** `downloadAttendance()`

### Endpoint: Student Attendance
- **Method:** POST
- **URL:** `processViewStudentAttendance`
- **Data Parameters:**
  - `_csrf=<csrf_token>`
  - `semesterSubId=<semester_id>`
  - `authorizedID=<student_id>`

**Response Data Parsed from Table (id="getStudentDetails"):**
- Course Type (Theory Only, Lab Only, Project Only)
- Slot
- Classes Attended
- Total Classes
- Attendance Percentage

**Data Structure:**
```
{
  "attendance": [
    {
      "slot": "L45",
      "course_type": "Lab Only",
      "attended": 81,
      "total": 83,
      "percentage": 98
    },
    ...
  ]
}
```

**Database Model:** Attendance
```
- id: INTEGER (Primary Key)
- course_id: INTEGER (Foreign Key to Course)
- attended: INTEGER (Classes attended)
- total: INTEGER (Total classes)
- percentage: INTEGER (Percentage)
```

**Also Stored in SharedPreferences:**
- Key: `"overallAttendance"` - Value: Overall attendance percentage (calculated from all courses)

---

## 5. MARKS DATA
**Function:** `downloadMarks()`

### Endpoint: Student Marks View
- **Method:** POST
- **URL:** `examinations/doStudentMarkView`
- **Data Parameters:**
  - `semesterSubId=<semester_id>`
  - `authorizedID=<student_id>`
  - `_csrf=<csrf_token>`

**Response Data Parsed from Table (id="fixedTableContainer"):**
- Slot
- Course Type
- Assessment Title (CAT 1, CAT 2, Quiz, etc.)
- Score Obtained
- Maximum Score
- Weightage Score
- Maximum Weightage
- Average Score (optional)
- Status (Present/Absent)

**Data Structure:**
```
{
  "marks": [
    {
      "slot": "A1",
      "course_type": "Theory Only",
      "title": "CAT 1",
      "score": 26,
      "max_score": 30,
      "weightage": 13,
      "max_weightage": 15,
      "average": null,
      "status": "Present"
    },
    ...
  ]
}
```

**Database Model:** Mark
```
- id: INTEGER (Primary Key)
- course_id: INTEGER (Foreign Key to Course)
- title: TEXT (Assessment Title)
- score: REAL (Score obtained)
- max_score: REAL (Maximum score possible)
- weightage: REAL (Weightage score)
- max_weightage: REAL (Maximum weightage)
- average: REAL (Class average, nullable)
- status: TEXT (Present/Absent)
- is_read: BOOLEAN (Default: false)
- signature: INTEGER (Hash for tracking unread marks)
```

### Endpoint: Student Grades View
- **Method:** POST
- **URL:** `examinations/examGradeView/doStudentGradeView`
- **Data Parameters:**
  - `semesterSubId=<semester_id>`
  - `authorizedID=<student_id>`
  - `_csrf=<csrf_token>`

**Response Data Parsed:**
- Course Code
- Grade (S, A, B, C, D, F, etc.)
- Semester GPA

**Data Structure:**
```
{
  "grades": [
    {
      "course_code": "CSE1001",
      "grade": "S"
    },
    ...
  ],
  "gpa": 8.58
}
```

**Database Model:** CumulativeMark
```
- id: INTEGER (Primary Key)
- course_code: TEXT
- theory_total: REAL (Total weightage for theory)
- theory_max: REAL (Max weightage for theory)
- lab_total: REAL (Total weightage for lab)
- lab_max: REAL (Max weightage for lab)
- project_total: REAL (Total weightage for project)
- project_max: REAL (Max weightage for project)
- grand_total: REAL (Weighted average across all types)
- grand_max: REAL (Maximum weighted average possible)
- grade: TEXT (Final grade)
```

**Also Stored in SharedPreferences:**
- Key: `"gpa"` - Value: Semester GPA

---

## 6. EXAM SCHEDULE DATA
**Function:** `downloadExamSchedule()`

### Endpoint: Exam Schedule
- **Method:** POST
- **URL:** `examinations/doSearchExamScheduleForStudent`
- **Data Parameters:**
  - `semesterSubId=<semester_id>`
  - `authorizedID=<student_id>`
  - `_csrf=<csrf_token>`

**Response Data Parsed from Table:**
- Exam Title (FAT, CAT, ESE, etc.)
- Slot
- Exam Date (DD-MMM-YYYY format)
- Exam Time (Start - End, 12-hour format)
- Exam Venue
- Seat Location (e.g., R1C1)
- Seat Number

**Data Structure:**
```
{
  "FAT": [
    {
      "slot": "A1",
      "date": "01-JAN-2020",
      "start_time": "9:30 AM",
      "end_time": "12:30 PM",
      "venue": "DB-101",
      "seat_location": "R1C1",
      "seat_number": 1
    },
    ...
  ],
  "CAT": [...],
  ...
}
```

**Database Model:** Exam
```
- id: INTEGER (Primary Key)
- course_id: INTEGER (Foreign Key to Course)
- title: TEXT (Exam Title)
- start_time: LONG (Timestamp in milliseconds)
- end_time: LONG (Timestamp in milliseconds)
- venue: TEXT
- seat_location: TEXT
- seat_number: INTEGER
```

---

## 7. STAFF INFORMATION
**Function:** `downloadProctor()` and `downloadDeanHOD()`

### Endpoint 1: Proctor Details
- **Method:** POST
- **URL:** `proctor/viewProctorDetails`
- **Data Parameters:**
  - `verifyMenu=true`
  - `winImage=<image_data>`
  - `authorizedID=<student_id>`
  - `_csrf=<csrf_token>`
  - `nocache=<timestamp>`

**Response Data Parsed:**
- Key-Value pairs (e.g., "Proctor Name": "Dr. XYZ", "Mobile": "9876543210")

### Endpoint 2: Dean & HOD Details
- **Method:** POST
- **URL:** `hrms/viewHodDeanDetails`
- **Data Parameters:**
  - `verifyMenu=true`
  - `winImage=<image_data>`
  - `authorizedID=<student_id>`
  - `_csrf=<csrf_token>`
  - `nocache=<timestamp>`

**Response Data Parsed:**
- Dean information (heading-based)
- HOD information (heading-based)
- Each with Key-Value pairs

**Data Structure:**
```
{
  "proctor": [
    {
      "key": "Proctor Name",
      "value": "Dr. XYZ"
    },
    ...
  ],
  "dean": [
    {
      "key": "Dean Name",
      "value": "Prof. ABC"
    },
    ...
  ],
  "hod": [
    {
      "key": "HOD Name",
      "value": "Dr. DEF"
    },
    ...
  ]
}
```

**Database Model:** Staff
```
- id: INTEGER (Primary Key)
- type: TEXT (proctor|dean|hod)
- key: TEXT (Field name)
- value: TEXT (Field value)
```

---

## 8. SPOTLIGHT/ANNOUNCEMENTS
**Function:** `downloadSpotlight()`

### Endpoint: Home/Dashboard
- **Method:** POST
- **URL:** `home`
- **Data Parameters:**
  - `_csrf=<csrf_token>`
  - `authorizedID=<student_id>`
  - `x=` (empty)

**Response Data Parsed from Offcanvas Elements:**
- Category (heading from offcanvas-header)
- Announcement Text
- Link (onclick attribute or href)

**Data Structure:**
```
{
  "spotlight": [
    {
      "announcement": "Announcement text here",
      "category": "Category Name",
      "link": "Link URL or null"
    },
    ...
  ]
}
```

**Database Model:** Spotlight
```
- id: INTEGER (Primary Key)
- announcement: TEXT
- category: TEXT
- link: TEXT (nullable)
- is_read: BOOLEAN (Default: false)
- signature: INTEGER (Hash for tracking unread announcements)
```

---

## 9. PAYMENT RECEIPTS
**Function:** `downloadReceipts()`

### Endpoint: Payment Receipts
- **Method:** POST
- **URL:** `p2p/getReceiptsApplno`
- **Data Parameters:**
  - `verifyMenu=true`
  - `winImage=<image_data>`
  - `authorizedID=<student_id>`
  - `_csrf=<csrf_token>`
  - `nocache=<timestamp>`

**Response Data Parsed from Table:**
- Receipt Number
- Payment Amount
- Payment Date (DD-MMM-YYYY format)

**Data Structure:**
```
{
  "receipts": [
    {
      "number": 10067,
      "amount": 97500,
      "date": "14-AUG-2020"
    },
    ...
  ]
}
```

**Database Model:** Receipt
```
- number: INTEGER (Primary Key - Receipt Number)
- amount: REAL (Amount paid)
- date: LONG (Timestamp in milliseconds)
```

---

## AUTHENTICATION & SECURITY

### Login Process
1. **URL:** `POST /vtop/login`
2. **Data:**
   - username
   - password
   - captchaStr (or gResponse for reCAPTCHA)
3. **Authentication Method:** Captcha (Default or Google reCAPTCHA)
4. **Cookies:** Managed via CookieManager (WebView)
5. **User Agent:** Dynamically updated from server to bypass blocks

### Tokens
- **CSRF Token:** Extracted from HTML form (`input[name="_csrf"]`)
- **Authorized ID:** Extracted from hidden input (`#authorizedIDX`)
- **Image Data:** For certain endpoints, `winImage` parameter is required

### Session Management
- Credentials stored in encrypted SharedPreferences
- Username and password retrieved for each sync
- WebView cookies maintained across requests

---

## IMPORTANT IMPLEMENTATION NOTES

1. **HTML Parsing:** All data is extracted by parsing HTML responses using JavaScript running in WebView. Response is converted to JSON for Java/Kotlin processing.

2. **Pagination:** Most tables use index-based iteration with fixed row heights (heading count).

3. **Data Validation:**
   - Empty slots/cells are marked as null
   - Default values provided for numeric fields (0 or 0.0)
   - Time format conversion: 12-hour to 24-hour (assumes no classes before 08:00 or after 20:00)

4. **Database:** Room ORM with relationships via Foreign Keys

5. **Progress Tracking:**
   - maxProgress = 12 steps
   - Each data fetch updates progress notification
   - Used for UI feedback (download status)

6. **Error Handling:**
   - User Agent blocks: Detected from response containing "not authorized"
   - Invalid credentials: Detected from HTML content patterns
   - Account locked/Max attempts: Detected from HTML patterns

7. **Notifications:**
   - Timetable notifications set after downloading timetable
   - Exam notifications set after downloading exam schedule
   - Unread counts tracked via signatures (hashes)

---

## SEMESTER SELECTION

**Function:** `getSemesters()` → `setSemester(semester)`

### Getting Available Semesters
- **URL:** `academics/common/StudentTimeTableChn`
- **Response Parsed:** Dropdown with ID "semesterSubId" containing semester options
- **Stored in:** SharedPreferences (key: "semester")
- **Format:** "Fall Semester 2020-21" (name) and "CH2020211" (ID)

---

## SHARED PREFERENCES DATA

Keys stored after successful sync:
- `name` (String) - Student Name
- `cgpa` (Float) - CGPA
- `totalCredits` (Float) - Total Credits Earned
- `gpa` (String) - Semester GPA
- `overallAttendance` (Integer) - Overall attendance percentage
- `semester` (String) - Selected semester name
- `authorisedUserAgent` (String) - Current working user agent

---

## RESPONSE FORMAT NOTE

All API responses are HTML pages. JavaScript injected into WebView parses the HTML using jQuery and DOM APIs, then returns JSON to Java via evaluateJavascript(). Example:

```javascript
$.ajax({
  type: 'POST',
  url: 'endpoint/url',
  data: 'key1=val1&key2=val2',
  async: false,
  success: function(res) {
    var doc = new DOMParser().parseFromString(res, 'text/html');
    // Parse DOM and build JSON response
    var response = { /* parsed data */ };
  }
});
return response;
```

