//
//  ContentView.swift
//  NekoDupImgFinder
//
//  Created by 千葉牧人 on 2025/7/20.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var scanner = ImageScanner()
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedDirectory: URL?
    @State private var showingDirectoryPicker = false
    @State private var showingDeleteAlert = false
    @State private var filesToDelete: [ImageFile] = []
    @State private var showingExportSheet = false
    
    var body: some View {
        NavigationSplitView {
            // 側邊欄：掃描設定
            VStack(alignment: .leading, spacing: 20) {
                Text("🐾 NekoDupImgFinder")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                ModernSettingRow(
                    title: "掃描目錄",
                    subtitle: selectedDirectory?.path,
                    icon: "folder"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let directory = selectedDirectory {
                            Text(directory.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        ModernPrimaryButton("選擇目錄", icon: "folder.badge.plus") {
                            showingDirectoryPicker = true
                        }
                    }
                }
                
                ModernSettingRow(
                    title: "比對模式",
                    subtitle: "選擇重複圖片的識別方式",
                    icon: "magnifyingglass"
                ) {
                    Picker("比對模式", selection: $settings.scanMode) {
                        ForEach(ScanMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                ModernSettingRow(
                    title: "進階設定",
                    subtitle: "調整掃描參數",
                    icon: "slider.horizontal.3"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("最小檔案大小")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(settings.minFileSize / 1024) KB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(settings.minFileSize) / 1024 },
                                set: { settings.minFileSize = Int64($0 * 1024) }
                            ), in: 1...1000, step: 1)
                            .tint(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("相似度容忍度")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(settings.similarityThreshold)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(settings.similarityThreshold) },
                                set: { settings.similarityThreshold = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(.blue)
                        }
                    }
                }
                
                Spacer()
                
                if scanner.isScanning {
                    ModernProgressView(
                        progress: scanner.progress,
                        title: "掃描中...",
                        subtitle: scanner.currentFile
                    )
                } else {
                    ModernPrimaryButton(
                        "開始掃描",
                        icon: "play.fill",
                        isDisabled: selectedDirectory == nil
                    ) {
                        print("【DEBUG】按鈕被點擊")
                        if let directory = selectedDirectory {
                            print("【DEBUG】selectedDirectory = \(directory)")
                            Task {
                                print("【DEBUG】開始執行 Task")
                                do {
                                    print("【DEBUG】準備呼叫 scanDirectory")
                                    try await scanner.scanDirectory(directory)
                                    print("【DEBUG】scanDirectory 完成")
                                } catch {
                                    print("掃描過程中發生錯誤: \(error)")
                                }
                            }
                        } else {
                            print("【DEBUG】selectedDirectory 為 nil")
                        }
                    }
                }
            }
            .padding()
            .frame(minWidth: 300)
        } content: {
            // 主要內容：重複圖片列表
            if scanner.duplicateGroups.isEmpty && !scanner.isScanning {
                ModernEmptyState(
                    icon: "photo.on.rectangle.angled",
                    title: "尚未開始掃描",
                    subtitle: "選擇一個目錄並開始掃描以尋找重複圖片",
                    actionTitle: "選擇目錄",
                    action: {
                        showingDirectoryPicker = true
                    }
                )
            } else {
                VStack {
                    // 批次操作工具列
                    if !scanner.duplicateGroups.isEmpty {
                        HStack(spacing: 12) {
                            Text("批次操作")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            ModernSecondaryButton("全選", icon: "checkmark.circle") {
                                scanner.selectAllDuplicates()
                            }
                            
                            ModernSecondaryButton("取消全選", icon: "xmark.circle") {
                                scanner.deselectAllDuplicates()
                            }
                            
                            ModernSecondaryButton("自動選擇", icon: "star.fill") {
                                scanner.autoSelectForDeletion()
                            }
                            
                            if scanner.hasAnySelection {
                                ModernSecondaryButton("刪除選中", icon: "trash") {
                                    filesToDelete = scanner.allSelectedFiles
                                    showingDeleteAlert = true
                                }
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        
                        // 選擇摘要
                        SelectionSummaryView(scanner: scanner)
                            .padding(.horizontal)
                    }
                    
                    List {
                        ForEach($scanner.duplicateGroups) { $group in
                            Section {
                                ForEach($group.files) { $file in
                                    DuplicateFileRow(
                                        file: file,
                                        isSelected: file.isSelected,
                                        isSuggested: file.id == group.suggestedKeepFile?.id,
                                        onToggleSelection: {
                                            file.isSelected.toggle()
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
                                    
                                    Button(group.allSelected ? "取消全選" : "全選群組") {
                                        group.toggleAllSelection()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    
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
        } detail: {
            // 詳細資訊面板
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
        .errorAlert()
    }
}

struct DuplicateFileRow: View {
    let file: ImageFile
    let isSelected: Bool
    let isSuggested: Bool
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 選擇框
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // 縮圖
            AsyncImage(url: file.url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 檔案資訊
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(file.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if isSuggested {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                Text(file.url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(file.fileSizeFormatted)
                    Text("•")
                    Text(file.imageSizeFormatted)
                    Text("•")
                    Text(file.creationDateFormatted)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("刪除") {
                onDelete()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct FileDetailView: View {
    let file: ImageFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 大圖預覽
            AsyncImage(url: file.url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(maxWidth: .infinity, maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 檔案詳細資訊
            VStack(alignment: .leading, spacing: 15) {
                Text("檔案資訊")
                    .font(.headline)
                
                InfoRow(label: "檔案名稱", value: file.fileName)
                InfoRow(label: "檔案路徑", value: file.url.path)
                InfoRow(label: "檔案大小", value: file.fileSizeFormatted)
                InfoRow(label: "圖片尺寸", value: file.imageSizeFormatted)
                InfoRow(label: "建立日期", value: file.creationDateFormatted)
                InfoRow(label: "修改日期", value: file.modificationDateFormatted)
                InfoRow(label: "選擇狀態", value: file.isSelected ? "已選中" : "未選中")
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("檔案詳細資訊")
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.body)
                .lineLimit(nil)
            
            Spacer()
        }
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    let content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        content = ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ContentView()
}
