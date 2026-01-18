import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/audio_webview_screen.dart';
import '../models/audio_resource.dart';
import '../providers/audio_provider.dart';
import 'audio_player_widget.dart';

/// Self-contained audio section widget for book details screen.
///
/// This widget handles all audio-related UI logic:
/// - Checks if audio module is enabled
/// - Triggers audiobook search if needed
/// - Shows appropriate state (searching, not found, WiFi required, player)
///
/// Usage:
/// ```dart
/// // In book_details_screen.dart
/// AudioSection(
///   bookId: book.id!,
///   bookTitle: book.title,
///   bookAuthor: book.author,
/// )
/// ```
///
/// The widget is designed to be dropped into any screen with minimal integration.
class AudioSection extends StatefulWidget {
  final int bookId;
  final String bookTitle;
  final String? bookAuthor;

  /// Language of the book (e.g., 'fr', 'en', 'French', 'English').
  /// Used to filter audiobook results to match the book's language.
  final String? bookLanguage;

  const AudioSection({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.bookAuthor,
    this.bookLanguage,
  });

  @override
  State<AudioSection> createState() => _AudioSectionState();
}

class _AudioSectionState extends State<AudioSection> {
  bool _searchTriggered = false;

  void _triggerSearchIfNeeded(AudioProvider provider) {
    if (_searchTriggered) return;
    if (!provider.isInitialized) return;
    if (!provider.isEnabled) return;
    if (provider.hasSearched(widget.bookId)) return;

    _searchTriggered = true;
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.searchAudiobook(
        bookId: widget.bookId,
        title: widget.bookTitle,
        author: widget.bookAuthor,
        preferredLanguage: widget.bookLanguage,
      );
    });
  }

  void _forceRefresh() {
    final provider = context.read<AudioProvider>();
    provider.clearBookCache(widget.bookId);
    _searchTriggered = false;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.searchAudiobook(
        bookId: widget.bookId,
        title: widget.bookTitle,
        author: widget.bookAuthor,
        preferredLanguage: widget.bookLanguage,
        forceRefresh: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AudioProvider>();

    // debugPrint('[AudioSection] build() - bookId: ${widget.bookId}');
    // debugPrint('[AudioSection]   isEnabled: ${provider.isEnabled}');
    // debugPrint('[AudioSection]   isInitialized: ${provider.isInitialized}');
    // debugPrint('[AudioSection]   isWifiConnected: ${provider.isWifiConnected}');
    // debugPrint(
    //   '[AudioSection]   isSearching: ${provider.isSearching(widget.bookId)}',
    // );
    // debugPrint(
    //   '[AudioSection]   hasSearched: ${provider.hasSearched(widget.bookId)}',
    // );
    // debugPrint(
    //   '[AudioSection]   audioResource: ${provider.getAudioResource(widget.bookId)}',
    // );

    // Don't show anything if module is disabled
    if (!provider.isEnabled) {
      // debugPrint('[AudioSection] -> Hiding: module disabled');
      return const SizedBox.shrink();
    }

    // Wait for initialization
    if (!provider.isInitialized) {
      // debugPrint('[AudioSection] -> Hiding: not initialized');
      return const SizedBox.shrink();
    }

    // Trigger search if not yet done (must be after isInitialized check)
    _triggerSearchIfNeeded(provider);

    // Check if searching
    if (provider.isSearching(widget.bookId)) {
      // debugPrint('[AudioSection] -> Showing: searching state');
      return _buildSearchingState(context);
    }

    // Get cached result
    final audioResource = provider.getAudioResource(widget.bookId);

    // No audiobook found
    if (audioResource == null) {
      // Only show "not found" if we've actually searched
      if (provider.hasSearched(widget.bookId)) {
        // debugPrint('[AudioSection] -> Hiding: searched but not found');
        return const SizedBox.shrink(); // Silently hide if not found
      }
      // debugPrint('[AudioSection] -> Hiding: not yet searched');
      return const SizedBox.shrink();
    }

    // Check WiFi for streaming
    if (!provider.isWifiConnected) {
      // debugPrint('[AudioSection] -> Showing: WiFi required state');
      return _buildWifiRequiredState(context, audioResource);
    }

    // Show player
    // debugPrint('[AudioSection] -> Showing: audio player!');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onLongPress: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Refreshing audiobook search...'),
              action: SnackBarAction(
                label: 'Refresh',
                onPressed: _forceRefresh,
              ),
            ),
          );
        },
        child: AudioPlayerWidget(
          audioResource: audioResource,
          onOpenInBrowser: () => _openInBrowser(audioResource),
        ),
      ),
    );
  }

  Widget _buildSearchingState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Searching for audiobook...',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiRequiredState(
    BuildContext context,
    AudioResource audioResource,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.headphones, size: 18, color: colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Audiobook Available',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                Text(
                  audioResource.source.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onTertiaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.wifi_off,
                  size: 16,
                  color: colorScheme.onTertiaryContainer.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connect to WiFi to stream',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onTertiaryContainer.withOpacity(0.7),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openInBrowser(audioResource),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Open'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openInBrowser(AudioResource resource) {
    // Use the direct stream URL if available, otherwise the source website
    final url = resource.streamUrl?.isNotEmpty == true
        ? resource.streamUrl!
        : resource.source.websiteUrl;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AudioWebViewScreen(url: url, title: resource.title),
      ),
    );
  }
}
