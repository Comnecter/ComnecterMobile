import 'dart:async';
import 'package:flutter/material.dart';
import '../services/legal_documents_service.dart';
import 'legal_document_viewer.dart';

/// Shared widget for displaying Privacy Policy and Terms of Service dialogs
/// This ensures consistent content across the app (signup and settings screens)
class LegalDocumentsDialog {
  /// Shows the Privacy Policy dialog
  /// Returns true if the user has viewed the full document (when full document is opened)
  static Future<bool> showPrivacyPolicy(BuildContext context) async {
    final dialogResult = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Effective Date: January 2025',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome to Comnecter, a mobile application designed to help you connect with people nearby using radar technology.',
              ),
              const SizedBox(height: 8),
              const Text(
                'This Privacy Policy explains how we collect, use, and protect your information when you use our app.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Points:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• We collect location data for radar functionality'),
              const Text('• Your data is encrypted and secure'),
              const Text('• Location data is automatically deleted after 30 days'),
              const Text('• You control what information you share'),
              const SizedBox(height: 16),
              const Text(
                'Please read the full Privacy Policy for complete information.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true), // Signal that we want to open full document
            child: const Text('View Full Policy'),
          ),
        ],
      ),
    );
    
    // If user clicked "View Full Policy", open the full document
    if (dialogResult == true && context.mounted) {
      try {
        final content = await LegalDocumentsService.loadPrivacyPolicy();
        if (context.mounted) {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => LegalDocumentViewer(
                title: 'Privacy Policy',
                content: content,
              ),
            ),
          );
          // Return true if document was viewed (result is true, or null/any value means it was opened and closed)
          // If the document viewer was opened, it means the user viewed it
          return result != false; // Only false if explicitly set, otherwise true (including null)
        }
      } catch (e) {
        return false;
      }
    }
    
    // User closed dialog without opening full document
    return false;
  }

  /// Shows the Terms of Service dialog
  /// Returns true if the user has viewed the full document (when full document is opened)
  static Future<bool> showTermsOfService(BuildContext context) async {
    final dialogResult = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terms of Service'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Effective Date: January 2025',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'By downloading, installing, or using the Comnecter mobile application, you agree to be bound by these Terms of Service.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Terms:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• You must be at least 13 years old'),
              const Text('• Use the app respectfully and safely'),
              const Text('• Report inappropriate behavior'),
              const Text('• We may terminate accounts for violations'),
              const SizedBox(height: 16),
              const Text(
                'Please read the full Terms of Service for complete information.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true), // Signal that we want to open full document
            child: const Text('View Full Terms'),
          ),
        ],
      ),
    );
    
    // If user clicked "View Full Terms", open the full document
    if (dialogResult == true && context.mounted) {
      try {
        final content = await LegalDocumentsService.loadTermsOfService();
        if (context.mounted) {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => LegalDocumentViewer(
                title: 'Terms of Service',
                content: content,
              ),
            ),
          );
          // Return true if document was viewed (result is true, or null/any value means it was opened and closed)
          // If the document viewer was opened, it means the user viewed it
          return result != false; // Only false if explicitly set, otherwise true (including null)
        }
      } catch (e) {
        return false;
      }
    }
    
    // User closed dialog without opening full document
    return false;
  }

  /// Shows the full Privacy Policy directly (for settings screen)
  static Future<void> showFullPrivacyPolicy(BuildContext context) async {
    final content = await LegalDocumentsService.loadPrivacyPolicy();
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LegalDocumentViewer(
            title: 'Privacy Policy',
            content: content,
          ),
        ),
      );
    }
  }

  /// Shows the full Terms of Service directly (for settings screen)
  static Future<void> showFullTermsOfService(BuildContext context) async {
    final content = await LegalDocumentsService.loadTermsOfService();
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LegalDocumentViewer(
            title: 'Terms of Service',
            content: content,
          ),
        ),
      );
    }
  }
}

