import Foundation
import AppKit

struct ImageFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let fileName: String
    let fileSize: Int64
    let creationDate: Date
    let modificationDate: Date
    let imageSize: CGSize?
    let fileHash: String?
    let perceptualHash: String?
    
    // 新增選擇狀態
    var isSelected: Bool = false
    
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var creationDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
    
    var modificationDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    var imageSizeFormatted: String {
        guard let size = imageSize else { return "未知" }
        return "\(Int(size.width)) × \(Int(size.height))"
    }
    
    // 用於群組比對
    var groupKey: String {
        fileHash ?? perceptualHash ?? url.lastPathComponent
    }
    
    // 建立可變的副本
    func withSelection(_ selected: Bool) -> ImageFile {
        var copy = self
        copy.isSelected = selected
        return copy
    }
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    var files: [ImageFile]
    let similarityType: SimilarityType
    
    var suggestedKeepFile: ImageFile? {
        // 建議保留檔案大小最大的圖片
        files.max { file1, file2 in
            file1.fileSize < file2.fileSize
        }
    }
    
    // 自動選擇要刪除的檔案（保留最大的）
    mutating func autoSelectForDeletion() {
        guard let keepFile = suggestedKeepFile else { return }
        
        files = files.map { file in
            file.withSelection(file.id != keepFile.id)
        }
    }
    
    // 全選/取消全選
    mutating func toggleAllSelection() {
        let allSelected = files.allSatisfy { $0.isSelected }
        files = files.map { file in
            file.withSelection(!allSelected)
        }
    }
    
    // 獲取選中的檔案
    var selectedFiles: [ImageFile] {
        files.filter { $0.isSelected }
    }
    
    // 獲取未選中的檔案（要保留的）
    var unselectedFiles: [ImageFile] {
        files.filter { !$0.isSelected }
    }
    
    // 檢查是否所有檔案都被選中
    var allSelected: Bool {
        files.allSatisfy { $0.isSelected }
    }
    
    // 檢查是否有檔案被選中
    var hasSelection: Bool {
        files.contains { $0.isSelected }
    }
}

enum SimilarityType {
    case exact
    case visual
    
    var displayName: String {
        switch self {
        case .exact:
            return "完全一致"
        case .visual:
            return "視覺相似"
        }
    }
}

enum ScanMode: String, CaseIterable {
    case exact = "完全一致"
    case visual = "視覺相似"
    case both = "兩種模式"
    
    var includesExact: Bool {
        self == .exact || self == .both
    }
    
    var includesVisual: Bool {
        self == .visual || self == .both
    }
} 