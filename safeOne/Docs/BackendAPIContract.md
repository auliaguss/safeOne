# SafeOne Backend API Contract

Set `BACKEND_BASE_URL` in `Info.plist` or `UserDefaults` to enable backend calls. Without it, the app uses local fallback data.

## Authentication

- `POST /auth/apple`
  - Body: `{ "identityToken": "...", "authorizationCode": "...", "fullName": "...", "role": "elder|children" }`
  - Response: `AuthSession`
- `POST /auth/logout`
  - Header: `Authorization: Bearer <accessToken>`
  - Response: empty `2xx`

Roles are `elder` and `children`.

## Reminders

- `GET /reminders?date=<iso>&startDate=<iso>&endDate=<iso>&userId=<uuid>`
  - Filters are optional. Dashboard uses `date=today` and children also pass selected elder `userId`.
  - Response: `[Reminder]`
- `POST /reminders`
  - Body: `Reminder`
  - Response: saved `Reminder`
- `PUT /reminders/{id}`
  - Body: `Reminder`
  - Response: saved `Reminder`
- `DELETE /reminders`
  - Body: `{ "ids": ["uuid"] }`
  - Response: empty `2xx`

## Profile

- `GET /users/me`
  - Response: `UserProfile`
- `PUT /users/me`
  - Body: `UserProfile`
  - Response: saved `UserProfile`
- `GET /users/me/devices`
  - Response: `[ConnectedDevice]`

`UserProfile.notificationPreferences` controls reminder sound, haptics, and text-to-speech.

## Real-time Calls

Use WebRTC for audio/video media and a backend WebSocket for signaling:

- `POST /calls`
  - Creates a call room and returns `callId`.
- `GET /calls/{id}`
  - Returns room status and participants.
- `WS /calls/{id}/signal`
  - Authenticated WebSocket used to relay `join`, `offer`, `answer`, `iceCandidate`, and `leave` events.

The backend should relay signaling events only to participants in the same call room. The client-side template is `CallSignalingService`; media capture and peer connection setup should be added with WebRTC once the backend signaling route exists.

