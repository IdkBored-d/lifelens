import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'avatar_store.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class AvatarCustomizationScreen extends StatefulWidget {
  const AvatarCustomizationScreen({super.key});

  @override
  State<AvatarCustomizationScreen> createState() => _AvatarCustomizationScreenState();
}

class _AvatarCustomizationScreenState extends State<AvatarCustomizationScreen> {
  List<String> bodyAssets = [];
  List<String> hairAssets = [];
  List<String> shirtAssets = [];

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    // For now, hardcode the assets since manifest loading is not working
    final assets = [
      'lib/assets/minime/body.glb',
      'lib/assets/minime/hair/shortHair.glb',
      'lib/assets/minime/shirts/basicShirt.glb',
      '', // None
    ];
    setState(() {
      bodyAssets = assets.where((a) =>
        a.contains('assets/minime/') &&
        a.endsWith('.glb') &&
        !a.contains('/hair/') &&
        !a.contains('/shirts/')
      ).toList();
      hairAssets = assets.where((a) => (a.contains('/hair/') && a.endsWith('.glb')) || a.isEmpty).toList()
        ..sort((a, b) => a.isEmpty ? -1 : (b.isEmpty ? 1 : 0));
      shirtAssets = assets.where((a) => (a.contains('/shirts/') && a.endsWith('.glb')) || a.isEmpty).toList()
        ..sort((a, b) => a.isEmpty ? -1 : (b.isEmpty ? 1 : 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Customize Avatar")),
      body: SafeArea(
        child: Consumer<AvatarStore>(
          builder: (context, store, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AssetSelector(
                  title: "Body",
                  assets: bodyAssets,
                  selected: store.bodyModel,
                  onSelected: store.setBodyModel,
                ),
                const SizedBox(height: 20),
                _AssetSelector(
                  title: "Hair",
                  assets: hairAssets,
                  selected: store.hairModel,
                  onSelected: store.setHairModel,
                ),
                const SizedBox(height: 20),
                _AssetSelector(
                  title: "Shirt",
                  assets: shirtAssets,
                  selected: store.shirtModel,
                  onSelected: store.setShirtModel,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssetSelector extends StatelessWidget {
  const _AssetSelector({
    required this.title,
    required this.assets,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> assets;
  final String selected;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (assets.isEmpty)
          Text(
            "No options available",
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          )
        else
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: assets.map((asset) {
            final isSelected = asset == selected;
            final name = asset.isEmpty ? 'None' : asset.split('/').last.replaceAll('.glb', '');
            return SizedBox(
              width: 120,
              height: 50,
              child: GestureDetector(
                onTap: () => onSelected(asset),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? cs.primary : cs.outlineVariant.withOpacity(0.45),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}