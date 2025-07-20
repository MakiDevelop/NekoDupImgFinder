import SwiftUI

struct PreviewContentView: View {
    @StateObject private var scanner = ImageScanner()
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedDirectory: URL?
    @State private var showingDirectoryPicker = false
    @State private var showingDeleteAlert = false
    @State private var filesToDelete: [ImageFile] = []
    @State private var showingExportSheet = false
    @State private var isPreviewMode = true
    
    var body: some View {
        NavigationSplitView {
            PreviewSidebarView(
                scanner: scanner,
                settings: settings,
                selectedDirectory: $selectedDirectory,
                showingDirectoryPicker: $showingDirectoryPicker,
                isPreviewMode: $isPreviewMode
            )
        } content: {
            PreviewContentListView(
                scanner: scanner,
                filesToDelete: $filesToDelete,
                showingDeleteAlert: $showingDeleteAlert,
                showingExportSheet: $showingExportSheet
            )
        } detail: {
            PreviewDetailView(scanner: scanner)
        }
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedDirectory = urls.first
            case .failure(let error):
                print("選擇目錄錯誤: \(error)")
            }
        }
        .alert("確認刪除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                Task {
                    await scanner.deleteFiles(filesToDelete)
                }
            }
        } message: {
            Text("確定要刪除選中的 \(filesToDelete.count) 個檔案嗎？此操作無法復原。")
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: CSVDocument(content: scanner.exportDuplicateList()),
            contentType: .commaSeparatedText,
            defaultFilename: "重複圖片清單.csv"
        ) { _ in }
    }
}

struct PreviewSidebarView: View {
    @ObservedObject var scanner: ImageScanner
    @ObservedObject var settings: SettingsManager
    @Binding var selectedDirectory: URL?
    @Binding var showingDirectoryPicker: Bool
    @Binding var isPreviewMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🐾 NekoDupImgFinder")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            DirectorySelectionView(
                selectedDirectory: $selectedDirectory,
                showingDirectoryPicker: $showingDirectoryPicker
            )
            
            ScanModeSelectionView(settings: settings)
            
            AdvancedSettingsView(settings: settings)
            
            Spacer()
            
            ScanProgressView(scanner: scanner, selectedDirectory: selectedDirectory)
            
            PreviewModeToggle(isPreviewMode: $isPreviewMode, scanner: scanner)
        }
        .padding()
        .frame(minWidth: 300)
    }
}

struct DirectorySelectionView: View {
    @Binding var selectedDirectory: URL?
    @Binding var showingDirectoryPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("📂 掃描目錄")
                .font(.headline)
            
            if let directory = selectedDirectory {
                Text(directory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Button("選擇目錄") {
                showingDirectoryPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ScanModeSelectionView: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🔍 比對模式")
                .font(.headline)
            
            Picker("比對模式", selection: $settings.scanMode) {
                ForEach(ScanMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("⚙️ 進階設定")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("最小檔案大小:")
                    Spacer()
                    Text("\(settings.minFileSize / 1024) KB")
                }
                
                Slider(value: Binding(
                    get: { Double(settings.minFileSize) / 1024 },
                    set: { settings.minFileSize = Int64($0 * 1024) }
                ), in: 1...1000, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("相似度容忍度:")
                    Spacer()
                    Text("\(settings.similarityThreshold)")
                }
                
                Slider(value: Binding(
                    get: { Double(settings.similarityThreshold) },
                    set: { settings.similarityThreshold = Int($0) }
                ), in: 1...10, step: 1)
            }
        }
    }
}

struct ScanProgressView: View {
    @ObservedObject var scanner: ImageScanner
    let selectedDirectory: URL?
    
    var body: some View {
        if scanner.isScanning {
            VStack(alignment: .leading, spacing: 10) {
                Text("🔄 掃描中...")
                    .font(.headline)
                
                ProgressView(value: scanner.progress)
                    .progressViewStyle(.linear)
                
                Text(scanner.currentFile)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        } else {
            Button("開始掃描") {
                if let directory = selectedDirectory {
                    Task { @MainActor in
                        do {
                            try await scanner.scanDirectory(directory)
                        } catch {
                            print("掃描過程中發生錯誤: \(error)")
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedDirectory == nil)
        }
    }
}

struct PreviewModeToggle: View {
    @Binding var isPreviewMode: Bool
    @ObservedObject var scanner: ImageScanner
    
    var body: some View {
        Toggle("預覽模式", isOn: $isPreviewMode)
            .font(.caption)
            .onChange(of: isPreviewMode) { _, newValue in
                if newValue {
                    scanner.scannedFiles = TestData.createTestImageFiles()
                    scanner.duplicateGroups = TestData.createTestDuplicateGroups()
                } else {
                    scanner.scannedFiles = []
                    scanner.duplicateGroups = []
                }
            }
    }
}

struct PreviewContentListView: View {
    @ObservedObject var scanner: ImageScanner
    @Binding var filesToDelete: [ImageFile]
    @Binding var showingDeleteAlert: Bool
    @Binding var showingExportSheet: Bool
    
    var body: some View {
        if scanner.duplicateGroups.isEmpty && !scanner.isScanning {
            EmptyStateView()
        } else {
            DuplicateGroupsListView(
                scanner: scanner,
                filesToDelete: $filesToDelete,
                showingDeleteAlert: $showingDeleteAlert,
                showingExportSheet: $showingExportSheet
            )
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("尚未開始掃描")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("選擇一個目錄並開始掃描以尋找重複圖片")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DuplicateGroupsListView: View {
    @ObservedObject var scanner: ImageScanner
    @Binding var filesToDelete: [ImageFile]
    @Binding var showingDeleteAlert: Bool
    @Binding var showingExportSheet: Bool
    
    var body: some View {
        List {
            ForEach(scanner.duplicateGroups) { group in
                Section {
                    ForEach(group.files) { file in
                        DuplicateFileRow(
                            file: file,
                            isSelected: file.isSelected,
                            isSuggested: file.id == group.suggestedKeepFile?.id,
                            onToggleSelection: {
                                // 在預覽模式中不處理選擇狀態
                            },
                            onDelete: {
                                filesToDelete = [file]
                                showingDeleteAlert = true
                            }
                        )
                    }
                } header: {
                    HStack {
                        Text("\(group.similarityType.displayName) - \(group.files.count) 個檔案")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("刪除群組") {
                            filesToDelete = group.files
                            showingDeleteAlert = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .navigationTitle("重複圖片")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("匯出 CSV") {
                    showingExportSheet = true
                }
                .disabled(scanner.duplicateGroups.isEmpty)
            }
        }
    }
}

struct PreviewDetailView: View {
    @ObservedObject var scanner: ImageScanner
    
    var body: some View {
        if let selectedFile = scanner.scannedFiles.first {
            FileDetailView(file: selectedFile)
        } else {
            VStack {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("選擇一個檔案以查看詳細資訊")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    PreviewContentView()
} 