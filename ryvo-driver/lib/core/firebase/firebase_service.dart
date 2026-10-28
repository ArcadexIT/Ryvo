import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  bool get _ready => Firebase.apps.isNotEmpty;

  FirebaseAuth? get auth => _ready ? FirebaseAuth.instance : null;
  FirebaseFirestore? get firestore => _ready ? FirebaseFirestore.instance : null;
  FirebaseMessaging? get messaging => _ready ? FirebaseMessaging.instance : null;

  Future<void> requestNotificationPermission() async {
    await messaging?.requestPermission();
  }

  Future<String?> getFcmToken() async {
    return messaging?.getToken();
  }
}
