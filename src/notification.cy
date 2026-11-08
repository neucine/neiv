extern c("neiv_notification_show") fn host_show(title: c_str, body: c_str): c_int;

pub enum NotificationError: i32 { denied = 0, invalid_content }

// Queues a permission request and notification. Delivery is controlled by macOS.
pub fn show(title: c_str, body: c_str): void!NotificationError {
    const status = host_show(title, body);
    if status == -2 { throw NotificationError.denied; }
    if status != 0 { throw NotificationError.invalid_content; }
    return;
}
