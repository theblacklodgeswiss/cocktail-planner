import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Setup Firebase mocks for testing without real Firebase instance
Future<void> setupFirebaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock Firebase Core Platform
  setupFirebaseCoreMocks();

  // Mock Firebase Auth Platform
  setupFirebaseAuthMocks();
  
  // Mock Firestore Platform
  setupFirestoreMocks();
  
  // Now initialize Firebase with the mocked platform channels
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'fake-api-key',
        appId: 'fake-app-id',
        messagingSenderId: 'fake-sender-id',
        projectId: 'fake-project-id',
      ),
    );
  } catch (e) {
    // Already initialized - that's fine
  }
}

void setupFirebaseCoreMocks() {
  const channel = MethodChannel('plugins.flutter.io/firebase_core');
  
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'Firebase#initializeCore') {
      return [
        {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': 'fake-api-key',
            'appId': 'fake-app-id',
            'messagingSenderId': 'fake-sender-id',
            'projectId': 'fake-project-id',
          },
          'pluginConstants': {},
        }
      ];
    }
    if (methodCall.method == 'Firebase#initializeApp') {
      return {
        'name': methodCall.arguments['appName'] ?? '[DEFAULT]',
        'options': methodCall.arguments['options'] ?? {
          'apiKey': 'fake-api-key',
          'appId': 'fake-app-id',
          'messagingSenderId': 'fake-sender-id',
          'projectId': 'fake-project-id',
        },
        'pluginConstants': {},
      };
    }
    return null;
  });
}

void setupFirebaseAuthMocks() {
  const channel = MethodChannel('plugins.flutter.io/firebase_auth');
  
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'Auth#registerIdTokenListener':
        return {
          'user': null, // No user signed in by default
          'token': null,
        };
      case 'Auth#registerAuthStateListener':
        return null;
      case 'Auth#signInAnonymously':
        return {'user': _mockUserData('anonymous-user-id', false, true)};
      case 'Auth#signOut':
        return null;
      case 'Auth#currentUser':
        return null;
      default:
        return null;
    }
  });
}

void setupFirestoreMocks() {
  const channel = MethodChannel('plugins.flutter.io/cloud_firestore');
  
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'Firestore#settings':
        return null;
      case 'Query#addSnapshotListener':
        return {'handle': 0};
      case 'Query#get':
        return {
          'documents': <Map<String, dynamic>>[],
          'metadata': {'isFromCache': false},
        };
      default:
        return null;
    }
  });
}

Map<String, dynamic> _mockUserData(
  String uid,
  bool isAnonymous,
  bool emailVerified,
) {
  return {
    'uid': uid,
    'email': 'test@example.com',
    'isAnonymous': isAnonymous,
    'emailVerified': emailVerified,
    'displayName': 'Test User',
    'photoURL': null,
    'phoneNumber': null,
    'providerData': [],
    'metadata': {
      'creationTimestamp': DateTime.now().millisecondsSinceEpoch,
      'lastSignInTimestamp': DateTime.now().millisecondsSinceEpoch,
    },
  };
}
