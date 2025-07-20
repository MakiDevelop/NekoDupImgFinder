import Foundation
import AppKit

struct TestData {
    static func createTestImageFiles() -> [ImageFile] {
        let testURLs = [
            URL(fileURLWithPath: "/Users/test/photo1.jpg"),
            URL(fileURLWithPath: "/Users/test/photo2.jpg"),
            URL(fileURLWithPath: "/Users/test/photo3.png"),
            URL(fileURLWithPath: "/Users/test/photo4.heic")
        ]
        
        return testURLs.enumerated().map { index, url in
            ImageFile(
                url: url,
                fileName: url.lastPathComponent,
                fileSize: Int64((index + 1) * 1024 * 1024), // 1MB, 2MB, 3MB, 4MB
                creationDate: Date().addingTimeInterval(-Double(index * 86400)), // 每天遞減
                modificationDate: Date().addingTimeInterval(-Double(index * 86400)),
                imageSize: CGSize(width: 1920 + index * 100, height: 1080 + index * 100),
                fileHash: "test_hash_\(index)",
                perceptualHash: "test_phash_\(index)",
                isSelected: false // 預設未選中
            )
        }
    }
    
    static func createTestDuplicateGroups() -> [DuplicateGroup] {
        let testFiles = createTestImageFiles()
        
        // 建立兩個重複群組，並設定選擇狀態
        var group1 = DuplicateGroup(
            files: [testFiles[0], testFiles[1]],
            similarityType: .exact
        )
        group1.autoSelectForDeletion() // 自動選擇（保留最大的）
        
        var group2 = DuplicateGroup(
            files: [testFiles[2], testFiles[3]],
            similarityType: .visual
        )
        group2.autoSelectForDeletion() // 自動選擇（保留最大的）
        
        return [group1, group2]
    }
    
    @MainActor
    static func createTestScanner() -> ImageScanner {
        let scanner = ImageScanner()
        scanner.scannedFiles = createTestImageFiles()
        scanner.duplicateGroups = createTestDuplicateGroups()
        return scanner
    }
} 