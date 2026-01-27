import 'package:flutter/material.dart';
import '../widgets/genie_app_bar.dart';
import '../services/translation_service.dart';

class BiblioCityScreen extends StatelessWidget {
  const BiblioCityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GenieAppBar(title: 'BiblioCity', showActions: true),
      body: Stack(
        children: [
          // Placeholder for Isometric View
          _buildIsometricView(context),

          // HUD - Library KPIs
          _buildHUD(),

          // Action Buttons
          _buildActionMenu(),
        ],
      ),
    );
  }

  Widget _buildIsometricView(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade900, Colors.blue.shade700],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance, size: 120, color: Colors.white24),
            const SizedBox(height: 20),
            Text(
              TranslationService.translate(
                context,
                'library_under_construction',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    return Positioned(
      top: 20,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildKPICard(Icons.favorite, '98%', 'Patrons'),
          _buildKPICard(Icons.monetization_on, '1.2k', 'Biblio-Bucks'),
          _buildKPICard(Icons.bolt, 'Level 14', 'Prestige'),
        ],
      ),
    );
  }

  Widget _buildKPICard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu() {
    return Positioned(
      bottom: 40,
      right: 20,
      child: Column(
        children: [
          _buildActionButton(Icons.build, 'Expand'),
          const SizedBox(height: 12),
          _buildActionButton(Icons.groups, 'Patrons'),
          const SizedBox(height: 12),
          _buildActionButton(Icons.settings, 'Manager'),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        FloatingActionButton.small(
          onPressed: () {},
          backgroundColor: Colors.white.withOpacity(0.2),
          elevation: 0,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}
