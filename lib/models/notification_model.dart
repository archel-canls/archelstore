class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'saldo' atau 'order'
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(String id, Map<dynamic, dynamic> data) {
    return NotificationModel(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'info',
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }
}