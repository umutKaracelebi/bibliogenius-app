import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import '../theme/app_design.dart';
import '../providers/theme_provider.dart';

class MigrationWizardScreen extends StatefulWidget {
  const MigrationWizardScreen({super.key});

  @override
  State<MigrationWizardScreen> createState() => _MigrationWizardScreenState();
}

class _MigrationWizardScreenState extends State<MigrationWizardScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion & Migration')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppDesign.pageGradientForTheme(themeProvider.themeStyle),
        ),
        child: SafeArea(
          child: _isProcessing
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        'Importer & Agréger',
                        'Ajoutez des livres provenant d\'autres plateformes à votre bibliothèque actuelle.',
                      ),
                      const SizedBox(height: 12),
                      _buildMigrationCard(
                        context,
                        title: 'Gleeph',
                        description:
                            'Importation directe via navigateur intégré.',
                        icon: Icons.auto_awesome,
                        onTap: () => context.push('/settings/gleeph-import'),
                        color: Colors.purple.shade400,
                      ),
                      const SizedBox(height: 12),
                      _buildMigrationCard(
                        context,
                        title: 'Goodreads / Babelio / Autre CSV',
                        description:
                            'Importez un fichier CSV exporté depuis une autre plateforme.',
                        icon: Icons.import_contacts,
                        onTap: () => _handleCsvImport(),
                        color: Colors.orange.shade400,
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        context,
                        'Sauvegarde & Système',
                        'Gérez les sauvegardes complètes de votre base de données.',
                      ),
                      const SizedBox(height: 12),
                      _buildMigrationCard(
                        context,
                        title: 'Exporter une sauvegarde',
                        description:
                            'Créez un fichier JSON contenant toute votre bibliothèque.',
                        icon: Icons.backup,
                        onTap: () => _handleExport(),
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 12),
                      _buildMigrationCard(
                        context,
                        title: 'Restaurer une sauvegarde',
                        description:
                            'ATTENTION : Remplace l\'intégralité des données actuelles.',
                        icon: Icons.restore,
                        onTap: () => _showRestoreWarning(),
                        color: Colors.red.shade400,
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        context,
                        'Organisation',
                        'Gérez la structure de votre bibliothèque.',
                      ),
                      const SizedBox(height: 12),
                      _buildMigrationCard(
                        context,
                        title: 'Gérer les étagères',
                        description:
                            'Renommer ou organiser vos étagères virtuelles.',
                        icon: Icons.folder_special,
                        onTap: () => context.push('/shelves-management'),
                        color: Colors.blue.shade400,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildMigrationCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCsvImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isProcessing = true);

      final file = result.files.first;
      final apiService = Provider.of<ApiService>(context, listen: false);

      final response = kIsWeb
          ? await apiService.importBooks(file.bytes!, filename: file.name)
          : await apiService.importBooks(file.path!);

      if (mounted) {
        setState(() => _isProcessing = false);
        if (response.statusCode == 200) {
          final imported = response.data['imported'];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Succès : $imported livres importés !'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(response.data['error'] ?? 'Échec de l\'importation');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    try {
      setState(() => _isProcessing = true);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.exportData();

      if (kIsWeb) {
        final blob = html.Blob([response.data]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'bibliogenius_backup_${DateTime.now().toIso8601String().split('T')[0]}.json',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final filename =
            'bibliogenius_backup_${DateTime.now().toIso8601String().split('T')[0]}.json';
        final file = io.File('${directory.path}/$filename');
        await file.writeAsBytes(response.data);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Ma sauvegarde BiblioGenius');
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sauvegarde exportée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'export : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRestoreWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Attention : Restauration'),
        content: const Text(
          'La restauration d\'une sauvegarde va ÉCRASER toutes vos données actuelles. Cette action est irréversible. Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleRestore();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmer l\'écrasement'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRestore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isProcessing = true);

      final file = result.files.first;
      List<int> bytes;
      if (kIsWeb) {
        bytes = file.bytes!;
      } else {
        bytes = await io.File(file.path!).readAsBytes();
      }

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.importBackup(bytes);

      if (mounted) {
        setState(() => _isProcessing = false);
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bibliothéque restaurée avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(response.data['error'] ?? 'Échec de la restauration');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de restauration : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
