import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/theme_provider.dart';
import '../utils/avatars.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GenieAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic title;
  final String? subtitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool showQuickActions; // Show Scanner & Online Search buttons

  const GenieAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.transparent = false,
    this.showQuickActions = false, // Disabled by default to avoid duplicates
  });

  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // Use provided subtitle, or fallback to library name from provider
    final displaySubtitle = subtitle ?? themeProvider.libraryName;

    // Get avatar info
    final avatarConfig = themeProvider.avatarConfig;
    final avatar = availableAvatars.firstWhere(
      (a) => a.id == themeProvider.currentAvatarId,
      orElse: () => availableAvatars.first,
    );

    // Theme-aware gradient - dark wood for Sorbonne, blue-purple for others
    // Theme-aware gradient
    final isSorbonne = themeProvider.themeStyle == 'sorbonne';
    final isDefault = themeProvider.themeStyle == 'default';

    final gradientColors = isSorbonne
        ? [const Color(0xFF1A0F0A), const Color(0xFF2D1810)] // Dark wood
        : isDefault
        ? [
            const Color(0xFF6BB0A9),
            const Color(0xFF5C8C9F),
          ] // Teal Gradient (6bb0a9 -> 5c8c9f)
        : [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
          ]; // Blue-purple (fallback)

    if (transparent) {
      // Use a transparent gradient/color if requested
      // We can just empty the list or use transparent colors
    }

    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: transparent
              ? null
              : LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: transparent ? Colors.transparent : null,
        ),
      ),
      elevation: 0,
      leadingWidth: 40, // Reduce space after hamburger menu
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive breakpoints based on available title width
          final availableWidth = constraints.maxWidth;
          // More aggressive thresholds to hide rather than truncate
          final hideTitle = availableWidth < 120;
          final hideSubtitle = availableWidth < 180;
          final isCompact = availableWidth < 220;

          // Adaptive sizes
          final logoSize = isCompact ? 20.0 : 28.0;
          final titleFontSize = isCompact ? 15.0 : 20.0;
          final subtitleFontSize = isCompact ? 10.0 : 13.0;
          final logoPadding = isCompact ? 4.0 : 6.0;
          final logoRadius = isCompact ? 8.0 : 12.0;
          final spacing = isCompact ? 6.0 : 12.0;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(logoPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(logoRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome, // "Spark" / Magic
                  color: Colors.white,
                  size: logoSize,
                ),
              ),
              // Hide text entirely if space is too tight (don't truncate)
              if (!hideTitle) ...[
                SizedBox(width: spacing),
                Flexible(
                  child: title is Widget
                      ? title
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: titleFontSize,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                            // Hide subtitle on narrower screens
                            if (!hideSubtitle && displaySubtitle.isNotEmpty)
                              Text(
                                displaySubtitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: subtitleFontSize,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                              ),
                          ],
                        ),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        // Quick Action Buttons (Scanner & Online Search) - only when explicitly enabled
        if (showQuickActions) ...[
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            tooltip: 'Scanner ISBN',
            onPressed: () async {
              final isbn = await context.push<String>('/scan');
              if (isbn != null && context.mounted) {
                context.push('/books/add', extra: {'isbn': isbn});
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.travel_explore,
              color: Colors.white,
            ), // Globe + search icon
            tooltip: 'Recherche en ligne',
            onPressed: () => context.push('/search/external'),
          ),
        ],
        if (actions != null) ...actions!,
        // Avatar
        Padding(
          padding: const EdgeInsets.only(right: 16, left: 8),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarConfig?.style == 'genie'
                    ? Color(
                        int.parse(
                          'FF${avatarConfig?.genieBackground ?? "fbbf24"}',
                          radix: 16,
                        ),
                      )
                    : Colors.white,
              ),
              child: ClipOval(
                child: (avatarConfig?.isGenie ?? false)
                    ? Image.asset(
                        avatarConfig?.assetPath ?? 'assets/genie_mascot.jpg',
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl:
                            avatarConfig?.toUrl(size: 32, format: 'png') ?? '',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Image.asset(avatar.assetPath, fit: BoxFit.cover),
                      ),
              ),
            ),
          ),
        ),
      ],
      bottom: bottom,
      centerTitle: false,
      backgroundColor: Colors.transparent, // Required for flexibleSpace to show
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
