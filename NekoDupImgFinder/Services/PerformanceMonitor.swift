import Foundation
import Combine

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var peakMemoryUsage: UInt64 = 0
    @Published var scanStartTime: Date?
    @Published var scanDuration: TimeInterval = 0
    @Published var processedFilesCount: Int = 0
    @Published var processingSpeed: Double = 0 // files per second
    
    private var memoryTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startMemoryMonitoring()
    }
    
    func startScan() {
        scanStartTime = Date()
        processedFilesCount = 0
        processingSpeed = 0
    }
    
    func endScan() {
        guard let startTime = scanStartTime else { return }
        scanDuration = Date().timeIntervalSince(startTime)
        scanStartTime = nil
    }
    
    func updateProcessedFiles(_ count: Int) {
        processedFilesCount = count
        
        if let startTime = scanStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 {
                processingSpeed = Double(count) / elapsed
            }
        }
    }
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    private func updateMemoryUsage() {
        let memoryInfo = getMemoryInfo()
        currentMemoryUsage = memoryInfo.current
        peakMemoryUsage = max(peakMemoryUsage, memoryInfo.current)
    }
    
    private func getMemoryInfo() -> (current: UInt64, peak: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return (current: UInt64(info.resident_size), peak: UInt64(info.resident_size))
        } else {
            return (current: 0, peak: 0)
        }
    }
    
    func getFormattedMemoryUsage() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(currentMemoryUsage))
    }
    
    func getFormattedPeakMemoryUsage() -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(peakMemoryUsage))
    }
    
    func getFormattedScanDuration() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: scanDuration) ?? "0s"
    }
    
    func getFormattedProcessingSpeed() -> String {
        return String(format: "%.1f 檔案/秒", processingSpeed)
    }
    
    func reset() {
        peakMemoryUsage = 0
        scanDuration = 0
        processedFilesCount = 0
        processingSpeed = 0
        scanStartTime = nil
    }
    
    deinit {
        memoryTimer?.invalidate()
    }
} 