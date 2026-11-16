# Finish post-trip and weekly review

Use existing types and screens. No new dependency or background service.

- [x] Automatic detector produces unclassified trips with no invented purpose.
- [x] Add current-week filtering while keeping all pending records and full-year export.
- [x] Persist one in-app weekly reminder per vehicle and week for unresolved completed-week records. Evaluate on app open and resume. Notification opens the matching vehicle review.
- [x] Test detector, week boundaries, reminder persistence, notification navigation, and existing correction flow. Run focused analysis.

The reminder is in-app. It does not schedule an operating-system push while the app is closed.
