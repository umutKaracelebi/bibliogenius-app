import 'package:flutter/material.dart';
import '../models/tag.dart';
import '../utils/app_constants.dart';

/// Widget for displaying tags in a hierarchical tree structure
/// Only shown when [AppConstants.enableHierarchicalTags] is true
class TagTreeView extends StatefulWidget {
  final List<Tag> tags;
  final Set<int> selectedTagIds;
  final Function(Tag) onTagSelected;
  final Function(Tag)? onTagLongPress;
  final bool multiSelect;

  const TagTreeView({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    required this.onTagSelected,
    this.onTagLongPress,
    this.multiSelect = true,
  });

  @override
  State<TagTreeView> createState() => _TagTreeViewState();
}

class _TagTreeViewState extends State<TagTreeView> {
  final Set<int> _expandedNodeIds = {};

  @override
  Widget build(BuildContext context) {
    // If hierarchical tags not enabled, show flat list
    if (!AppConstants.enableHierarchicalTags) {
      return _buildFlatList();
    }

    // Build tree structure from flat list
    final rootTags = _buildTree(widget.tags);

    if (rootTags.isEmpty) {
      return const Center(child: Text('Aucun tag disponible'));
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: rootTags.length,
      itemBuilder: (context, index) => _buildTreeNode(rootTags[index], 0),
    );
  }

  /// Build tree structure from flat list with parent_id
  List<Tag> _buildTree(List<Tag> flatTags) {
    final Map<int, Tag> tagMap = {};
    final List<Tag> rootTags = [];

    // First pass: create map of all tags
    for (final tag in flatTags) {
      tagMap[tag.id] = tag;
    }

    // Second pass: build tree by assigning children
    for (final tag in flatTags) {
      if (tag.parentId == null) {
        // Root tag - add to root list with children
        final children = flatTags
            .where((t) => t.parentId == tag.id)
            .map((t) => _attachChildren(t, flatTags))
            .toList();
        rootTags.add(tag.copyWithChildren(children));
      }
    }

    return rootTags;
  }

  /// Recursively attach children to a tag
  Tag _attachChildren(Tag tag, List<Tag> allTags) {
    final children = allTags
        .where((t) => t.parentId == tag.id)
        .map((t) => _attachChildren(t, allTags))
        .toList();
    return tag.copyWithChildren(children);
  }

  /// Build a single tree node with expand/collapse
  Widget _buildTreeNode(Tag tag, int depth) {
    final hasChildren = tag.children.isNotEmpty;
    final isExpanded = _expandedNodeIds.contains(tag.id);
    final isSelected = widget.selectedTagIds.contains(tag.id);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onTagSelected(tag),
          onLongPress: widget.onTagLongPress != null
              ? () => widget.onTagLongPress!(tag)
              : null,
          child: Container(
            padding: EdgeInsets.only(
              left: 16.0 + (depth * 24.0),
              right: 16.0,
              top: 12.0,
              bottom: 12.0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withAlpha(25)),
              ),
            ),
            child: Row(
              children: [
                // Expand/collapse button for parents
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedNodeIds.remove(tag.id);
                        } else {
                          _expandedNodeIds.add(tag.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 28),

                // Tag icon
                Icon(
                  hasChildren ? Icons.folder_outlined : Icons.label_outline,
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),

                // Tag name
                Expanded(
                  child: Text(
                    tag.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tag.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // Selection indicator for multiselect
                if (widget.multiSelect && isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Children (if expanded)
        if (hasChildren && isExpanded)
          ...tag.children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  /// Fallback: flat list when hierarchical tags disabled
  Widget _buildFlatList() {
    if (widget.tags.isEmpty) {
      return const Center(child: Text('Aucun tag disponible'));
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.tags.length,
      itemBuilder: (context, index) {
        final tag = widget.tags[index];
        final isSelected = widget.selectedTagIds.contains(tag.id);
        final theme = Theme.of(context);

        return ListTile(
          leading: Icon(
            Icons.label_outline,
            color: isSelected ? theme.colorScheme.primary : null,
          ),
          title: Text(tag.name),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${tag.count}'),
          ),
          selected: isSelected,
          onTap: () => widget.onTagSelected(tag),
          onLongPress: widget.onTagLongPress != null
              ? () => widget.onTagLongPress!(tag)
              : null,
        );
      },
    );
  }
}
