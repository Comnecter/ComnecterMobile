import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/firebase_service.dart';

class CrashlyticsTestScreen extends StatelessWidget {
  const CrashlyticsTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Crashlytics Test'),
        backgroundColor: Colors.red[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Firebase Crashlytics Test Panel',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Test non-fatal error logging
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseService.instance.logError(
                    'Test non-fatal error',
                    'This is a test error for Crashlytics',
                    StackTrace.current,
                    customKeys: {
                      'test_type': 'non_fatal',
                      'screen': 'crashlytics_test',
                      'timestamp': DateTime.now().toIso8601String(),
                    },
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Non-fatal error logged to Crashlytics'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error logging test error: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Log Non-Fatal Error',
                style: TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test custom event logging
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseService.instance.logCustomEvent(
                    'Crashlytics test button pressed',
                    parameters: {
                      'action': 'test_custom_event',
                      'screen': 'crashlytics_test',
                      'user_action': 'button_press',
                    },
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Custom event logged to Crashlytics'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error logging custom event: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Log Custom Event',
                style: TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test fatal error (DEBUG ONLY)
            if (kDebugMode) ...[
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseService.instance.logFatalError(
                      'Test fatal error',
                      'This is a test fatal error for Crashlytics (DEBUG MODE)',
                      StackTrace.current,
                      customKeys: {
                        'test_type': 'fatal',
                        'screen': 'crashlytics_test',
                        'debug_mode': 'true',
                      },
                    );
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Fatal error logged to Crashlytics'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error logging fatal error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  'Log Fatal Error (DEBUG)',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Test crash (VERY DANGEROUS - DEBUG ONLY)
              ElevatedButton(
                onPressed: () async {
                  // Show warning dialog first
                  final shouldCrash = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('⚠️ WARNING'),
                      content: const Text(
                        'This will intentionally crash the app to test Crashlytics reporting. '
                        'The app will close immediately. Continue?'
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Crash App', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  
                  if (shouldCrash == true) {
                    await FirebaseService.instance.testCrash();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  '💥 Test Crash (DEBUG)',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Test non-fatal and custom events in debug mode\n'
                      '2. Test fatal errors to verify logging\n'
                      '3. Use crash test only if needed (will close app)\n'
                      '4. Check Firebase Console > Crashlytics for reports\n'
                      '5. Reports may take a few minutes to appear',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}