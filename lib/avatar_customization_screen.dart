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
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  String? _syncedStoreName;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveName(AvatarStore store, {String? value}) async {
    final nextName = (value ?? _nameController.text).trim();
    final previousName = store.miniMeName;

    await store.setMiniMeName(nextName);
    _syncedStoreName = store.miniMeName;
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
    final store = context.select<AvatarStore, _AvatarCustomizationSelection>(
      (avatarStore) => _AvatarCustomizationSelection.fromStore(avatarStore),
    );
    final storeActions = context.read<AvatarStore>();

    return Scaffold(
      appBar: AppBar(title: const Text("Customize Mini-Me")),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final cs = theme.colorScheme;

            final shouldSyncNameField =
                _syncedStoreName != store.miniMeName &&
                !_nameFocusNode.hasFocus;
            if (shouldSyncNameField) {
              _syncedStoreName = store.miniMeName;
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
                        'Choose a style for your mini-me',
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
                        focusNode: _nameFocusNode,
                        textInputAction: TextInputAction.done,
                        maxLength: 24,
                        decoration: InputDecoration(
                          hintText: 'Enter a name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (value) =>
                            _saveName(storeActions, value: value),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _saveName(storeActions),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Save Name'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_rounded, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Companion Styles',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 480 ? 3 : 2;
                          return GridView.builder(
                            itemCount: miniMeCompanionPresets.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.14,
                                ),
                            itemBuilder: (context, index) {
                              final preset = miniMeCompanionPresets[index];
                              final selected = preset.id == store.companionId;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () =>
                                      storeActions.setCompanionId(preset.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? cs.primaryContainer
                                          : cs.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: selected
                                            ? preset.accentColor
                                            : cs.outlineVariant.withValues(
                                                alpha: 0.45,
                                              ),
                                        width: selected ? 1.6 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                preset.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                            if (selected)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 18,
                                                color: preset.accentColor,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          preset.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                height: 1.25,
                                              ),
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            _ToneDot(color: preset.shellColor),
                                            const SizedBox(width: 6),
                                            _ToneDot(color: preset.shirtColor),
                                            const SizedBox(width: 6),
                                            _ToneDot(color: preset.accentColor),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AvatarCustomizationSelection {
  const _AvatarCustomizationSelection({
    required this.bodyModel,
    required this.hairModel,
    required this.shirtModel,
    required this.bodyWidthScale,
    required this.effectiveBodyWidthScale,
    required this.companionId,
    required this.degradationLevel,
    required this.isMiniMeHatched,
    required this.miniMeName,
    required this.selectedCompanion,
  });

  factory _AvatarCustomizationSelection.fromStore(AvatarStore store) {
    return _AvatarCustomizationSelection(
      bodyModel: store.bodyModel,
      hairModel: store.hairModel,
      shirtModel: store.shirtModel,
      bodyWidthScale: store.bodyWidthScale,
      effectiveBodyWidthScale: store.effectiveBodyWidthScale,
      companionId: store.companionId,
      degradationLevel: store.degradationLevel,
      isMiniMeHatched: store.isMiniMeHatched,
      miniMeName: store.miniMeName,
      selectedCompanion: store.selectedCompanion,
    );
  }

  final String bodyModel;
  final String hairModel;
  final String shirtModel;
  final double bodyWidthScale;
  final double effectiveBodyWidthScale;
  final String companionId;
  final double degradationLevel;
  final bool isMiniMeHatched;
  final String miniMeName;
  final MiniMeCompanionPreset selectedCompanion;

  @override
  bool operator ==(Object other) {
    return other is _AvatarCustomizationSelection &&
        other.bodyModel == bodyModel &&
        other.hairModel == hairModel &&
        other.shirtModel == shirtModel &&
        other.bodyWidthScale == bodyWidthScale &&
        other.effectiveBodyWidthScale == effectiveBodyWidthScale &&
        other.companionId == companionId &&
        other.degradationLevel == degradationLevel &&
        other.isMiniMeHatched == isMiniMeHatched &&
        other.miniMeName == miniMeName &&
        other.selectedCompanion.id == selectedCompanion.id;
  }

  @override
  int get hashCode => Object.hash(
    bodyModel,
    hairModel,
    shirtModel,
    bodyWidthScale,
    effectiveBodyWidthScale,
    companionId,
    degradationLevel,
    isMiniMeHatched,
    miniMeName,
    selectedCompanion.id,
  );
}

class _ToneDot extends StatelessWidget {
  const _ToneDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
    );
  }
}
