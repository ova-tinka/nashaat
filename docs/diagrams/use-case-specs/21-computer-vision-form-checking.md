Use case Id: UC21    Computer Vision Form Checking

**Brief Description**
During an active workout session, the user can optionally enable the device camera. A computer vision model analyses the user's posture frame-by-frame in real time and provides visual feedback: green for correct form, orange with a tip for form that needs adjustment, and red with a pause signal for dangerous form. At the end of the session, a form score per exercise is included in the workout session summary.

**Primary actors**
Authenticated User, Camera / CV Service

**Preconditions:**
1. The user is authenticated and has an active workout session in progress.
2. The device has a front or rear camera and the user has granted camera permission.
3. The CV Service model is available (on-device or via API).
4. The exercise being performed has a reference pose model in the CV Service.

**Post-conditions:**
1. Real-time form feedback was displayed to the user throughout the session.
2. A per-exercise form score (0–100) is stored in the completed_exercises JSONB of the workout_log.
3. Camera permissions are released and video frames are not stored or transmitted.
4. The form score contributes to the session summary presented to the user.

**Main Success Scenario:**
<ToDo: List the included use cases. Add rows to the table below if needed />

| Actor Action | Subsystem Response |
|--------------|-----------------|
| 1. User starts a workout session and taps "Enable Form Check". | 2. Subsystem requests camera permission if not already granted; opens camera preview in a small overlay on the workout screen. |
| 3. User performs an exercise in view of the camera. | 4. CV Service analyses posture frames continuously; overlay shows green border and "Good form" text. |
| 5. CV Service detects a form deviation. | 6. Overlay changes to orange; a tip is displayed (e.g., "Keep your back straight"). |
| 7. CV Service detects a dangerous form. | 8. Overlay changes to red; workout session is paused; alert displays "Stop — risk of injury. Correct your form before continuing." |
| 9. User corrects form and resumes. | 10. CV Service confirms safe form; overlay returns to green; session resumes. |
| 11. User completes the session. | 12. Subsystem calculates a form score per exercise from frame-level scores, writes scores to completed_exercises JSONB, and displays session summary with form scores. |

**Alternative flows:**
2a. Camera permission denied: subsystem hides form-check UI and notifies user; session continues without CV.
4a. CV Service cannot identify exercise from camera angle: overlay shows grey with "Adjust camera angle for form feedback".
8a. User dismisses dangerous form alert without correcting: subsystem logs the event and displays a warning; session can be continued by explicit user action only.
11a. CV model unavailable mid-session: overlay disappears; session continues and form scores are omitted from the summary.

**Special Requirements:**
<ToDo: List the non-functional requirements that the use case must meet. E.g. CV inference under 200ms per frame; no video frames stored or transmitted; form score 0–100 per exercise; camera preview overlay must not obscure key workout controls; red-alert auto-pause cannot be dismissed without user acknowledgement; feature is opt-in per session; CV model covers weightlifting and calisthenics exercises only (future: sports drills). />
