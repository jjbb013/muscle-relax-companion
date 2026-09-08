import Foundation
import UserNotifications
import Combine

// MARK: - 备份提醒服务（需求 §5.1.3）
//
// 设置页开关开启后，经本地通知每周提示一次。
// 纯本地通知（UNCalendarNotificationTrigger），无任何网络/同步逻辑；
// 通知文案不含任何健康数据。

@MainActor
final class BackupReminderService: BackupReminderServicing, ObservableObject {

    /// 固定的 pending request identifier，取消/重排都以此定位
    static let identifier = "weekly-backup-reminder"

    private let center = UNUserNotificationCenter.current()

    init() {}

    // MARK: BackupReminderServicing

    /// 已授权直接返回 true；未决定时发起 [.alert, .sound] 授权请求；已拒绝返回 false
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    /// 每周日晚 20:00 触发一次（repeats = true）。
    /// 重复调用安全：先移除旧的 pending request 再排入新的。
    /// 调用方应先确保 requestAuthorizationIfNeeded() 为 true。
    func scheduleWeeklyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])

        let content = UNMutableNotificationContent()
        content.title = "该备份你的身体记录了"
        // 正文不含任何健康数据（§5.1.3），只陈述动作与隐私事实
        content.body = "导出备份只需 10 秒，数据只在你自己手里"
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1   // 周日
        components.hour = 20     // 晚 20:00
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: trigger
        )
        // 添加失败（如未授权）静默忽略，不崩溃；UI 层以授权状态为准
        center.add(request, withCompletionHandler: nil)
    }

    /// 取消每周提醒（设置页关闭开关时调用）
    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
