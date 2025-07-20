import Foundation
import SwiftUI

enum AppError: LocalizedError {
    case directoryAccessDenied
    case fileNotFound
    case insufficientPermissions
    case unsupportedImageFormat
    case processingFailed(String)
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .directoryAccessDenied:
            return "無法存取指定目錄，請檢查權限設定"
        case .fileNotFound:
            return "找不到指定檔案"
        case .insufficientPermissions:
            return "權限不足，無法執行此操作"
        case .unsupportedImageFormat:
            return "不支援的圖片格式"
        case .processingFailed(let message):
            return "處理失敗：\(message)"
        case .networkError:
            return "網路連線錯誤"
        case .unknown:
            return "發生未知錯誤"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .directoryAccessDenied:
            return "請在系統偏好設定中授予應用程式完整磁碟存取權限"
        case .fileNotFound:
            return "請確認檔案路徑是否正確"
        case .insufficientPermissions:
            return "請以管理員權限執行應用程式"
        case .unsupportedImageFormat:
            return "請確認圖片格式是否為支援的類型"
        case .processingFailed:
            return "請重試操作，或聯絡技術支援"
        case .networkError:
            return "請檢查網路連線狀態"
        case .unknown:
            return "請重新啟動應用程式"
        }
    }
}

class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var showingErrorAlert = false
    
    private init() {}
    
    func handle(_ error: Error) {
        DispatchQueue.main.async {
            if let appError = error as? AppError {
                self.currentError = appError
            } else {
                self.currentError = .processingFailed(error.localizedDescription)
            }
            self.showingErrorAlert = true
        }
    }
    
    func handle(_ error: AppError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.showingErrorAlert = true
        }
    }
    
    func clearError() {
        currentError = nil
        showingErrorAlert = false
    }
}

struct ErrorAlert: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert("錯誤", isPresented: $errorHandler.showingErrorAlert) {
                Button("確定") {
                    errorHandler.clearError()
                }
            } message: {
                if let error = errorHandler.currentError {
                    VStack(alignment: .leading) {
                        Text(error.errorDescription ?? "")
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
    }
}

extension View {
    func errorAlert() -> some View {
        modifier(ErrorAlert())
    }
} 