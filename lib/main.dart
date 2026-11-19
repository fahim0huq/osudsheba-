import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'app/app.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Google sign-in is optional; a failure here must never stop the app (and its medicine
  // alarms) from starting.
  try {
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? '429979113631-j8tke7aulp7rg9moli0deu9lmv3fseh5.apps.googleusercontent.com' : null,
      serverClientId: kIsWeb ? null : '429979113631-j8tke7aulp7rg9moli0deu9lmv3fseh5.apps.googleusercontent.com',
    );
  } catch (e) {
    debugPrint('GoogleSignIn init failed: $e');
  }
  
  final storageService = LocalStorageService();
  await storageService.init();
  
  final notificationService = NotificationService.instance;
  try {
    await notificationService.init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }
  // Ask for notification permission only for returning users here. New users are asked
  // when they add their first medicine, when the request makes sense to them, instead
  // of on the very first screen before they know what the app does.
  if (storageService.getSettings()?.onboardingCompleted ?? false) {
    await notificationService.ensurePermissionsRequested();
  }

  // Alarms are (re)built by OsudShebaApp once the signed-in user's medicines have loaded.
  // (Rescheduling here ran before sign-in, always saw an empty list, and cancelled every
  // alarm, including pending snoozes, on each app start.)
  final container = ProviderContainer();
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OsudShebaApp(),
    ),
  );
}
