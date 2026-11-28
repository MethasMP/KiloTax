import Foundation
import CoreLocation
import CoreBluetooth
import CoreMotion
import AVFoundation
import UserNotifications

@objc class KiloClaimBackgroundEngine: NSObject, CBCentralManagerDelegate, CLLocationManagerDelegate {
    static let shared = KiloClaimBackgroundEngine()

    private enum PowerState {
        case deepSleep
        case armed
        case activeDriving
        case disconnectGrace
    }

    private var centralManager: CBCentralManager?
    private var locationManager: CLLocationManager?
    private var motionManager: CMMotionActivityManager?

    private let userDefaultsKeyTargetBT = "kiloclaim_native_target_bt_name"
    private let userDefaultsKeyTargetBTUuid = "kiloclaim_native_target_bt_uuid"
    private let userDefaultsKeyCompletedTrips = "kiloclaim_native_completed_trips"
    private let parkedRegionIdentifier = "KiloClaimParkedGeofence"

    private let parkedGeofenceRadiusMeters: CLLocationDistance = 200.0
    private let disconnectGraceSeconds: TimeInterval = 180.0
    private let stationaryAutoStopSeconds: TimeInterval = 240.0

    private var powerState: PowerState = .deepSleep
    private var disconnectGraceWorkItem: DispatchWorkItem?
    private var isAutomotiveConfirmed = false
    private var isTargetBluetoothConnected = false
    private var tripTriggeredByBluetooth = false

    private var startLocation: CLLocation?
    private var lastLocation: CLLocation?
    private var parkedAnchorLocation: CLLocation?
    private var stationarySince: Date?
    private var accumulatedDistanceMeters: Double = 0.0
    private var tripStartTime: Date?

    private override init() {
        super.init()
    }

