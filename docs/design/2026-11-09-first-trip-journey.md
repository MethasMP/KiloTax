# First trip journey

Welcome → vehicle setup → Home → choose how to record → review and save a trip.

- Welcome has one start action and a returning-user sign-in link. Existing local vehicles go directly to Home.
- Onboarding saves the vehicle without Bluetooth setup or an account gate. Number plate is optional; invalid nonempty input is still validated. Tax method remains explicit because it determines the records and entry screens required; the copy no longer promises interchangeable evidence.
- Home provides GPS and past-trip entry. Manual entry does not require location. Automatic setup is a separate action, also accessible from Settings for both tax methods.
- Automatic setup explains foreground access, background access, and car connection separately. It does not request permissions on screen entry. Background access uses an explicit app-settings action after foreground access. Status refreshes when returning from settings.
- A car connection alone never displays “armed”. Home reflects missing background access or the car connection, without guaranteeing background operation.
- An optional account invitation appears after records exist and can be dismissed for the current Home session. Authentication uses the existing account flow and does not equate successful sign-in with verified backup completion.

## Validation

Widget tests cover welcome routing, omission of Bluetooth during initial setup, GPS/manual choices, incomplete permissions with a paired car, and background permission gating. Existing vehicle setup tests cover Bluetooth, tax method selection, and manual entry.

`tool/design_audit/journey_capture_test.dart` renders welcome, first-trip guidance and tracking setup at 390×844, and checks 320×640 with 200% text. These renders are not native-device tests.

Before release, verify location permission prompts, settings return, location services disabled, foreground-only access, car connection, and background trip detection on physical iOS and Android devices. Detection depends on OS capabilities and configuration beyond permission grants.
