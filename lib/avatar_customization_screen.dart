import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                    color: cs.outlineVariant.withOpacity(0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.25),
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
      appBar: AppBar(title: const Text("Customize Avatar")),
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.45),
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
                  'Appearance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _AssetSelector(
                  title: "Body",
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
              final name = asset.isEmpty
                  ? 'None'
                  : asset.split('/').last.replaceAll('.glb', '');
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
                            : cs.outlineVariant.withOpacity(0.45),
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
            'Left = slimmer, right = wider',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
