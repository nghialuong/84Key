//
//  SettingsModels.swift
//  84Key
//
//  Section model for the macOS Settings-style window. Each section maps 1:1 to
//  a sidebar destination and carries its own title, subtitle and SF Symbol.
//

import SwiftUI

/// The sections of the 84Key Settings window, in sidebar order.
enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case input
    case vietnamese
    case smart
    case compatibility
    case system
    case shortcuts
    case advanced
    case about

    var id: String { rawValue }

    /// Sidebar + page title.
    var title: String {
        switch self {
        case .overview:      return "Tổng quan"
        case .input:         return "Nhập liệu"
        case .vietnamese:    return "Gõ tiếng Việt"
        case .smart:         return "Tính năng thông minh"
        case .compatibility: return "Tương thích"
        case .system:        return "Hệ thống"
        case .shortcuts:     return "Phím tắt"
        case .advanced:      return "Nâng cao"
        case .about:         return "Giới thiệu"
        }
    }

    /// Short page subtitle shown under the title.
    var subtitle: String {
        switch self {
        case .overview:      return "Trạng thái 84Key và các tuỳ chọn quan trọng nhất."
        case .input:         return "Chọn kiểu gõ và bảng mã phù hợp với bạn."
        case .vietnamese:    return "Tinh chỉnh cách đặt dấu và gõ tắt tiếng Việt."
        case .smart:         return "Để 84Key tự xử lý những tình huống thường gặp."
        case .compatibility: return "Khắc phục các vấn đề với một số ứng dụng."
        case .system:        return "Khởi động cùng macOS và cách chuyển ngôn ngữ."
        case .shortcuts:     return "Các phím tắt hiện có trong 84Key."
        case .advanced:      return "Quyền riêng tư và công cụ chẩn đoán."
        case .about:         return "Về 84Key, mã nguồn và tác giả."
        }
    }

    /// SF Symbol for the native sidebar `Label`.
    var systemImage: String {
        switch self {
        case .overview:      return "house"
        case .input:         return "keyboard"
        case .vietnamese:    return "character.cursor.ibeam"
        case .smart:         return "sparkles"
        case .compatibility: return "puzzlepiece.extension"
        case .system:        return "gearshape"
        case .shortcuts:     return "command"
        case .advanced:      return "slider.horizontal.3"
        case .about:         return "info.circle"
        }
    }
}

/// Bundle metadata helpers (read-only).
enum Key84Bundle {
    /// Marketing version, e.g. "0.1.0".
    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
