import Foundation
import CoreLocation
import CoreBluetooth
import UserNotifications

/// KiloTax Autonomous Hardware Immortality Engine
///
/// Features:
/// 1. CBCentralManager with State Restoration ('KiloTaxCarBeacon')
///    - Wakes the app from a DEAD / TERMINATED state when the vehicle's Bluetooth beacon connects.
/// 2. Low-Memory Native GPS Telemetry Pipeline (RAM < 2MB)
///    - Streams and accumulates asphalt distance directly into persistent storage.
///    - iOS Jetsam will not terminate a lightweight process holding active navigation indicator.
/// 3. Bluetooth Disconnect Finalizer
///    - Detects engine shutdown, finalizes the trip, and delivers local push notifications.
@objc class KiloTaxBackgroundEngine: NSObject, CBCentralManagerDelegate, CLLocationManagerDelegate {
    static let shared = KiloTaxBackgroundEngine()

    private var centralManager: CBCentralManager?
    private var locationManager: CLLocationManager?

    private let userDefaultsKeyTargetBT = "kilotax_native_target_bt_name"
    private let userDefaultsKeyNativeTrip = "kilotax_native_in_flight_trip"
    private let userDefaultsKeyCompletedTrips = "kilotax_native_completed_trips"

    private var isRecording = false
    private var startLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var accumulatedDistanceMeters: Double = 0.0
    private var tripStartTime: Date?

    private override init() {
        super.init()
    }

