// Temporary file to document Core Data reset procedure

// If the app crashes with NSTaggedPointerString count error, it's likely due to
// Core Data model incompatibility. Follow these steps:

// 1. Delete the app from simulator/device
// 2. Clean build folder (Cmd+Shift+K)
// 3. Delete derived data
// 4. Rebuild and run

// Alternative: Add this code to AppDelegate temporarily:
/*
func resetCoreDataIfNeeded() {
    let storeURL = NSPersistentContainer.defaultDirectoryURL()
        .appendingPathComponent("TrainAlert.sqlite")
    
    do {
        try FileManager.default.removeItem(at: storeURL)
        print("Core Data store deleted")
    } catch {
        print("Could not delete Core Data store: \(error)")
    }
}
*/