import SwiftUI

struct SelectionSummaryView: View {
    @ObservedObject var scanner: ImageScanner
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("📋 選擇摘要")
                .font(.headline)
            
            if scanner.hasAnySelection {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("選中檔案:")
                        Spacer()
                        Text("\(scanner.allSelectedFiles.count)")
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("保留檔案:")
                        Spacer()
                        Text("\(scanner.allUnselectedFiles.count)")
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("節省空間:")
                        Spacer()
                        Text(calculateSpaceSaved())
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("重複群組:")
                        Spacer()
                        Text("\(scanner.duplicateGroups.count)")
                            .fontWeight(.bold)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("操作建議")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("• 選中的檔案將被刪除")
                    Text("• 未選中的檔案將被保留")
                    Text("• 建議保留檔案大小最大的版本")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("尚未選擇任何檔案")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("點擊檔案旁的方框來選擇要刪除的檔案")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func calculateSpaceSaved() -> String {
        let totalSize = scanner.allSelectedFiles.reduce(0) { total, file in
            total + file.fileSize
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

#Preview {
    SelectionSummaryView(scanner: ImageScanner())
} 