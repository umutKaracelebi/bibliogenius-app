import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom Cache Manager for Book Covers
/// Retains images for 30 days and handles up to 500 images.
class BookCoverCacheManager {
  static const key = 'bookCoversCache';
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: key),
    ),
  );
}

/// A widget that displays a book cover with automatic caching.
///
/// Uses cached_network_image for:
/// - Memory caching (fast re-display)
/// - Disk caching (persistent across sessions)
/// - Placeholder during loading
/// - Error handling with fallback
class CachedBookCover extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedBookCover({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl!,
      cacheManager: BookCoverCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) {
        debugPrint('Error loading image $url: $error');
        return errorWidget ?? _buildFallback();
      },
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.book,
        size: (width != null && height != null)
            ? (width! < height! ? width! * 0.4 : height! * 0.4)
            : 32,
        color: Colors.grey[500],
      ),
    );
  }
}

/// Compact version for list items
class CompactBookCover extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const CompactBookCover({super.key, required this.imageUrl, this.size = 50});

  @override
  Widget build(BuildContext context) {
    return CachedBookCover(
      imageUrl: imageUrl,
      width: size,
      height: size * 1.5,
      borderRadius: BorderRadius.circular(4),
    );
  }
}
