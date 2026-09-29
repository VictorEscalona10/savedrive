# PROJECT_CONTEXT: SafeDrive
# TYPE: Mobile Application
# STACK: Flutter (Dart), Supabase (Backend/Auth), Google ML Kit (Computer Vision)

## 1. CORE_CONCEPT
SafeDrive is an active driver-monitoring app that uses the smartphone's front camera and GPS telemetrics to prevent accidents caused by drowsiness or distraction. It features automated start, intelligent alarm silencing based on traffic context, and dynamic facial morphology calibration.

## 2. TECH_STACK & DEPENDENCIES
- Frontend: Flutter (UI, Logic)
- Backend: Supabase (Auth via Google Sign-In, Database)
- Vision: `camera`, `google_mlkit_face_detection` (eyeOpenProbability, headEulerAngleY)
- Telemetry: `geolocator` (speed, location)
- Mapping: `mapbox_maps_flutter` (Dark mode UI) OR `flutter_map` + OSM
- Background Tasks: `flutter_background_service`
- Storage & Audio: `shared_preferences`, `audioplayers`
- Emergency: `background_sms` (fallback without internet)

## 3. UI/UX_ARCHITECTURE
- Dashboard: "Free-drive" hybrid map. Shows real-time location and speed over a dark-themed map. No turn-by-turn routing required.
- Hardware Setup: Phone mounted on dashboard/console vent, tilted toward the driver. Relies on the front camera's wide-angle lens.
- Settings: Minimalist. User only configures emergency contacts and alarm tolerance times. NO manual facial sensitivity settings.

## 4. CONTEXT_AWARE_AUTOMATION (TELEMETRY LOGIC)
- **Auto-Start**: Background service reads GPS. IF speed > 20 km/h AND monitoring is OFF -> Auto-trigger camera and Ghost Calibration.
- **Traffic Light Silencer**: IF speed < 10 km/h (stopped/heavy traffic) -> Pause/Relax alarm strictness. Allows driver to look around freely without triggering false positives.

## 5. GHOST_CALIBRATION_LOGIC (ANTI-BIAS SYSTEM)
Solves facial morphology bias (e.g., naturally narrow eyes) and phone mount angles without manual user setup.
- **Phase 1 (Collection)**: Upon Auto-Start, app silently collects face data in the background. Alarms are MUTED.
- **Phase 2 (Posture Filter)**: Only accepts frames where `headEulerAngleY` is between -15° and +15° (ensuring driver is looking reasonably forward).
- **Phase 3 (Quota)**: Stops collecting once it hits exactly 50 *valid* frames.
- **Phase 4 (Baseline)**: Averages the 50 frames to establish the user's "Relative Zero" for eyes and head angle for that specific trip.
- **Execution**: Alarms trigger based on relative % drops from the Baseline, NOT absolute ML Kit values.
- **Fallback**: IF 30 seconds pass at > 20km/h WITHOUT collecting 50 valid frames -> Trigger TTS/Audio: "Please adjust phone to start SafeDrive".

## 6. ESCALATION_PROTOCOL
1. Buffer Window: Brief grace period (e.g., 3 seconds) for checking mirrors. If attention returns, timer resets silently.
2. Local Alarm: Visual and loud audio warnings if distraction exceeds buffer.
3. Emergency Protocol: If alarm persists beyond critical limit -> Fetch emergency contact from Supabase/Local -> Send automated SMS with GPS location.