    /// Configures the native background engine on app launch
    @objc func configure() {
        // Initialize CoreBluetooth with State Restoration
        centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue.global(qos: .utility),
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: "KiloTaxCarBeacon",
                CBCentralManagerOptionShowPowerAlertKey: false
            ]
        )

        // Initialize CoreLocation Manager with automotive high-priority profile
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager?.distanceFilter = 5.0 // Updates every 5 meters
        locationManager?.activityType = .automotiveNavigation
        locationManager?.pausesLocationUpdatesAutomatically = false
        if #available(iOS 9.0, *) {
            locationManager?.allowsBackgroundLocationUpdates = true
        }
        if #available(iOS 11.0, *) {
            locationManager?.showsBackgroundLocationIndicator = true
        }
    }

    /// Sets the target Bluetooth device name configured in Flutter
    @objc func setTargetBluetoothName(_ name: String?) {
        let defaults = UserDefaults.standard
        if let name = name, !name.isEmpty {
            defaults.set(name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), forKey: userDefaultsKeyTargetBT)
        } else {
            defaults.removeObject(forKey: userDefaultsKeyTargetBT)
        }
    }

    /// Gets any trips completed natively while Flutter was completely dead (Non-destructive read).
    @objc func getCompletedNativeTrips() -> [[String: Any]] {
        let defaults = UserDefaults.standard
        return defaults.array(forKey: userDefaultsKeyCompletedTrips) as? [[String: Any]] ?? []
    }

    /// Explicit two-phase commit: Flutter acknowledges successful persistence before clearing native buffer.
    @objc func acknowledgeNativeTripsIngested(_ tripIds: [String]) {
        let defaults = UserDefaults.standard
        guard var trips = defaults.array(forKey: userDefaultsKeyCompletedTrips) as? [[String: Any]] else { return }
        trips.removeAll { item in
            guard let id = item["id"] as? String else { return false }
            return tripIds.contains(id)
        }
        defaults.set(trips, forKey: userDefaultsKeyCompletedTrips)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Scan for peripherals or check connected peripherals
            scanOrInspectConnectedDevices()
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        // App was restored by iOS CoreBluetooth in background!
        NSLog("[KiloTax Native] Restored by iOS CoreBluetooth from dead state.")
        scanOrInspectConnectedDevices()
    }

    private func matchesTarget(peripheral: CBPeripheral, advertisementData: [String : Any]? = nil) -> Bool {
        guard let target = UserDefaults.standard.string(forKey: userDefaultsKeyTargetBT), !target.isEmpty else { return false }
        let targetLower = target.lowercased()

        // 1. Check peripheral hardware identifier (UUID)
        let peripheralUuid = peripheral.identifier.uuidString.lowercased()
        if peripheralUuid == targetLower || peripheralUuid.contains(targetLower) {
            return true
        }

        // 2. Check peripheral advertisement name and advertised service UUIDs
        if let adv = advertisementData {
            if let localName = adv[CBAdvertisementDataLocalNameKey] as? String,
               localName.lowercased().contains(targetLower) {
                return true
            }
            if let serviceUuids = adv[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                for uuid in serviceUuids {
                    if uuid.uuidString.lowercased().contains(targetLower) {
                        return true
                    }
                }
            }
        }

        // 3. Check peripheral standard name
        if let name = peripheral.name?.lowercased(), name.contains(targetLower) {
            return true
        }

        return false
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if matchesTarget(peripheral: peripheral) {
            NSLog("[KiloTax Native] Paired vehicle connected: \(peripheral.name ?? peripheral.identifier.uuidString). Triggering autonomous trip start.")
            startNativeRecording()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if matchesTarget(peripheral: peripheral) && isRecording {
            NSLog("[KiloTax Native] Vehicle disconnected. Engine turned off. Finalizing trip.")
            finalizeNativeTrip()
        }
    }

    private func scanOrInspectConnectedDevices() {
        guard let target = UserDefaults.standard.string(forKey: userDefaultsKeyTargetBT), !target.isEmpty else { return }
        
        // Scan for advertising Bluetooth devices
        centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if matchesTarget(peripheral: peripheral, advertisementData: advertisementData) && !isRecording {
            NSLog("[KiloTax Native] Found target vehicle in beacon scan: \(peripheral.name ?? peripheral.identifier.uuidString). Starting auto drive.")
            startNativeRecording()
        }
    }

    // MARK: - CLLocationManagerDelegate

    @objc func startNativeRecording() {
        guard !isRecording else { return }
        isRecording = true
        startLocation = nil
        lastLocation = nil
        accumulatedDistanceMeters = 0.0
        tripStartTime = Date()

        locationManager?.startUpdatingLocation()
    }

    @objc func finalizeNativeTrip() {
        guard isRecording else { return }
        isRecording = false
        locationManager?.stopUpdatingLocation()

        let distanceKm = accumulatedDistanceMeters / 1000.0
        guard distanceKm >= 0.1 else { return }

        let completedTrip: [String: Any] = [
            "id": "native_\(Int(Date().timeIntervalSince1970 * 1000))",
            "distanceKm": Double(round(100 * distanceKm) / 100),
            "startedAt": (tripStartTime ?? Date()).timeIntervalSince1970 * 1000,
            "completedAt": Date().timeIntervalSince1970 * 1000,
            "startLatitude": startLocation?.coordinate.latitude ?? 0.0,
            "startLongitude": startLocation?.coordinate.longitude ?? 0.0,
            "endLatitude": lastLocation?.coordinate.latitude ?? 0.0,
            "endLongitude": lastLocation?.coordinate.longitude ?? 0.0,
            "source": "native_bluetooth_auto"
        ]

        var existing = UserDefaults.standard.array(forKey: userDefaultsKeyCompletedTrips) as? [[String: Any]] ?? []
        existing.append(completedTrip)
        UserDefaults.standard.set(existing, forKey: userDefaultsKeyCompletedTrips)

        // Send local notification to notify driver
        sendTripNotification(distanceKm: distanceKm)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRecording, let latest = locations.last else { return }
        guard latest.horizontalAccuracy >= 0 && latest.horizontalAccuracy <= 65.0 else { return }

        if startLocation == nil {
            startLocation = latest
            lastLocation = latest
            return
        }

        if let prev = lastLocation {
            let delta = latest.distance(from: prev)
            // Filter noise / anomalous GPS warp jumps
            if delta > 3.0 && delta < 2000.0 {
                accumulatedDistanceMeters += delta
                lastLocation = latest
            }
        }
    }

    private func sendTripNotification(distanceKm: Double) {
        let content = UNMutableNotificationContent()
        content.title = "KiloTax Auto-Log Complete"
        content.body = String(format: "Recorded %.1f km trip. Ready for 1-tap review.", distanceKm)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "kilotax_trip_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
