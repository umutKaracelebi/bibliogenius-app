import 'package:flutter/material.dart';
import '../models/avatar_config.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/translation_service.dart';
import '../services/translation_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarCustomizer extends StatefulWidget {
  final AvatarConfig initialConfig;
  final Function(AvatarConfig) onConfigChanged;

  const AvatarCustomizer({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
  });

  @override
  State<AvatarCustomizer> createState() => _AvatarCustomizerState();
}

class _AvatarCustomizerState extends State<AvatarCustomizer> {
  late AvatarConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  void _updateConfig(AvatarConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    widget.onConfigChanged(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = themeProvider.locale.languageCode;
    final isGenie = _config.style == 'genie';
    final isHuman = [
      'man',
      'woman',
      'boy',
      'girl',
      'grandfather',
      'grandmother',
    ].contains(_config.style);

    return Column(
      children: [
        // Avatar Preview
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: isGenie
                ? Color(
                    int.parse(
                      'FF${_config.genieBackground ?? "fbbf24"}',
                      radix: 16,
                    ),
                  )
                : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: isGenie
                ? Image.asset(
                    'assets/genie_mascot.jpg',
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: _config.toUrl(size: 200, format: 'png'),
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Center(child: Icon(Icons.error)),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Customization Options
        Expanded(
          child: ListView(
            children: [
              // Style Selector (Human vs Genie)
              _buildSection(
                TranslationService.translate(context, 'avatar_style'),
                AvatarOptions.getAvatarStyles(lang),
                _config.style,
                (value) {
                  // Apply preset defaults if available
                  final preset = AvatarOptions.presets[value];
                  if (preset != null) {
                    _updateConfig(preset.copyWith(seed: _config.seed));
                  } else {
                    // Set default mouth to smile for human-like styles
                    final isHumanStyle = [
                      'man',
                      'woman',
                      'boy',
                      'girl',
                      'grandfather',
                      'grandmother',
                      'avataaars',
                    ].contains(value);
                    _updateConfig(
                      _config.copyWith(
                        style: value,
                        mouth: isHumanStyle ? 'smile' : null,
                      ),
                    );
                  }
                },
              ),

              // Genie is a static mascot image - no customization options
              if (isHuman) ...[
                _buildSection(
                  TranslationService.translate(context, 'avatar_expression'),
                  AvatarOptions.getMouthOptions(lang),
                  _config.mouth ?? 'smile',
                  (value) => _updateConfig(_config.copyWith(mouth: value)),
                ),
                _buildSection(
                  TranslationService.translate(context, 'avatar_hair'),
                  AvatarOptions.getHairStyles(lang),
                  _config.hairStyle ?? 'shortFlat',
                  (value) => _updateConfig(_config.copyWith(hairStyle: value)),
                ),
                _buildSection(
                  TranslationService.translate(context, 'avatar_facial_hair'),
                  AvatarOptions.getFacialHairStyles(lang),
                  _config.facialHair ?? 'none',
                  (value) => _updateConfig(_config.copyWith(facialHair: value)),
                ),
                _buildColorSection(
                  TranslationService.translate(context, 'avatar_skin_color'),
                  AvatarOptions.getSkinColors(lang),
                  _config.skinColor ?? 'ffdbb4',
                  (value) => _updateConfig(_config.copyWith(skinColor: value)),
                ),
                _buildColorSection(
                  TranslationService.translate(context, 'avatar_hair_color'),
                  AvatarOptions.hairColors,
                  _config.hairColor ?? '4a312c',
                  (value) => _updateConfig(_config.copyWith(hairColor: value)),
                ),
                _buildSection(
                  TranslationService.translate(context, 'avatar_accessories'),
                  AvatarOptions.getAccessoriesOptions(lang),
                  _config.accessories ?? 'none',
                  (value) =>
                      _updateConfig(_config.copyWith(accessories: value)),
                ),
                _buildSection(
                  TranslationService.translate(context, 'avatar_clothing'),
                  AvatarOptions.getClothingOptions(lang),
                  _config.clothing ?? 'hoodie',
                  (value) => _updateConfig(_config.copyWith(clothing: value)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    String title,
    Map<String, String> options,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.entries.map((entry) {
                final isSelected = entry.key == currentValue;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onChanged(entry.key);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSection(
    String title,
    Map<String, String> colors,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.entries.map((entry) {
                final isSelected = entry.key == currentValue;
                return GestureDetector(
                  onTap: () => onChanged(entry.key),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(int.parse('FF${entry.key}', radix: 16)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
