import SwiftUI

struct StatisticsView: View {
    @ObservedObject var scanner: ImageScanner
    @ObservedObject var performanceMonitor = PerformanceMonitor.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("📊 掃描統計")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                StatCard(
                    title: "掃描檔案",
                    value: "\(scanner.scannedFiles.count)",
                    icon: "doc.text"
                )
                
                StatCard(
                    title: "重複群組",
                    value: "\(scanner.duplicateGroups.count)",
                    icon: "folder.badge.plus"
                )
                
                StatCard(
                    title: "重複檔案",
                    value: "\(scanner.duplicateGroups.reduce(0) { $0 + $1.files.count })",
                    icon: "photo.on.rectangle"
                )
                
                StatCard(
                    title: "節省空間",
                    value: calculateSpaceSaved(),
                    icon: "externaldrive"
                )
            }
            
            if performanceMonitor.scanDuration > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("⚡ 效能數據")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("掃描時間:")
                            Spacer()
                            Text(performanceMonitor.getFormattedScanDuration())
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("處理速度:")
                            Spacer()
                            Text(performanceMonitor.getFormattedProcessingSpeed())
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("記憶體使用:")
                            Spacer()
                            Text(performanceMonitor.getFormattedMemoryUsage())
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("峰值記憶體:")
                            Spacer()
                            Text(performanceMonitor.getFormattedPeakMemoryUsage())
                                .fontWeight(.medium)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func calculateSpaceSaved() -> String {
        let totalSize = scanner.duplicateGroups.reduce(0) { total, group in
            total + group.files.reduce(0) { fileTotal, file in
                fileTotal + file.fileSize
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    StatisticsView(scanner: ImageScanner())
} 