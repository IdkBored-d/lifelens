import 'package:flutter/material.dart';
import 'package:lifelens/models/mini_me_companion.dart';
import 'package:provider/provider.dart';

import 'assets/minime/minime_avatar.dart';
import 'avatar_store.dart';

class AvatarCustomizationScreen extends StatefulWidget {
  const AvatarCustomizationScreen({super.key});

  @override
  State<AvatarCustomizationScreen> createState() =>
      _AvatarCustomizationScreenState();
}

class _AvatarCustomizationScreenState extends State<AvatarCustomizationScreen> {
  List<String> bodyAssets = [];
  List<String> hairAssets = [];
  List<String> shirtAssets = [];
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    // For now, hardcode the assets since manifest loading is not working
    final assets = [
      'lib/assets/minime/body.glb',
      'lib/assets/minime/hair/hair.glb',
      'lib/assets/minime/hair/hair_male.glb',
      'lib/assets/minime/shirts/neck_tie.glb',
      '', // None
    ];
    setState(() {
      bodyAssets = assets
          .where(
            (a) =>
                a.contains('assets/minime/') &&
                a.endsWith('.glb') &&
                !a.contains('/hair/') &&
                !a.contains('/shirts/'),
          )
          .toList();
      hairAssets =
          assets
              .where(
                (a) =>
                    (a.contains('/hair/') && a.endsWith('.glb')) || a.isEmpty,
              )
              .toList()
            ..sort((a, b) => a.isEmpty ? -1 : (b.isEmpty ? 1 : 0));
      shirtAssets =
          assets
              .where(
                (a) =>
                    (a.contains('/shirts/') && a.endsWith('.glb')) || a.isEmpty,
              )
              .toList()
            ..sort((a, b) => a.isEmpty ? -1 : (b.isEmpty ? 1 : 0));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName(AvatarStore store, {String? value}) async {
    final nextName = (value ?? _nameController.text).trim();
    final previousName = store.miniMeName;

    store.setMiniMeName(nextName);
    _nameController.text = store.miniMeName;
    _nameController.selection = TextSelection.fromPosition(
      TextPosition(offset: _nameController.text.length),
    );

    if (store.miniMeName == previousName && nextName.isNotEmpty) {
      return;
    }

    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Name updated',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: cs.onPrimaryContainer,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Name Updated',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${store.miniMeName} is ready.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Nice'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Customize Mini-Me")),
      body: SafeArea(
        child: Consumer<AvatarStore>(
          builder: (context, store, _) {
            final cs = theme.colorScheme;

            if (_nameController.text != store.miniMeName) {
              _nameController.text = store.miniMeName;
              _nameController.selection = TextSelection.fromPosition(
                TextPosition(offset: _nameController.text.length),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primaryContainer.withValues(alpha: 0.88),
                        cs.secondaryContainer.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 260,
                        child: Center(
                          child: MiniMeAvatar(
                            bodyModel: store.bodyModel,
                            hairModel: store.hairModel,
                            shirtModel: store.shirtModel,
                            bodyWidthScale: store.effectiveBodyWidthScale,
                            companionId: store.companionId,
                            degradationLevel: store.degradationLevel,
                            isHatched: store.isMiniMeHatched,
                            size: 248,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        store.miniMeName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick a softer palette, a little crest, and an accessory that fits your Mini-Me.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSecondaryContainer.withValues(
                            alpha: 0.82,
                          ),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.badge_rounded, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Mini-Me Name',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        maxLength: 24,
                        decoration: InputDecoration(
                          hintText: 'Enter a name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (value) => _saveName(store, value: value),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _saveName(store),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Save Name'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Companion',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: miniMeCompanionPresets.map((preset) {
                    final selected = preset.id == store.companionId;
                    return GestureDetector(
                      onTap: () => store.setCompanionId(preset.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 132,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? preset.accentColor
                                : cs.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preset.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Creation State',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              store.isMiniMeHatched
                                  ? '${store.selectedCompanion.name} has been created and appears throughout the UI.'
                                  : 'Keep the Mini-Me in an egg/creation state until onboarding is finished.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: store.isMiniMeHatched
                            ? store.resetHatchState
                            : store.hatchMiniMe,
                        child: Text(
                          store.isMiniMeHatched ? 'Reset Hatch' : 'Hatch',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Style',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _AssetSelector(
                  title: "Palette",
                  assets: bodyAssets,
                  selected: store.bodyModel,
                  onSelected: store.setBodyModel,
                ),
                const SizedBox(height: 14),
                _BodyWidthSlider(
                  value: store.bodyWidthScale,
                  onChanged: store.setBodyWidthScale,
                ),
                const SizedBox(height: 20),
                _AssetSelector(
                  title: "Crest",
                  assets: hairAssets,
                  selected: store.hairModel,
                  onSelected: store.setHairModel,
                ),
                const SizedBox(height: 20),
                _AssetSelector(
                  title: "Accessory",
                  assets: shirtAssets,
                  selected: store.shirtModel,
                  onSelected: store.setShirtModel,
                ),
                const SizedBox(height: 20),
                _DegradationSlider(
                  value: store.degradationLevel,
                  onChanged: store.setDegradationLevel,
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
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (assets.isEmpty)
          Text(
            "No options available",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: assets.map((asset) {
              final isSelected = asset == selected;
              final name = _friendlyAssetName(title, asset);
              return SizedBox(
                width: 120,
                height: 50,
                child: GestureDetector(
                  onTap: () => onSelected(asset),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? cs.primary
                            : cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
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

String _friendlyAssetName(String title, String asset) {
  if (asset.isEmpty) {
    return 'None';
  }

  final key = asset.toLowerCase();
  switch (title) {
    case 'Palette':
      return 'Breeze';
    case 'Crest':
      if (key.contains('male')) {
        return 'Sprout';
      }
      return 'Fluff';
    case 'Accessory':
      if (key.contains('tie')) {
        return 'Ribbon';
      }
      return 'Band';
    default:
      return asset.split('/').last.replaceAll('.glb', '');
  }
}

class _BodyWidthSlider extends StatelessWidget {
  const _BodyWidthSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percent = (value * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Body Shape ($percent%)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Slider(
            value: value,
            min: 0.75,
            max: 1.35,
            divisions: 12,
            label: '$percent%',
            onChanged: onChanged,
          ),
          Text(
            'Left = slimmer, right = rounder',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DegradationSlider extends StatelessWidget {
  const _DegradationSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percent = (value * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Condition / Degradation ($percent%)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Slider(
            value: value,
            min: 0,
            max: 1,
            divisions: 10,
            label: '$percent%',
            onChanged: onChanged,
          ),
          Text(
            'UI-only for now: this controls how worn or polished the Mini Me looks so backend health signals can connect later.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
