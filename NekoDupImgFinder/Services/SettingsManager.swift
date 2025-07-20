import Foundation
import Combine

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var lastUsedDirectory: URL?
    @Published var scanMode: ScanMode = .both
    @Published var minFileSize: Int64 = 1 * 1024  // 降低到 1KB
    @Published var similarityThreshold: Int = 5
    @Published var compareSameExtensionOnly = false
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSettings()
        setupBindings()
    }
    
    private func setupBindings() {
        $lastUsedDirectory
            .sink { [weak self] url in
                if let url = url {
                    self?.userDefaults.set(url.path, forKey: "lastUsedDirectory")
                } else {
                    self?.userDefaults.removeObject(forKey: "lastUsedDirectory")
                }
            }
            .store(in: &cancellables)
        
        $scanMode
            .sink { [weak self] mode in
                self?.userDefaults.set(mode.rawValue, forKey: "scanMode")
            }
            .store(in: &cancellables)
        
        $minFileSize
            .sink { [weak self] size in
                self?.userDefaults.set(size, forKey: "minFileSize")
            }
            .store(in: &cancellables)
        
        $similarityThreshold
            .sink { [weak self] threshold in
                self?.userDefaults.set(threshold, forKey: "similarityThreshold")
            }
            .store(in: &cancellables)
        
        $compareSameExtensionOnly
            .sink { [weak self] enabled in
                self?.userDefaults.set(enabled, forKey: "compareSameExtensionOnly")
            }
            .store(in: &cancellables)
    }
    
    private func loadSettings() {
        // 載入最後使用的目錄
        if let path = userDefaults.string(forKey: "lastUsedDirectory") {
            lastUsedDirectory = URL(fileURLWithPath: path)
        }
        
        // 載入掃描模式
        if let modeString = userDefaults.string(forKey: "scanMode"),
           let mode = ScanMode(rawValue: modeString) {
            scanMode = mode
        }
        
        // 載入最小檔案大小
        minFileSize = userDefaults.object(forKey: "minFileSize") as? Int64 ?? 1 * 1024
        
        // 載入相似度容忍度
        similarityThreshold = userDefaults.integer(forKey: "similarityThreshold")
        if similarityThreshold == 0 {
            similarityThreshold = 5
        }
        
        // 載入副檔名比對設定
        compareSameExtensionOnly = userDefaults.bool(forKey: "compareSameExtensionOnly")
    }
    
    func resetToDefaults() {
        lastUsedDirectory = nil
        scanMode = .both
        minFileSize = 1 * 1024
        similarityThreshold = 5
        compareSameExtensionOnly = false
    }
} 