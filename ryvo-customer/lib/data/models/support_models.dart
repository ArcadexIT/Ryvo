class SupportTicket {
  SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.category,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
    this.jobId,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        ticketNumber: json['ticketNumber'] as String? ?? '',
        category: json['category'] as String? ?? 'general',
        subject: json['subject'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        priority: json['priority'] as String? ?? 'medium',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        jobId: json['jobId'] as String?,
      );

  final String id;
  final String ticketNumber;
  final String category;
  final String subject;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? jobId;
}

class SupportMessage {
  SupportMessage({
    required this.id,
    required this.message,
    required this.senderType,
    required this.createdAt,
    this.senderName,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return SupportMessage(
      id: json['id'] as String,
      message: json['message'] as String? ?? '',
      senderType: json['senderType'] as String? ?? 'user',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      senderName: sender?['fullName'] as String?,
    );
  }

  final String id;
  final String message;
  final String senderType;
  final DateTime createdAt;
  final String? senderName;

  bool get isFromAdmin => senderType == 'admin';
}

class SupportTicketDetail extends SupportTicket {
  SupportTicketDetail({
    required super.id,
    required super.ticketNumber,
    required super.category,
    required super.subject,
    required super.status,
    required super.priority,
    required super.createdAt,
    super.updatedAt,
    super.jobId,
    this.messages = const [],
    this.jobNumber,
  });

  factory SupportTicketDetail.fromJson(Map<String, dynamic> json) {
    final job = json['job'] as Map<String, dynamic>?;
    final messagesJson = json['messages'] as List<dynamic>? ?? const [];
    return SupportTicketDetail(
      id: json['id'] as String,
      ticketNumber: json['ticketNumber'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      subject: json['subject'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      jobId: json['jobId'] as String? ?? job?['id'] as String?,
      jobNumber: job?['jobNumber'] as String?,
      messages: messagesJson
          .whereType<Map<String, dynamic>>()
          .map(SupportMessage.fromJson)
          .toList(),
    );
  }

  final List<SupportMessage> messages;
  final String? jobNumber;
}

String formatTicketStatus(String status) {
  return switch (status) {
    'open' => 'Open',
    'in_progress' => 'In Progress',
    'resolved' => 'Resolved',
    'closed' => 'Closed',
    _ => status,
  };
}

String formatTicketCategory(String category) {
  return switch (category) {
    'technical' => 'Technical',
    'payment' => 'Payment',
    'job_issue' => 'Job Issue',
    'account' => 'Account',
    'general' => 'General',
    _ => category,
  };
}
