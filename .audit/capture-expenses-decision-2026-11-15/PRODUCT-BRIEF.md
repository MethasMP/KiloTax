# Capture and trip controls decision

Decision: GO for a dedicated receipt scanner action; retain manual trip controls in Trips and the Home tracking status. Implemented in the working checkout: dedicated Scan, relocated manual trip controls, real-state processing motion and editable receipt review. See .audit/receipt-flow-2026-11-15 for test evidence and limitations.

User: Australian sole trader recording vehicle travel and receipts. Auto tracking handles routine drives; a receipt still needs an explicit capture action.
Pain: Current Capture > Scan a receipt > Receipt Scanner > Open camera scanner repeats intent and makes users search through unrelated trip actions.
Primary journey: Scan receipt > native camera scanner > review extracted fields > save. Gallery and manual expense entry remain available from scanner fallback and Expenses. Cancel returns to the source. Show camera permission recovery when required.
Navigation: Logbook supports direct Scan action. Do not retain the identical Capture label/icon with a different default action for CPK. For CPK, make the decision explicit: retain receipt capture as evidence-only with existing vault policy, or use a clearly labelled Add trip action. Never turn a CPK receipt into an extra deduction merely by changing navigation.
Trips: Auto detection remains the normal tracking mode. Offer Start manually and Add past trip as distinct secondary actions. Show an active trip with Open current drive / End & review. No second active recording when auto detection and manual recording overlap. Opening scanner must not end a drive.
Home: Tracking status distinguishes ready, missing permissions, waiting for vehicle, and active trip. Manual start remains reachable if auto is unavailable or deliberately disabled.
Current implementation evidence: HomeTelemetryCapsule evaluates background permission and configured/connected Bluetooth for its readiness text. AutonomousTripDetector also supports movement detection without a car Bluetooth signal. TripLiveTrackingScreen starts a live drive after foreground permission/setup and resumes an existing live drive. startLiveDrive guards against a second active start, but this alone does not prove deduplication across automatic finalization and manual saving; audit session ownership before implementation.
Anti-goal: Do not remove manual start/stop; do not redesign tax calculations or introduce a new tracking engine in a navigation-only change.
Validation: Direct scanner launch happens once; cancel and permission denial recover; gallery/manual entry remain available; existing auto drive resumes without a second session; manual/auto transitions create one saved trip; test both CPK and logbook policies.
Success measures: taps to scanner, camera-launch failures, receipt completion rate, manual fallback usage, and duplicate-trip rate. No measured baseline claimed.

Official sources checked 2026-11-15:
- https://www.driversnote.com/tracking — automatic, start/stop GPS, and manually added trips.
- https://www.driversnote.com/pricing — confirms automatic and manual start/stop capabilities.
- https://help.everlance.com/hc/en-us/articles/45326341161115-How-to-Start-and-Stop-Tracker-Manually — manual tracker flow.
- https://help.everlance.com/hc/en-us/articles/45327091514139-Welcome-Series-Part-2-How-to-Capture-Add-and-Classify-Trips — distinguishes auto detection, manual recording, and manual entry.
- https://support.mileiq.com/hc/en-us/articles/204465475-How-do-I-start-to-track-my-first-drive — automatic-first flow without needing start/stop.
- https://support.mileiq.com/hc/en-us/articles/203798889-How-to-Classify-Drives — confirms automatic capture then classification.

Recommendation is specific to DriveLog; competitor capability evidence does not establish their Capture-button behavior. Product-lens skill used for the journey and go/no-go decision.