    @objc func configure() {
        centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue.global(qos: .utility),
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: "KiloClaimCarBeacon",
                CBCentralManagerOptionShowPowerAlertKey: false
            ]
        )

        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager?.distanceFilter = 10.0
        locationManager?.activityType = .automotiveNavigation
        locationManager?.pausesLocationUpdatesAutomatically = true
        if #available(iOS 9.0, *) {
            locationManager?.allowsBackgroundLocationUpdates = true
        }
        if #available(iOS 11.0, *) {
            locationManager?.showsBackgroundLocationIndicator = true
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        if CMMotionActivityManager.isActivityAvailable() {
            motionManager = CMMotionActivityManager()
            let motionQueue = OperationQueue()
            motionQueue.qualityOfService = .utility
            motionManager?.startActivityUpdates(to: motionQueue) { [weak self] activity in
                guard let self = self, let activity = activity else { return }
                DispatchQueue.main.async {
                    self.handleMotionActivity(activity)
                }
            }
        }

        // Low-power SLC wake-up ensures iOS relaunches this engine even after termination.
        locationManager?.startMonitoringSignificantLocationChanges()
        if let knownLocation = locationManager?.location {
            plantParkedGeofence(at: knownLocation)
        }

        checkActiveAudioRoute()
    }

    @objc func setTargetBluetoothTarget(name: String?, uuid: String?) {
        let defaults = UserDefaults.standard
        if let name = name, !name.isEmpty {
            defaults.set(name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), forKey: userDefaultsKeyTargetBT)
        } else {
            defaults.removeObject(forKey: userDefaultsKeyTargetBT)
        }
        if let uuid = uuid, !uuid.isEmpty {
            defaults.set(uuid.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), forKey: userDefaultsKeyTargetBTUuid)
        } else {
            defaults.removeObject(forKey: userDefaultsKeyTargetBTUuid)
        }
        checkActiveAudioRoute()
    }

    @objc func setTargetBluetoothName(_ name: String?) {
        setTargetBluetoothTarget(name: name, uuid: nil)
    }

    @objc func getCompletedNativeTrips() -> [[String: Any]] {
        let defaults = UserDefaults.standard
        return defaults.array(forKey: userDefaultsKeyCompletedTrips) as? [[String: Any]] ?? []
    }

    @objc func acknowledgeNativeTripsIngested(_ tripIds: [String]) {
        let defaults = UserDefaults.standard
        guard var trips = defaults.array(forKey: userDefaultsKeyCompletedTrips) as? [[String: Any]] else { return }
        trips.removeAll { item in
            guard let id = item["id"] as? String else { return false }
            return tripIds.contains(id)
        }
        defaults.set(trips, forKey: userDefaultsKeyCompletedTrips)
    }

    // MARK: - CoreMotion Dual-Trigger Gate

    private func handleMotionActivity(_ activity: CMMotionActivity) {
        if activity.automotive && activity.confidence != .low {
            isAutomotiveConfirmed = true
            cancelDisconnectGraceTimer()

            if powerState == .armed {
                NSLog("[KiloClaim Native] CoreMotion automotive confirmed after geofence exit. Starting drive.")
                startNativeRecording(triggeredByBluetooth: isTargetBluetoothConnected, seedLocation: parkedAnchorLocation)
            }
        } else if activity.walking || activity.stationary {
            isAutomotiveConfirmed = false
            if powerState == .activeDriving && !isTargetBluetoothConnected && activity.walking && activity.confidence == .high {
                scheduleDisconnectGraceTimer()
            }
        }
    }

    // MARK: - AVAudioSession Route Observer (Classic BT / CarPlay)

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.checkActiveAudioRoute()
        }
    }

    private func checkActiveAudioRoute() {
        let defaults = UserDefaults.standard
        guard let targetName = defaults.string(forKey: userDefaultsKeyTargetBT), !targetName.isEmpty else {
            isTargetBluetoothConnected = false
            return
        }

        let route = AVAudioSession.sharedInstance().currentRoute
        let allPorts = route.outputs + route.inputs
        let bluetoothPortTypes: Set<AVAudioSession.Port> = [
            .bluetoothHFP,
            .bluetoothA2DP,
            .bluetoothLE,
            .carAudio
        ]

        let connected = allPorts.contains { port in
            guard bluetoothPortTypes.contains(port.portType) else { return false }
            let portNameLower = port.portName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return portNameLower == targetName || portNameLower.contains(targetName)
        }

        isTargetBluetoothConnected = connected

        if connected {
            cancelDisconnectGraceTimer()
            if powerState == .deepSleep || powerState == .armed {
                NSLog("[KiloClaim Native] Classic BT / CarPlay route connected (\(targetName)). Starting autonomous trip.")
                startNativeRecording(triggeredByBluetooth: true, seedLocation: parkedAnchorLocation)
            } else if powerState == .disconnectGrace {
                powerState = .activeDriving
                tripTriggeredByBluetooth = true
            }
        } else if powerState == .activeDriving && tripTriggeredByBluetooth {
            scheduleDisconnectGraceTimer()
        }
    }

    // MARK: - Disconnect & Stationary Grace Timer

    private func scheduleDisconnectGraceTimer() {
        guard powerState == .activeDriving || powerState == .disconnectGrace else { return }
        powerState = .disconnectGrace
        if disconnectGraceWorkItem != nil { return }

        NSLog("[KiloClaim Native] Vehicle stop/disconnect detected. Starting 3-minute grace window.")
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.disconnectGraceWorkItem = nil
            if self.powerState == .disconnectGrace && !self.isAutomotiveConfirmed && !self.isTargetBluetoothConnected {
                NSLog("[KiloClaim Native] 3-minute grace elapsed. Finalizing native trip.")
                self.finalizeNativeTrip()
            } else if self.powerState == .disconnectGrace {
                self.scheduleDisconnectGraceTimer()
            }
        }
        disconnectGraceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + disconnectGraceSeconds, execute: workItem)
    }

    private func cancelDisconnectGraceTimer() {
        disconnectGraceWorkItem?.cancel()
        disconnectGraceWorkItem = nil
    }

    // MARK: - Parked Geofence (GPS = 0% while parked)

    private func plantParkedGeofence(at location: CLLocation) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        clearParkedGeofence()

        parkedAnchorLocation = location
        let region = CLCircularRegion(
            center: location.coordinate,
            radius: parkedGeofenceRadiusMeters,
            identifier: parkedRegionIdentifier
        )
        region.notifyOnExit = true
        region.notifyOnEntry = false
        locationManager?.startMonitoring(for: region)
    }

    private func clearParkedGeofence() {
        guard let regions = locationManager?.monitoredRegions else { return }
        for region in regions where region.identifier == parkedRegionIdentifier {
            locationManager?.stopMonitoring(for: region)
        }
    }

    // MARK: - CBCentralManagerDelegate (Passive System Inspection Only — No Continuous BLE Scan)

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            inspectConnectedBlePeripherals()
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        NSLog("[KiloClaim Native] Restored by iOS CoreBluetooth from background state.")
        inspectConnectedBlePeripherals()
    }

    private func matchesTarget(peripheral: CBPeripheral) -> Bool {
        let defaults = UserDefaults.standard
        let targetName = defaults.string(forKey: userDefaultsKeyTargetBT)
        let targetUuid = defaults.string(forKey: userDefaultsKeyTargetBTUuid)

        if (targetName == nil || targetName!.isEmpty) && (targetUuid == nil || targetUuid!.isEmpty) {
            return false
        }

        let peripheralUuid = peripheral.identifier.uuidString.lowercased()
        if let targetUuid = targetUuid, !targetUuid.isEmpty, peripheralUuid == targetUuid {
            return true
        }

        guard let target = targetName, !target.isEmpty else { return false }
        let targetLower = target.lowercased()
        if peripheralUuid == targetLower || peripheralUuid.contains(targetLower) {
            return true
        }

        if let name = peripheral.name?.lowercased(), name == targetLower || name.contains(targetLower) {
            return true
        }
        return false
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if matchesTarget(peripheral: peripheral) {
            DispatchQueue.main.async {
                self.isTargetBluetoothConnected = true
                self.cancelDisconnectGraceTimer()
                self.startNativeRecording(triggeredByBluetooth: true, seedLocation: self.parkedAnchorLocation)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if matchesTarget(peripheral: peripheral) {
            DispatchQueue.main.async {
                self.isTargetBluetoothConnected = false
                if self.powerState == .activeDriving {
                    self.scheduleDisconnectGraceTimer()
                }
            }
        }
    }

    private func inspectConnectedBlePeripherals() {
        guard let target = UserDefaults.standard.string(forKey: userDefaultsKeyTargetBT), !target.isEmpty else { return }

        // Only query already-connected system peripherals; never run an unbounded BLE scan in background.
        if let connected = centralManager?.retrieveConnectedPeripherals(withServices: [
            CBUUID(string: "1800"),
            CBUUID(string: "1801"),
            CBUUID(string: "180A"),
        ]) {
            for peripheral in connected where matchesTarget(peripheral: peripheral) {
                DispatchQueue.main.async {
                    self.isTargetBluetoothConnected = true
                    self.cancelDisconnectGraceTimer()
                    if self.powerState == .deepSleep || self.powerState == .armed {
                        self.startNativeRecording(triggeredByBluetooth: true, seedLocation: self.parkedAnchorLocation)
                    }
                }
                return
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    @objc func startNativeRecording() {
        startNativeRecording(triggeredByBluetooth: isTargetBluetoothConnected, seedLocation: parkedAnchorLocation)
    }

    private func startNativeRecording(triggeredByBluetooth: Bool, seedLocation: CLLocation?) {
        guard powerState != .activeDriving else { return }
        powerState = .activeDriving
        tripTriggeredByBluetooth = triggeredByBluetooth
        startLocation = seedLocation
        lastLocation = seedLocation
        stationarySince = nil
        accumulatedDistanceMeters = 0.0
        tripStartTime = Date()

        DispatchQueue.main.async {
            self.clearParkedGeofence()
            self.locationManager?.pausesLocationUpdatesAutomatically = false
            self.locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            self.locationManager?.startUpdatingLocation()
        }
    }

    @objc func finalizeNativeTrip() {
        guard powerState == .activeDriving || powerState == .disconnectGrace else { return }
        cancelDisconnectGraceTimer()
        let finalAnchor = lastLocation ?? locationManager?.location
        let btMatched = tripTriggeredByBluetooth || isTargetBluetoothConnected

        powerState = .deepSleep
        stationarySince = nil
        tripTriggeredByBluetooth = false

        DispatchQueue.main.async {
            self.locationManager?.stopUpdatingLocation()
            self.locationManager?.pausesLocationUpdatesAutomatically = true
            if let anchor = finalAnchor {
                self.plantParkedGeofence(at: anchor)
            }
        }

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
            "source": btMatched ? "native_bluetooth_auto" : "native_motion_geofence",
            "vehicleBluetoothMatched": btMatched
        ]

        var existing = UserDefaults.standard.array(forKey: userDefaultsKeyCompletedTrips) as? [[String: Any]] ?? []
        existing.append(completedTrip)
        UserDefaults.standard.set(existing, forKey: userDefaultsKeyCompletedTrips)

        sendTripNotification(distanceKm: distanceKm)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == parkedRegionIdentifier else { return }
        guard powerState == .deepSleep else { return }

        powerState = .armed
        NSLog("[KiloClaim Native] Exited 200m parked geofence. Armed for CoreMotion/speed confirmation.")
        if isAutomotiveConfirmed || isTargetBluetoothConnected {
            startNativeRecording(triggeredByBluetooth: isTargetBluetoothConnected, seedLocation: parkedAnchorLocation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        guard latest.horizontalAccuracy >= 0 && latest.horizontalAccuracy <= 65.0 else { return }

        // SLC wake-up while sleeping: promote if moving at vehicle speed (> 18 km/h = 5.0 m/s) or automotive.
        if powerState == .deepSleep || powerState == .armed {
            if latest.speed >= 5.0 || (isAutomotiveConfirmed && latest.speed >= 2.5) {
                startNativeRecording(triggeredByBluetooth: isTargetBluetoothConnected, seedLocation: parkedAnchorLocation ?? latest)
            } else if powerState == .deepSleep && parkedAnchorLocation == nil {
                plantParkedGeofence(at: latest)
            }
            return
        }

        guard powerState == .activeDriving || powerState == .disconnectGrace else { return }

        if startLocation == nil {
            startLocation = latest
            lastLocation = latest
            return
        }

        if let prev = lastLocation {
            let delta = latest.distance(from: prev)
            if delta > 3.0 && delta < 2000.0 {
                accumulatedDistanceMeters += delta
                lastLocation = latest
                stationarySince = nil
                if powerState == .disconnectGrace && latest.speed >= 4.0 {
                    cancelDisconnectGraceTimer()
                    powerState = .activeDriving
                }
            } else if latest.speed < 0.8 && !isTargetBluetoothConnected {
                // No-Bluetooth fallback: finalize after 4 minutes stationary.
                let now = Date()
                if stationarySince == nil {
                    stationarySince = now
                } else if let since = stationarySince, now.timeIntervalSince(since) >= stationaryAutoStopSeconds {
                    finalizeNativeTrip()
                }
            }
        }
    }

    private func sendTripNotification(distanceKm: Double) {
        let content = UNMutableNotificationContent()
        content.title = "KiloClaim Auto-Log Complete"
        content.body = String(format: "Recorded %.1f km trip. Ready for 1-tap review.", distanceKm)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "kiloclaim_trip_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
