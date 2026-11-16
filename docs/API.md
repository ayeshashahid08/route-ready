# RouteReady API contract (core), v0.1

This file is the source of truth for backend and frontend. Frontend: build against
the examples here (copy them from docs/mock-data.json). Backend: responses must match.
To change anything, open a pull request on this file and tell the other two.

## Conventions

- Base path: /api. All bodies and responses are JSON. All field names are camelCase.
- Auth: send the header  Authorization: Bearer <token>  on every request except login.
- Dates are "YYYY-MM-DD". Times are "HH:MM" (24 hour). Weekdays are numbers 1=Mon ... 5=Fri.
- IDs are integers. Booleans are true/false. Phones look like "+923000000001".
- Shift codes: A, B, C, D are pickup shifts. Y, Z are dropoff shifts.
- Roles: a user has a list of roles, e.g. ["head","captain"]. A head who also drives has both.
  The frontend decides which screens to show from this list.
- Errors always look like:  { "error": "Human readable message", "code": "SOME_CODE" }

Error status codes:
- 400 VALIDATION_ERROR (bad or missing field), 400 SHIFT_NOT_RUNNING (shift does not run that weekday),
  400 DATE_IN_PAST
- 401 UNAUTHENTICATED (no or bad token), 401 INVALID_CREDENTIALS (login only)
- 403 FORBIDDEN (wrong role), 403 PASSWORD_CHANGE_REQUIRED
- 404 NOT_FOUND
- 409 PLAN_PUBLISHED (cannot regenerate or edit a published plan), 409 CONFLICT

First login rule: while mustChangePassword is true, every endpoint except
POST /auth/login, GET /me and POST /auth/change-password answers 403 PASSWORD_CHANGE_REQUIRED.
The backend does NOT block users who have not set a location. The frontend reads
locationSet from GET /me and sends them to the location screen.

## 1. Auth and profile

### POST /api/auth/login
Request:
    { "phone": "+923110000001", "password": "Dev12345" }
Response 200:
    { "token": "...", "mustChangePassword": false,
      "user": { "id": 7, "fullName": "Student 01", "roles": ["student"] } }
Error: 401 INVALID_CREDENTIALS.

### POST /api/auth/change-password
Request:  { "currentPassword": "Dev12345", "newPassword": "MyNewPass99" }
Response 200:  { "ok": true }
Rules: newPassword at least 8 characters and different from the old one.

### GET /api/me
Response 200: see "me" in mock-data.json. Fields: id, fullName, phone, email, roles,
mustChangePassword, locationSet, location (null until set), and for captains only
licenceExpiresInDays (number, or null if no documents yet). The captain app shows a
banner when licenceExpiresInDays is 45 or less.

### PUT /api/me/location
Request:
    { "lat": 31.487, "lng": 74.303, "mapsUrl": null, "addressNote": "Green gate, 2nd floor" }
mapsUrl and addressNote are optional. Response 200: { "ok": true }

### POST /api/location/parse-maps-link
Used when the user pastes a Google Maps link. Does not save anything.
Request:  { "url": "https://maps.app.goo.gl/..." }
Response 200: { "lat": 31.487, "lng": 74.303 }
Error: 400 VALIDATION_ERROR if no coordinates can be read from the link.

### PUT /api/me/captain-documents  (captain only)
Request:  { "cnic": "FAKE-CNIC-1", "licenceNo": "FAKE-LIC-1", "licenceExpiry": "2027-05-30" }
Response 200: { "verificationStatus": "pending" }
Saving always resets verification to pending.

### GET /api/me/captain-documents  (captain only)
Never returns full numbers, only the last 4 characters.
Response 200:
    { "cnicLast4": "N-1", "licenceNoLast4": "C-1", "licenceExpiry": "2027-05-30",
      "verificationStatus": "pending", "rejectionReason": null }

## 2. Shifts and student schedule

### GET /api/shifts
Response 200: array of { shiftCode, direction, campusTime, weekdays }.
For pickup shifts campusTime is the arrival time at campus. For dropoff shifts it is the leave time.

### GET /api/me/schedule  (student)
Response 200:
    { "termId": 1, "termName": "Fall 2026",
      "days": [ { "weekday": 1, "pickupShiftCode": "A", "dropoffShiftCode": "Y" } ] }
A weekday that is missing from days means no ride that day.

### PUT /api/me/schedule  (student)
Replaces the whole week. Send only the days with rides.
Request:  { "days": [ { "weekday": 1, "pickupShiftCode": "A", "dropoffShiftCode": null } ] }
Rules: each day needs at least one shift; a shift must have the right direction and run
on that weekday (D runs only on 2 and 4), else 400 SHIFT_NOT_RUNNING.
Changes apply to future plans only. Response 200: same shape as GET.

