import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/translation_service.dart';
import '../../models/collection.dart';
import 'import_curated_list_screen.dart' as import_curated;
import '../../widgets/genie_app_bar.dart';

class CollectionListScreen extends StatefulWidget {
  const CollectionListScreen({super.key});

  @override
  State<CollectionListScreen> createState() => _CollectionListScreenState();
}

class _CollectionListScreenState extends State<CollectionListScreen> {
  late Future<List<Collection>> _collectionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshCollections();
  }

  void _refreshCollections() {
    setState(() {
      _collectionsFuture = Provider.of<ApiService>(
        context,
        listen: false,
      ).getCollections();
    });
  }

  Future<void> _createCollection() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            TranslationService.translate(context, 'create_collection'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: TranslationService.translate(context, 'name'),
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: TranslationService.translate(
                    context,
                    'description',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(TranslationService.translate(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  try {
                    final apiService = Provider.of<ApiService>(
                      context,
                      listen: false,
                    );
                    await apiService.createCollection(
                      nameController.text,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      _refreshCollections();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: Text(TranslationService.translate(context, 'create')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width <= 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GenieAppBar(
        title: TranslationService.translate(context, 'collections'),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
        automaticallyImplyLeading: false,
        showQuickActions: true,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(TranslationService.translate(context, 'discover')),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const import_curated.ImportCuratedListScreen(),
                ),
              );
              if (result == true) {
                _refreshCollections();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Collection>>(
        future: _collectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Calculate top padding for app bar + status bar
            final topPadding =
                MediaQuery.of(context).padding.top + kToolbarHeight + 24;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                top: topPadding,
                left: 24,
                right: 24,
                bottom: 24,
              ),
              child: Column(
                children: [
                  // Promotional banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withValues(alpha: 0.8),
                          Theme.of(context).primaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          TranslationService.translate(
                            context,
                            'discover_collections_title',
                          ),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          TranslationService.translate(
                            context,
                            'discover_collections_subtitle',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const import_curated.ImportCuratedListScreen(),
                              ),
                            );
                            if (result == true) {
                              _refreshCollections();
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                          child: Text(
                            TranslationService.translate(
                              context,
                              'explore_collections',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Empty state
                  const Icon(
                    Icons.collections_bookmark,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    TranslationService.translate(context, 'no_collections'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TranslationService.translate(
                      context,
                      'create_collection_hint',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final collections = snapshot.data!;
          final topPadding =
              MediaQuery.of(context).padding.top + kToolbarHeight;
          return ListView.builder(
            padding: EdgeInsets.only(top: topPadding + 8, bottom: 80),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      context.push(
                        '/collections/${collection.id}',
                        extra: collection,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Collection Icon / Avatar
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade700,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.folder_special,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  collection.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (collection.description != null &&
                                    collection.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    collection.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${collection.totalBooks} ${TranslationService.translate(context, "books")}',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Actions
                          MenuAnchor(
                            builder:
                                (
                                  BuildContext context,
                                  MenuController controller,
                                  Widget? child,
                                ) {
                                  return IconButton(
                                    onPressed: () {
                                      if (controller.isOpen) {
                                        controller.close();
                                      } else {
                                        controller.open();
                                      }
                                    },
                                    icon: const Icon(Icons.more_vert),
                                    tooltip: 'Options',
                                  );
                                },
                            menuChildren: [
                              MenuItemButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        TranslationService.translate(
                                          context,
                                          'confirm_delete',
                                        ),
                                      ),
                                      content: Text(
                                        TranslationService.translate(
                                          context,
                                          'delete_collection_confirm',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(
                                            TranslationService.translate(
                                              context,
                                              'cancel',
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: Text(
                                            TranslationService.translate(
                                              context,
                                              'delete',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && context.mounted) {
                                    try {
                                      await Provider.of<ApiService>(
                                        context,
                                        listen: false,
                                      ).deleteCollection(collection.id);
                                      _refreshCollections();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                                leadingIcon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                child: Text(
                                  TranslationService.translate(
                                    context,
                                    'delete',
                                  ),
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCollection,
        child: const Icon(Icons.add),
      ),
    );
  }
}
