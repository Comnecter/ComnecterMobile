import 'package:flutter/material.dart';

/// Full-screen viewer for legal documents (Terms of Service and Privacy Policy)
class LegalDocumentViewer extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback? onClose;
  final bool markAsViewed;

  const LegalDocumentViewer({
    super.key,
    required this.title,
    required this.content,
    this.onClose,
    this.markAsViewed = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (!didPop) {
          // Intercept the pop and return markAsViewed value
          Navigator.of(context).pop(markAsViewed);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(markAsViewed),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose ?? () => Navigator.of(context).pop(markAsViewed),
              tooltip: 'Close',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _buildFormattedContent(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedContent(ThemeData theme) {
    // Split content into lines and parse markdown-like formatting
    final lines = content.split('\n');
    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Check for headers
      if (trimmedLine.startsWith('# ')) {
        // H1
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Text(
              trimmedLine.substring(2),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      } else if (trimmedLine.startsWith('## ')) {
        // H2
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Text(
              trimmedLine.substring(3),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (trimmedLine.startsWith('### ')) {
        // H3
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              trimmedLine.substring(4),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } else if (trimmedLine.startsWith('- **') || trimmedLine.startsWith('* **')) {
        // Bullet point with bold
        final text = trimmedLine
            .replaceAll(RegExp(r'^[-*]\s*\*\*'), '')
            .replaceAll(RegExp(r'\*\*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: theme.textTheme.bodyLarge),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('* ')) {
        // Regular bullet point
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: theme.textTheme.bodyLarge),
                Expanded(
                  child: _buildTextWithFormatting(
                    trimmedLine.substring(2),
                    theme,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (trimmedLine.startsWith('**') && trimmedLine.endsWith('**') && trimmedLine.length > 4) {
        // Bold text
        final text = trimmedLine.replaceAll('**', '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else {
        // Regular paragraph - handle inline formatting
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: _buildTextWithFormatting(trimmedLine, theme),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildTextWithFormatting(String text, ThemeData theme) {
    // Handle inline bold (**text**)
    if (text.contains('**')) {
      final parts = text.split('**');
      final List<TextSpan> spans = [];
      
      for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 0) {
          // Regular text
          if (parts[i].isNotEmpty) {
            spans.add(TextSpan(
              text: parts[i],
              style: theme.textTheme.bodyLarge,
            ));
          }
        } else {
          // Bold text
          spans.add(TextSpan(
            text: parts[i],
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ));
        }
      }
      
      return RichText(
        text: TextSpan(children: spans),
      );
    }
    
    return Text(
      text,
      style: theme.textTheme.bodyLarge,
    );
  }
}

