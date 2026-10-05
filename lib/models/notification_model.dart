class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return NotificationModel(
      id: id,
      type: data['type']?.toString() ?? 'general',
      title: data['title']?.toString() ?? 'Notification',
      message: data['message']?.toString() ?? '',
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : null,
      isRead: data['isRead'] == true,
    );
  }
}