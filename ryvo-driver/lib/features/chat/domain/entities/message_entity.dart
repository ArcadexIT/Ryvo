class MessageEntity {
  final String id;
  final String text;
  final bool isSent;
  final DateTime timestamp;
  final String? deliveryStatus;

  const MessageEntity({
    required this.id,
    required this.text,
    required this.isSent,
    required this.timestamp,
    this.deliveryStatus,
  });
}
