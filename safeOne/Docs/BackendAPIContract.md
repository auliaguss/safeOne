# SafeOne Backend API Contract

Set `BACKEND_BASE_URL` in `Info.plist` or `UserDefaults` to enable backend calls. Without it, the app uses local fallback data.

## Authentication

The app's native Sign in with Apple flow uses Supabase directly through `auth.signInWithIdToken`.
Keep these IDs aligned:

- Xcode bundle identifier / Apple App ID: `com.superAulia.safeOne`
- Apple Developer Team ID: `V7RKC8F8WN`
- Supabase project URL: `https://qcivbqymwarzhavvkcjo.supabase.co`
- Supabase Auth > Sign In / Providers > Apple > Client IDs must include `com.superAulia.safeOne`

If Supabase returns `Unacceptable audience in id_token: [com.superAulia.safeOne]`, the Apple provider is enabled but the Client IDs list does not include the native iOS bundle ID above. A web Services ID is only needed for browser OAuth; this iOS app sends Apple's native identity token to Supabase.

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

## Pairing

- `GET /pairings`
  - Returns pairing records linked to the signed-in caregiver or elder.
- `POST /pairings`
  - Caregiver creates or refreshes a pairing code.
  - Response: `PairingRecord`
- `POST /pairings/join`
  - Body: `{ "code": "ABC123" }`
  - Elder joins a caregiver pairing and the backend creates the caregiver assignment.

## Emergency Contacts

- `GET /contacts/emergency`
  - Response: `[EmergencyContact]`
- `PUT /contacts/emergency`
  - Body: `[EmergencyContact]`
  - Response: saved contacts

## Real-time Calls

Use WebRTC for audio/video media and a backend WebSocket for signaling:

- `POST /calls`
  - Creates a call room and returns `callId`.
- `GET /calls/{id}`
  - Returns room status and participants.
- `WS /calls/{id}/signal`
  - Authenticated WebSocket used to relay `join`, `offer`, `answer`, `iceCandidate`, and `leave` events.

The backend should relay signaling events only to participants in the same call room. The client-side template is `CallSignalingService`; media capture and peer connection setup should be added with WebRTC once the backend signaling route exists.