## 3. Rides and ride exceptions

### GET /api/me/rides?from=2026-11-23&to=2026-11-29  (student)
Maximum range 14 days. One item per ride (one direction on one date).
state is one of:
- "scheduled": no published plan covers it yet
- "assigned": a published plan has a stop for this student (assignment is filled in)
- "unplaced": a published plan exists but has no stop for this student
- "cancelled": the student cancelled it
assignment is null unless state is "assigned". Students only ever see published plans.

### POST /api/me/ride-exceptions  (student)
A new request for the same date and direction replaces the old one.
Request examples:
    { "rideDate": "2026-11-24", "direction": "pickup", "exceptionType": "cancel" }
    { "rideDate": "2026-11-24", "direction": "dropoff", "exceptionType": "change_shift", "newShiftCode": "Z" }
    { "rideDate": "2026-11-25", "direction": "dropoff", "exceptionType": "add", "newShiftCode": "Y" }
Rules: exceptionType is cancel, change_shift or add. cancel must NOT have newShiftCode;
the other two must have it, with the same direction as the request.
Response 201:
    { "exception": { "exceptionId": 5, "rideDate": "2026-11-24", "direction": "pickup",
      "exceptionType": "cancel", "newShiftCode": null, "status": "applied" } }
status is always "applied" in this version. The backend re-plans the affected shift.

## 4. Plans (head only)

### GET /api/captains/eligible?date=2026-11-23&shiftCode=A
Captains who can drive that shift (for the swap-captain dropdown).
Response 200: array of { id, fullName, phone, plate }.

### POST /api/plans/generate
Creates a draft plan, or rebuilds the existing draft (this discards manual edits).
Request:  { "date": "2026-11-23", "shiftCode": "A" }
Response 200: a plan object (below). Error 409 PLAN_PUBLISHED if already published.

### GET /api/plans?date=2026-11-23
Response 200: array of { planId, date, shiftCode, status, tripCount, riderCount, unplacedCount }.
Use it to show which shifts of the day already have a plan.

### GET /api/plans/:planId
Response 200: a plan object. Fields:
- planId, date, shiftCode, direction, campusTime, status ("draft" or "published"),
  generatedAt, publishedAt
- trips: array of { tripId, status, startTime, captain {id, fullName, phone},
  van {plate, capacity}, stops [ { stopId, order, plannedTime, status,
  student {id, fullName, phone} } ] }
- unplaced: array of { student {id, fullName, phone}, reason }
  reason is "no_location" or "not_enough_seats". An empty array means nobody is left out.

### POST /api/plans/:planId/move-student
Request:  { "studentId": 10, "toTripId": 12 }
Rules: target trip must have a free seat (else 409 CONFLICT). Draft plans only.
If studentId is currently unplaced, this places them. Response 200: the updated plan.

### POST /api/plans/:planId/swap-captain
Request:  { "tripId": 11, "newCaptainId": 3 }
newCaptainId must be in the eligible list. Draft plans only. Response 200: the updated plan.

### POST /api/plans/:planId/publish
Sends inbox messages to affected students and captains. Response 200: the updated plan.

## 5. Captain trips

### GET /api/me/trips?date=2026-11-23  (captain)
date defaults to today. Only published plans appear.
Response 200: array of trips. Each trip: tripId, planId, date, shiftCode, direction,
status, startTime, campusTime, van {plate}, stops [ { stopId, order, plannedTime, status,
student { id, fullName, phone, lat, lng, addressNote } } ].
lat and lng are the pickup point (pickup shifts) or dropoff point (dropoff shifts).
The Navigate button opens Google Maps with them.

### PATCH /api/trip-stops/:stopId  (captain)
Request:  { "status": "picked_up" }     (allowed: "picked_up", "no_show", "pending" to undo a mistake)
Response 200: { "stopId": 101, "status": "picked_up" }

### PATCH /api/trips/:tripId  (captain)
Request:  { "status": "in_progress" }   (allowed: "in_progress", "completed")
Response 200: { "tripId": 11, "status": "in_progress" }

## 6. Inbox (all roles)

The frontend polls GET /api/me/notifications every 30 seconds for the unread badge.

### GET /api/me/notifications?limit=50
Response 200:
    { "unreadCount": 1, "items": [ { "id": 1, "message": "...", "planId": 11,
      "isRead": false, "createdAt": "2026-11-22T18:00:00Z" } ] }

### POST /api/me/notifications/:id/read    Response 200: { "ok": true }
### POST /api/me/notifications/read-all    Response 200: { "ok": true }

## Not in this version (planned later)

Head admin endpoints (users, vans, document verification, leaves), pending-head approvals,
licence reminders, audit log, merge suggestions.
