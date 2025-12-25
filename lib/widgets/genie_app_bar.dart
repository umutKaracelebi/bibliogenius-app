import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/theme_provider.dart';
import '../utils/avatars.dart';

class GenieAppBar extends StatelessWidget implements PreferredSizeWidget {
  final dynamic title;
  final String? subtitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const GenieAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

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
    final isSorbonne = themeProvider.themeStyle == 'sorbonne';
    final gradientColors = isSorbonne
        ? [const Color(0xFF1A0F0A), const Color(0xFF2D1810)] // Dark wood
        : [const Color(0xFF667eea), const Color(0xFF764ba2)]; // Blue-purple

    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.auto_awesome, // "Spark" / Magic
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: title is Widget
                ? title
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (displaySubtitle != null && displaySubtitle.isNotEmpty)
                        Text(
                          displaySubtitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
          ),
        ],
      ),
      actions: [
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
                    : Image.network(
                        avatarConfig?.toUrl(size: 32, format: 'png') ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
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
