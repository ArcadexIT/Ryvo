import 'package:flutter/material.dart';

class MockData {
  MockData._();

  static const mapStyle = '''[
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
    {"featureType":"landscape","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"water","stylers":[{"color":"#c9e8f5"}]},
    {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffd180"}]}
  ]''';

  static const weeklyEarnings = [120.0, 85.0, 210.0, 145.0, 190.0, 95.0, 127.5];
  static const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const earningsList = [
    {'id': 'tx-001', 'title': 'Jump Start - Sarah M.', 'amount': 45.00, 'date': 'Today, 2:30 PM'},
    {'id': 'tx-002', 'title': 'Jump Start - Mike R.', 'amount': 38.50, 'date': 'Today, 11:15 AM'},
    {'id': 'tx-003', 'title': 'Jump Start - Lisa K.', 'amount': 52.00, 'date': 'Yesterday'},
    {'id': 'tx-004', 'title': 'Jump Start - John D.', 'amount': 41.00, 'date': 'Yesterday'},
    {'id': 'tx-005', 'title': 'Jump Start - Emma W.', 'amount': 47.50, 'date': 'Mar 28'},
  ];

  static const jobHistory = [
    {'id': 'job-001', 'customer': 'Sarah M.', 'type': 'Jump Start', 'amount': 45.00, 'status': 'completed', 'date': 'Today'},
    {'id': 'job-002', 'customer': 'Mike R.', 'type': 'Jump Start', 'amount': 38.50, 'status': 'completed', 'date': 'Today'},
    {'id': 'job-003', 'customer': 'Lisa K.', 'type': 'Jump Start', 'amount': 52.00, 'status': 'completed', 'date': 'Yesterday'},
    {'id': 'job-004', 'customer': 'John D.', 'type': 'Jump Start', 'amount': 41.00, 'status': 'completed', 'date': 'Yesterday'},
    {'id': 'job-005', 'customer': 'Emma W.', 'type': 'Jump Start', 'amount': 47.50, 'status': 'completed', 'date': 'Mar 28'},
    {'id': 'job-006', 'customer': 'Tom B.', 'type': 'Jump Start', 'amount': 44.00, 'status': 'declined', 'date': 'Mar 27'},
    {'id': 'job-007', 'customer': 'Anna P.', 'type': 'Jump Start', 'amount': 39.00, 'status': 'completed', 'date': 'Mar 27'},
    {'id': 'job-008', 'customer': 'Chris L.', 'type': 'Jump Start', 'amount': 50.00, 'status': 'completed', 'date': 'Mar 26'},
    {'id': 'job-009', 'customer': 'Nina S.', 'type': 'Jump Start', 'amount': 42.00, 'status': 'cancelled', 'date': 'Mar 26'},
    {'id': 'job-010', 'customer': 'David H.', 'type': 'Jump Start', 'amount': 46.00, 'status': 'completed', 'date': 'Mar 25'},
  ];

  static const notifications = [
    {'title': 'New job request nearby', 'body': 'Jump Start request 1.2 km away — £45.00', 'time': '2 min ago', 'icon': Icons.work_outline},
    {'title': 'Payment received', 'body': '£40.50 deposited to your wallet', 'time': '1 hour ago', 'icon': Icons.payments_outlined},
    {'title': 'KYC Approved', 'body': 'Your documents have been verified', 'time': 'Yesterday', 'icon': Icons.verified_outlined},
    {'title': 'New 5-star review', 'body': 'Sarah M. rated your service 5 stars', 'time': 'Yesterday', 'icon': Icons.star_outline},
    {'title': 'System update', 'body': 'App version 1.0.1 is available', 'time': '2 days ago', 'icon': Icons.system_update_outlined},
  ];

  static const reviews = [
    {'name': 'Sarah M.', 'rating': 5, 'comment': 'Fast and professional! Got my car started in minutes.', 'date': 'Today'},
    {'name': 'Mike R.', 'rating': 5, 'comment': 'Excellent service, very friendly driver.', 'date': 'Today'},
    {'name': 'Lisa K.', 'rating': 4, 'comment': 'Good service, arrived on time.', 'date': 'Yesterday'},
    {'name': 'John D.', 'rating': 5, 'comment': 'Highly recommend! Saved me on a cold morning.', 'date': 'Yesterday'},
    {'name': 'Emma W.', 'rating': 5, 'comment': 'Quick response and fair pricing.', 'date': 'Mar 28'},
  ];

  static const chatMessages = [
    {'message': 'Hi, I\'m on my way! ETA about 8 minutes.', 'isSent': true, 'time': '2:15 PM', 'status': 'Read'},
    {'message': 'Thank you! I\'m in the parking lot near the entrance.', 'isSent': false, 'time': '2:16 PM', 'status': null},
    {'message': 'Got it, I can see your location. Be there shortly.', 'isSent': true, 'time': '2:17 PM', 'status': 'Delivered'},
    {'message': 'I have a red Toyota Camry.', 'isSent': false, 'time': '2:18 PM', 'status': null},
  ];

  static const faqs = [
    {'q': 'How do I go online and receive jobs?', 'a': 'Toggle the Online switch on the home map screen. When online, you\'ll receive nearby job requests with a countdown timer to accept or decline.'},
    {'q': 'When do I get paid?', 'a': 'Earnings are added to your wallet after each completed job. Pending amounts clear within 24 hours. You can withdraw anytime to your linked bank account.'},
    {'q': 'What documents do I need?', 'a': 'You need a valid Driver\'s License, an identity selfie, and insurance confirmation. Upload them during KYC verification.'},
    {'q': 'How is my rating calculated?', 'a': 'Your rating is the average of all customer reviews after completed jobs. Maintaining a high rating improves your job matching priority.'},
    {'q': 'Can I cancel an accepted job?', 'a': 'Cancelling after acceptance affects your completion rate. Only cancel in genuine emergencies and contact support if needed.'},
  ];
}
