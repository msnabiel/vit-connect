# VTOP API Endpoints - Quick Reference

## Base URL
All endpoints are relative to the VTOP portal base URL (e.g., https://vtop.vit.ac.in/)

## Authentication
- **Login Endpoint:** `POST /vtop/login`
- **CSRF Token:** Extracted from forms (`input[name="_csrf"]`)
- **Session ID:** Extracted from forms (`#authorizedIDX`)
- **Captcha Required:** Default or Google reCAPTCHA

---

## Data Fetching Endpoints (POST)

### 1. Student Profile & Credits
| Data | URL | Key Parameters | Response Format |
|------|-----|-----------------|-----------------|
| Name | `studentsRecord/StudentProfileAllView` | verifyMenu, authorizedID, _csrf | JSON with "name" |
| CGPA & Credits | `examinations/examGradeView/StudentGradeHistory` | verifyMenu, authorizedID, _csrf | JSON with "cgpa", "total_credits" |

### 2. Courses & Timetable
| Data | URL | Key Parameters | Response Format |
|------|-----|-----------------|-----------------|
| Courses | `processViewTimeTable` | semesterSubId, authorizedID, _csrf | JSON with "courses" array |
| Timetable | `processViewTimeTable` | semesterSubId, authorizedID, _csrf | JSON with "theory" and "lab" arrays |

### 3. Academic Performance
| Data | URL | Key Parameters | Response Format |
|------|-----|-----------------|-----------------|
| Attendance | `processViewStudentAttendance` | semesterSubId, authorizedID, _csrf | JSON with "attendance" array |
| Marks | `examinations/doStudentMarkView` | semesterSubId, authorizedID, _csrf | JSON with "marks" array |
| Grades | `examinations/examGradeView/doStudentGradeView` | semesterSubId, authorizedID, _csrf | JSON with "grades" array and "gpa" |
| Exam Schedule | `examinations/doSearchExamScheduleForStudent` | semesterSubId, authorizedID, _csrf | JSON with exam titles as keys |

### 4. Staff Information
| Data | URL | Key Parameters | Response Format |
|------|-----|-----------------|-----------------|
| Proctor | `proctor/viewProctorDetails` | winImage, authorizedID, _csrf, verifyMenu | JSON with "proctor" array |
| Dean & HOD | `hrms/viewHodDeanDetails` | winImage, authorizedID, _csrf, verifyMenu | JSON with "dean" and "hod" arrays |

### 5. Announcements & Payments
| Data | URL | Key Parameters | Response Format |
|------|-----|-----------------|-----------------|
| Spotlight/News | `home` | authorizedID, _csrf, x | JSON with "spotlight" array |
| Receipts | `p2p/getReceiptsApplno` | winImage, authorizedID, _csrf, verifyMenu | JSON with "receipts" array |

### 6. Semesters
| Data | URL | Key Parameters | Response Format |
|------|-----|-----------------|-----------------|
| Available Semesters | `academics/common/StudentTimeTableChn` | verifyMenu, authorizedID, _csrf | JSON with "semesters" array |

---

## Data Structure Examples

### Course Object
```json
{
  "code": "CSE1001",
  "title": "Problem Solving and Programming",
  "type": "lab|theory|project",
  "credits": 3,
  "slots": ["L45", "L46"],
  "venue": "AB2 - 015",
  "faculty": "JOHN DOE"
}
```

### Mark Object
```json
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
}
```

### Attendance Object
```json
{
  "slot": "L45",
  "course_type": "Lab Only",
  "attended": 81,
  "total": 83,
  "percentage": 98
}
```

### Exam Object
```json
{
  "slot": "A1",
  "date": "01-JAN-2020",
  "start_time": "9:30 AM",
  "end_time": "12:30 PM",
  "venue": "DB-101",
  "seat_location": "R1C1",
  "seat_number": 1
}
```

### Timetable Slot Object
```json
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
}
```

---

## Common Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `authorizedID` | String | Hidden input value from form (#authorizedIDX) |
| `_csrf` | String | CSRF token from form |
| `semesterSubId` | String | Semester ID (e.g., "CH2020211") |
| `verifyMenu` | String | "true" - for menu verification |
| `winImage` | String | Image data parameter (exact format unknown) |
| `nocache` | String | Timestamp to prevent caching |
| `x` | String | Empty parameter (used in home endpoint) |

---

## Data Parsing Strategy

All endpoints return **HTML content** (not JSON directly).

### Parsing Approach:
1. Inject JavaScript into WebView
2. Use jQuery for AJAX POST request
3. Parse HTML response using DOMParser
4. Extract table data or form values
5. Convert to JSON object
6. Return JSON string to Java code via evaluateJavascript()

### Example JavaScript Pattern:
```javascript
$.ajax({
  type: 'POST',
  url: 'endpoint/url',
  data: 'param1=val1&param2=val2',
  async: false,
  success: function(res) {
    var doc = new DOMParser().parseFromString(res, 'text/html');
    var response = {};
    // Parse DOM elements and populate response
    return response;
  }
});
```

---

## Error Handling Patterns

### Detected Errors:
| Error | Detection Method |
|-------|------------------|
| Unauthorized User Agent | Response contains "not authorized" |
| Invalid Captcha | HTML contains "invalid captcha" (case-insensitive) |
| Invalid Credentials | HTML contains "invalid user name/login id/user id / password" |
| Account Locked | HTML contains "account is locked" |
| Max Login Attempts | HTML contains "maximum fail attempts reached" |

---

## Session Management

1. **Login:** 
   - POST to `/vtop/login` with username, password, captcha
   - Cookies automatically managed by WebView

2. **Refresh Session:** 
   - Credentials stored in encrypted SharedPreferences
   - Re-login performed on each data sync

3. **User Agent Updates:**
   - Fetched from server endpoint when blocked
   - Stored in SharedPreferences for next sync

---

## Important Notes

1. All responses are HTML, not JSON
2. CSRF token and AuthorizedID must be extracted before each request
3. Semester ID must be set before requesting academic data
4. Some endpoints require `winImage` parameter (exact usage unclear from code)
5. Times may be in 12-hour or 24-hour format (auto-conversion in client)
6. Date format is typically DD-MMM-YYYY (e.g., "01-JAN-2020")
7. All numeric values should handle null/empty cases
8. Links in Spotlight can be onclick handlers or href attributes
