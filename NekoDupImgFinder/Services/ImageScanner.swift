import Foundation
import AppKit
import Combine
import CryptoKit

@MainActor
class ImageScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0.0
    @Published var currentFile = ""
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var scannedFiles: [ImageFile] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("【DEBUG】ImageScanner 初始化")
    }
    
    // 掃描設定
    var scanMode: ScanMode {
        get { SettingsManager.shared.scanMode }
        set { SettingsManager.shared.scanMode = newValue }
    }
    var similarityThreshold: Int {
        get { SettingsManager.shared.similarityThreshold }
        set { SettingsManager.shared.similarityThreshold = newValue }
    }
    var minFileSize: Int64 {
        get { SettingsManager.shared.minFileSize }
        set { SettingsManager.shared.minFileSize = newValue }
    }
    var compareSameExtensionOnly: Bool {
        get { SettingsManager.shared.compareSameExtensionOnly }
        set { SettingsManager.shared.compareSameExtensionOnly = newValue }
    }
    
    func scanDirectory(_ url: URL) async throws {
        print("【LOG】進入 scanDirectory，url = \(url)")

        // 檢查 URL 是否有效
        print("【LOG】url.path = \(url.path)")
        guard !url.path.isEmpty else {
            print("【LOG】❌ URL 路徑為空")
            return
        }
        guard url.isFileURL else {
            print("【LOG】❌ URL 不是檔案 URL: \(url)")
            return
        }

        // 檢查目錄是否存在
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        print("【LOG】fileExists: \(exists), isDirectory: \(isDirectory.boolValue)")
        guard exists else {
            print("【LOG】❌ 目錄不存在: \(url.path)")
            return
        }
        guard isDirectory.boolValue else {
            print("【LOG】❌ 路徑不是目錄: \(url.path)")
            return
        }
        print("【LOG】✓ 目錄存在且可訪問")

        // 測試列出目錄內容
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            print("【LOG】目錄內容測試 - 找到 \(contents.count) 個項目")
            for (index, item) in contents.prefix(5).enumerated() {
                print("【LOG】  [\(index + 1)] \(item.lastPathComponent)")
            }
            if contents.count > 5 {
                print("【LOG】  ... 還有 \(contents.count - 5) 個項目")
            }
        } catch {
            print("【LOG】❌ 無法列出目錄內容: \(error)")
        }

        isScanning = true
        progress = 0.0
        duplicateGroups = []
        scannedFiles = []
        print("【LOG】重設狀態 isScanning=\(isScanning), progress=\(progress)")

        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "bmp", "webp", "gif", "tiff", "tif"]
        print("【LOG】支援的圖片副檔名: \(imageExtensions)")

        print("【LOG】開始枚舉目錄: \(url.path)")
        var enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey
        ])
        print("【LOG】enumerator = \(String(describing: enumerator))")
        guard enumerator != nil else {
            print("【LOG】❌ 無法創建目錄枚舉器，可能是權限問題")
            return
        }
        print("【LOG】✓ 目錄枚舉器創建成功")

        var imageFiles: [ImageFile] = []
        var totalFiles = 0
        var processedFiles = 0

        // 第一遍：收集所有圖片檔案
        var fileCount = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            fileCount += 1
            let pathExtension = fileURL.pathExtension.lowercased()
            print("【LOG】檢查檔案 [\(fileCount)]: \(fileURL.lastPathComponent), 副檔名: \(pathExtension)")
            if imageExtensions.contains(pathExtension) {
                totalFiles += 1
                print("【LOG】✓ 符合圖片格式: \(fileURL.lastPathComponent)")
            }
        }
        print("【LOG】總共檢查了 \(fileCount) 個檔案，其中 \(totalFiles) 個是圖片檔案")

        // 第二遍：處理圖片檔案
        enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey
        ])
        print("【LOG】第二遍 enumerator = \(String(describing: enumerator))")
        while let fileURL = enumerator?.nextObject() as? URL {
            let pathExtension = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(pathExtension) {
                currentFile = fileURL.lastPathComponent
                print("【LOG】處理檔案: \(fileURL.lastPathComponent)")
                let beforeCount = imageFiles.count
                if let imageFile = await processImageFile(fileURL) {
                    imageFiles.append(imageFile)
                    print("【LOG】✓ 成功處理: \(fileURL.lastPathComponent)，目前 imageFiles.count = \(imageFiles.count) (was \(beforeCount))")
                    if imageFile.fileHash == nil {
                        print("【LOG】⚠️ 檔案雜湊計算失敗: \(fileURL.lastPathComponent)")
                    }
                } else {
                    print("【LOG】✗ 處理失敗: \(fileURL.lastPathComponent)")
                }
                processedFiles += 1
                progress = Double(processedFiles) / Double(totalFiles)
                print("【LOG】progress = \(progress)")
            }
        }

        print("【LOG】找到 \(imageFiles.count) 個圖片檔案")
        print("【LOG】當前掃描模式: \(scanMode.rawValue)")
        print("【LOG】包含完全一致比對: \(scanMode.includesExact)")
        print("【LOG】包含視覺相似比對: \(scanMode.includesVisual)")
        scannedFiles = imageFiles

        // 比對重複圖片
        print("【LOG】開始比對重複圖片...")
        let foundGroups = await findDuplicates(in: imageFiles, scanMode: scanMode, similarityThreshold: similarityThreshold)
        duplicateGroups = foundGroups
        print("【LOG】找到 \(duplicateGroups.count) 個重複群組")

        // 自動選擇要刪除的檔案
        print("【LOG】自動選擇要刪除的檔案...")
        autoSelectForDeletion()

        print("【LOG】掃描完成")
        isScanning = false
        currentFile = ""
    }
    
    private func processImageFile(_ url: URL) async -> ImageFile? {
        let resourceValues = try? url.resourceValues(forKeys: [
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey
        ])
        
        guard let resourceValues = resourceValues else {
            Swift.print("無法取得檔案屬性: \(url.lastPathComponent)")
            return nil
        }
        
        guard let fileSize = resourceValues.fileSize else {
            Swift.print("無法取得檔案大小: \(url.lastPathComponent)")
            return nil
        }
        
        guard fileSize >= minFileSize else {
            Swift.print("檔案太小 (\(fileSize) < \(minFileSize)): \(url.lastPathComponent)")
            return nil
        }
        
        let creationDate = resourceValues.creationDate ?? Date()
        let modificationDate = resourceValues.contentModificationDate ?? Date()
        
        // 取得圖片尺寸
        let imageSize = getImageSize(from: url)
        
        // 計算檔案 hash
        let fileHash = await calculateFileHash(url: url)
        
        // 計算感知 hash（僅在需要視覺比對時）
        let perceptualHash = scanMode.includesVisual ? await calculatePerceptualHash(url: url) : nil
        
        return ImageFile(
            url: url,
            fileName: url.lastPathComponent,
            fileSize: Int64(fileSize),
            creationDate: creationDate,
            modificationDate: modificationDate,
            imageSize: imageSize,
            fileHash: fileHash,
            perceptualHash: perceptualHash
        )
    }
    
    private func getImageSize(from url: URL) -> CGSize? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        if let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
           let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            return CGSize(width: width, height: height)
        }
        
        return nil
    }
    
    private nonisolated func calculateFileHash(url: URL) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: url)
                    let hash = SHA256.hash(data: data)
                    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                    Swift.print("計算檔案雜湊: \(url.lastPathComponent) -> \(String(hashString.prefix(8)))...")
                    continuation.resume(returning: hashString)
                } catch {
                    Swift.print("計算檔案 hash 錯誤: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private nonisolated func calculatePerceptualHash(url: URL) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = NSImage(contentsOf: url),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    Swift.print("⚠️ 無法載入圖片進行感知雜湊計算: \(url.lastPathComponent)")
                    continuation.resume(returning: nil)
                    return
                }
                
                // 簡化的感知 hash 計算
                let hash = self.simplePerceptualHash(cgImage: cgImage)
                Swift.print("計算感知雜湊: \(url.lastPathComponent) -> \(String(hash.prefix(8)))...")
                continuation.resume(returning: hash)
            }
        }
    }
    
    private nonisolated func simplePerceptualHash(cgImage: CGImage) -> String {
        // 簡化的感知 hash 實作
        // 實際應用中可以使用更複雜的演算法
        let width = cgImage.width
        let height = cgImage.height
        
        Swift.print("處理圖片尺寸: \(width) x \(height)")
        
        // 縮小到 8x8 進行快速比對
        let targetSize = CGSize(width: 8, height: 8)
        
        guard let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 8 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ""
        }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        
        guard let data = context.data else { return "" }
        
        let ptr = data.bindMemory(to: UInt8.self, capacity: 8 * 8 * 4)
        var hash = ""
        
        for y in 0..<8 {
            for x in 0..<8 {
                let offset = (y * 8 + x) * 4
                let gray = (Int(ptr[offset]) + Int(ptr[offset + 1]) + Int(ptr[offset + 2])) / 3
                hash += gray > 128 ? "1" : "0"
            }
        }
        
        Swift.print("感知雜湊結果: \(String(hash.prefix(16)))...")
        return hash
    }
    
    private nonisolated func findDuplicates(in files: [ImageFile], scanMode: ScanMode, similarityThreshold: Int) async -> [DuplicateGroup] {
        var allGroups: [DuplicateGroup] = []
        
        // 完全一致比對
        if scanMode.includesExact {
            var exactGroups: [String: [ImageFile]] = [:]
            for file in files {
                if let hash = file.fileHash {
                    exactGroups[hash, default: []].append(file)
                }
            }
            
            // 過濾出完全一致的重複群組
            for (hash, groupFiles) in exactGroups {
                guard groupFiles.count > 1 else { continue }
                Swift.print("找到完全一致群組: \(groupFiles.count) 個檔案，hash: \(String(hash.prefix(8)))...")
                allGroups.append(DuplicateGroup(files: groupFiles, similarityType: .exact))
            }
        }
        
        // 視覺相似比對
        if scanMode.includesVisual {
            var processedFiles = Set<ImageFile>()
            var visualGroups: [DuplicateGroup] = []
            
            for i in 0..<files.count {
                let file1 = files[i]
                guard let phash1 = file1.perceptualHash else { continue }
                
                if processedFiles.contains(file1) { continue }
                
                var similarFiles = [file1]
                processedFiles.insert(file1)
                
                // 與其他檔案比較
                for j in (i+1)..<files.count {
                    let file2 = files[j]
                    guard let phash2 = file2.perceptualHash else { continue }
                    
                    if processedFiles.contains(file2) { continue }
                    
                    // 計算漢明距離（不同位元的數量）
                    let hammingDistance = calculateHammingDistance(phash1, phash2)
                    Swift.print("比較 \(file1.fileName) 和 \(file2.fileName)，漢明距離: \(hammingDistance)")
                    
                    // 如果漢明距離小於等於容忍度，認為是相似的
                    if hammingDistance <= similarityThreshold {
                        similarFiles.append(file2)
                        processedFiles.insert(file2)
                        Swift.print("✓ 認為相似，容忍度: \(similarityThreshold)")
                    }
                }
                
                // 如果找到多個相似檔案，加入群組
                if similarFiles.count > 1 {
                    Swift.print("找到視覺相似群組: \(similarFiles.count) 個檔案")
                    visualGroups.append(DuplicateGroup(files: similarFiles, similarityType: .visual))
                }
            }
            
            allGroups.append(contentsOf: visualGroups)
        }
        
        return allGroups
    }
    
    private nonisolated func calculateHammingDistance(_ hash1: String, _ hash2: String) -> Int {
        guard hash1.count == hash2.count else { return Int.max }
        
        var distance = 0
        for (char1, char2) in zip(hash1, hash2) {
            if char1 != char2 {
                distance += 1
            }
        }
        return distance
    }
    
    // 自動選擇要刪除的檔案（保留最大的）
    func autoSelectForDeletion() {
        for i in 0..<duplicateGroups.count {
            duplicateGroups[i].autoSelectForDeletion()
        }
    }
    
    // 全選所有重複檔案
    func selectAllDuplicates() {
        for i in 0..<duplicateGroups.count {
            duplicateGroups[i].toggleAllSelection()
        }
    }
    
    // 取消全選
    func deselectAllDuplicates() {
        for i in 0..<duplicateGroups.count {
            duplicateGroups[i].files = duplicateGroups[i].files.map { file in
                file.withSelection(false)
            }
        }
    }
    
    // 獲取所有選中的檔案
    var allSelectedFiles: [ImageFile] {
        duplicateGroups.flatMap { group in
            group.selectedFiles
        }
    }
    
    // 獲取所有要保留的檔案
    var allUnselectedFiles: [ImageFile] {
        duplicateGroups.flatMap { group in
            group.unselectedFiles
        }
    }
    
    // 檢查是否有任何檔案被選中
    var hasAnySelection: Bool {
        duplicateGroups.contains { group in
            group.hasSelection
        }
    }
    
    // 檢查是否所有重複檔案都被選中
    var allDuplicatesSelected: Bool {
        duplicateGroups.allSatisfy { group in
            group.allSelected
        }
    }
    
    func deleteFiles(_ files: [ImageFile]) async {
        for file in files {
            do {
                try FileManager.default.removeItem(at: file.url)
            } catch {
                Swift.print("刪除檔案錯誤 \(file.url.path): \(error)")
            }
        }
        
        // 重新掃描以更新結果
        if let firstFile = scannedFiles.first {
            try? await scanDirectory(firstFile.url.deletingLastPathComponent())
        }
    }
    
    // 刪除所有選中的檔案
    func deleteAllSelectedFiles() async {
        let selectedFiles = allSelectedFiles
        await deleteFiles(selectedFiles)
    }
    
    func exportDuplicateList() -> String {
        var csv = "檔案名稱,檔案路徑,檔案大小,建立日期,圖片尺寸,相似類型,選擇狀態\n"
        
        for group in duplicateGroups {
            for file in group.files {
                csv += "\"\(file.fileName)\",\"\(file.url.path)\",\"\(file.fileSizeFormatted)\",\"\(file.creationDateFormatted)\",\"\(file.imageSizeFormatted)\",\"\(group.similarityType.displayName)\",\"\(file.isSelected ? "選中" : "未選中")\"\n"
            }
        }
        
        return csv
    }
} 