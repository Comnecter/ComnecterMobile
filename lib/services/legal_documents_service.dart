import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for loading legal documents (Terms of Service and Privacy Policy)
class LegalDocumentsService {
  static const String _termsOfServicePath = 'assets/legal/terms_of_service.md';
  static const String _privacyPolicyPath = 'assets/legal/privacy_policy.md';

  /// Loads the Terms of Service markdown file
  static Future<String> loadTermsOfService() async {
    try {
      return await rootBundle.loadString(_termsOfServicePath);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading Terms of Service: $e');
      }
      return 'Error loading Terms of Service. Please contact support.';
    }
  }

  /// Loads the Privacy Policy markdown file
  static Future<String> loadPrivacyPolicy() async {
    try {
      return await rootBundle.loadString(_privacyPolicyPath);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading Privacy Policy: $e');
      }
      return 'Error loading Privacy Policy. Please contact support.';
    }
  }

  /// Converts markdown to plain text with basic formatting
  static String markdownToPlainText(String markdown) {
    // Remove markdown headers (# ## ###)
    String text = markdown.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    
    // Convert bold (**text** or __text__) to plain text
    text = text.replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'__(.*?)__'), r'$1');
    
    // Convert italic (*text* or _text_) to plain text
    text = text.replaceAll(RegExp(r'(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)'), r'$1');
    text = text.replaceAll(RegExp(r'(?<!_)_(?!_)(.*?)(?<!_)_(?!_)'), r'$1');
    
    // Remove markdown links [text](url) to just text
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    
    // Clean up extra whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return text.trim();
  }
}

