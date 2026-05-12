import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'restart.dart';
import 'package:provider/provider.dart';
import 'theme_controller.dart';
import 'package:lifelens/shared_widgets/mini_me_profile_icon.dart';
import 'package:lifelens/services/tracking_reminder_service.dart';
import 'dev_test_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  String? _notificationPreferenceUserId;
  String? _profileStreamUserId;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userProfileStream(
    String userId,
  ) {
    if (_profileStreamUserId != userId || _profileStream == null) {
      _profileStreamUserId = userId;
      _profileStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots();
    }
    return _profileStream!;
  }

  String _normalizeUsername(String input) {
    var value = input.trim();
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value;
  }

  String _usernameLookupKey(String input) {
    return _normalizeUsername(input).toLowerCase();
  }

  bool _isValidUsername(String input) {
    return RegExp(r'^[A-Za-z0-9_.]{3,24}$').hasMatch(_normalizeUsername(input));
  }

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    if (_notificationPreferenceUserId == userId) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && mounted) {
        final enabled = doc.data()?['notificationsEnabled'] ?? true;
        await TrackingReminderService.instance.setNotificationsEnabled(enabled);
        _notificationPreferenceUserId = userId;
        if (_notificationsEnabled != enabled) {
          setState(() {
            _notificationsEnabled = enabled;
          });
        }
      }
    } catch (e) {
      // Ignore error, use default value
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _notificationsEnabled = value;
    });

    await TrackingReminderService.instance.setNotificationsEnabled(value);

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'notificationsEnabled': value,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating notifications: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDarkMode = context.select<ThemeController, bool>(
      (controller) => controller.isDarkMode,
    );
    final userId = user?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.transparent,
                      child: MiniMeProfileIcon(
                        size: 88,
                        padding: 7,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        borderColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),

                    const SizedBox(height: 13),
                    if (userId == null)
                      Text(
                        _headerDisplayNameFor(user),
                        style: theme.textTheme.titleMedium,
                      )
                    else
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _userProfileStream(userId),
                        builder: (context, snapshot) {
                          final profileData = snapshot.data?.data();
                          final headerName = _headerDisplayNameFor(
                            user,
                            profileData: profileData,
                          );
                          return Text(
                            headerName,
                            style: theme.textTheme.titleMedium,
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              _ProfileSection(
                title: 'Account',
                children: [
                  if (userId != null)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _userProfileStream(userId),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        final username = (data?['username'] ?? '')
                            .toString()
                            .trim();
                        final usernameValue = username.isEmpty
                            ? 'Set username'
                            : '@$username';

                        return _ProfileTile(
                          icon: Icons.badge_outlined,
                          label: 'Username',
                          value: usernameValue,
                          onTap: () => _showChangeUsernameDialog(
                            context,
                            currentUsername: username,
                          ),
                        );
                      },
                    ),

                  _ProfileTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user?.email ?? 'Not available',
                  ),

                  _ProfileTile(
                    icon: Icons.lock_outline,
                    label: 'Password',
                    value: '••••••••',
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _ProfileSection(
                title: 'Preferences',
                children: [
                  _ProfileSwitchTile(
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark mode',
                    value: isDarkMode,
                    onChanged: (value) {
                      context.read<ThemeController>().setDarkMode(value);
                    },
                  ),

                  _ProfileSwitchTile(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),

                  _ProfileTile(
                    icon: Icons.security_outlined,
                    label: 'Security',
                    value: 'Manage',
                    onTap: () => _showSecurityDialog(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _ProfileSection(
                title: 'Developer',
                children: [
                  _ProfileTile(
                    icon: Icons.science_outlined,
                    label: 'Pipeline Tests',
                    value: 'Open',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DevTestScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _LogoutButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  RestartWidget.restartApp(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _headerDisplayNameFor(
    User? user, {
    Map<String, dynamic>? profileData,
  }) {
    final firstName = (profileData?['firstName'] ?? '').toString().trim();
    final lastName = (profileData?['lastName'] ?? '').toString().trim();
    final fullName = [
      firstName,
      lastName,
    ].where((value) => value.isNotEmpty).join(' ').trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final displayName = user?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }

    return 'User';
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final screenContext = this.context;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final currentPassword = currentPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (currentPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match')),
                );
                return;
              }

              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _changePassword(
                screenContext,
                currentPassword,
                newPassword,
              );
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showChangeUsernameDialog(
    BuildContext context, {
    required String currentUsername,
  }) {
    final usernameController = TextEditingController(text: currentUsername);
    var saving = false;
    String? inlineError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Change Username'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    enabled: !saving,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      errorText: inlineError,
                      errorMaxLines: 3,
                      helperText: '3-24 chars: letters, numbers, . and _',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final entered = usernameController.text.trim();
                          final newUsernameDisplay = _normalizeUsername(
                            entered,
                          );
                          final normalizedCurrent = _normalizeUsername(
                            currentUsername,
                          );

                          if (!_isValidUsername(entered)) {
                            setDialogState(() {
                              inlineError =
                                  'Use 3-24 letters/numbers and . or _';
                            });
                            return;
                          }

                          if (newUsernameDisplay == normalizedCurrent) {
                            setDialogState(() {
                              inlineError =
                                  'That is already your current username.';
                            });
                            return;
                          }

                          setDialogState(() {
                            inlineError = null;
                            saving = true;
                          });
                          var dialogClosed = false;

                          try {
                            await _changeUsername(
                              newUsernameDisplay,
                            ).timeout(const Duration(seconds: 15));
                            if (!mounted) return;
                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop();
                              dialogClosed = true;
                            }
                          } on TimeoutException {
                            setDialogState(() {
                              saving = false;
                              inlineError =
                                  'Update is taking too long. Please try again.';
                            });
                          } on FirebaseException catch (e) {
                            String message = 'Unable to update username.';
                            if (e.code == 'username-taken') {
                              message = 'That username is already taken.';
                            } else if (e.code == 'username-same') {
                              message =
                                  'That is already your current username.';
                            } else if (e.code == 'permission-denied') {
                              message =
                                  'Permission denied. Deploy latest Firestore rules.';
                            }
                            setDialogState(() {
                              saving = false;
                              inlineError = message;
                            });
                          } catch (_) {
                            setDialogState(() {
                              saving = false;
                              inlineError = 'Unable to update username.';
                            });
                          } finally {
                            if (mounted && !dialogClosed && saving) {
                              setDialogState(() {
                                saving = false;
                              });
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeUsername(String newUsernameDisplay) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'You must be signed in.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final newUsernameLower = _usernameLookupKey(newUsernameDisplay);

    await firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'User profile not found.',
        );
      }

      final userData = userSnap.data() ?? <String, dynamic>{};
      final oldUsernameDisplay = (userData['username'] ?? '').toString().trim();
      final oldUsernameLower =
          (userData['usernameLower'] ?? userData['username'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (oldUsernameDisplay == newUsernameDisplay) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'username-same',
          message: 'That is already your current username.',
        );
      }

      final newUsernameRef = firestore
          .collection('usernames')
          .doc(newUsernameLower);
      final newUsernameSnap = await tx.get(newUsernameRef);
      if (newUsernameSnap.exists) {
        final ownerId = (newUsernameSnap.data()?['uid'] ?? '').toString();
        if (ownerId != uid) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'username-taken',
            message: 'That username is already taken.',
          );
        }
      }

      DocumentSnapshot<Map<String, dynamic>>? oldUsernameSnap;
      DocumentReference<Map<String, dynamic>>? oldUsernameRef;
      if (oldUsernameLower.isNotEmpty && oldUsernameLower != newUsernameLower) {
        oldUsernameRef = firestore
            .collection('usernames')
            .doc(oldUsernameLower);
        oldUsernameSnap = await tx.get(oldUsernameRef);
      }

      tx.set(newUsernameRef, {
        'uid': uid,
        'username': newUsernameDisplay,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (oldUsernameRef != null &&
          oldUsernameSnap != null &&
          oldUsernameSnap.exists) {
        final ownerId = (oldUsernameSnap.data()?['uid'] ?? '').toString();
        if (ownerId == uid) {
          tx.delete(oldUsernameRef);
        }
      }

      tx.update(userRef, {
        'username': newUsernameDisplay,
        'usernameLower': newUsernameLower,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _changePassword(
    BuildContext context,
    String currentPassword,
    String newPassword,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    var loadingShown = false;

    try {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      loadingShown = true;

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);

      if (context.mounted) {
        if (loadingShown && navigator.canPop()) {
          navigator.pop();
          loadingShown = false;
        }
        messenger.showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error changing password';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please log out and log back in before changing password';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please wait a moment and try again.';
      }

      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (loadingShown && navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  void _showSecurityDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage your account security',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Delete Account',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text(
                  'Permanently delete your account and data',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteAccountConfirmation(context);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final passwordController = TextEditingController();
    final screenContext = this.context;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('Delete Account'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action cannot be undone!',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'All your data will be permanently deleted, including:\n• Profile information\n• Mood logs\n• Sphere memberships\n• Messages',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm with your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your password')),
                );
                return;
              }

              Navigator.pop(context);
              await _deleteAccount(screenContext, password);
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    var loadingShown = false;

    try {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      loadingShown = true;

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete user data from Firestore
      final userId = user.uid;
      final firestore = FirebaseFirestore.instance;

      // Delete user document
      await firestore.collection('users').doc(userId).delete();

      // Remove user from all sphere memberships
      final spheres = await firestore.collection('spheres').get();
      for (var sphere in spheres.docs) {
        final memberDoc = sphere.reference.collection('members').doc(userId);
        final memberExists = await memberDoc.get();

        if (memberExists.exists) {
          await memberDoc.delete();
          // Decrement member count
          await sphere.reference.update({
            'memberCount': FieldValue.increment(-1),
          });
        }
      }

      // Delete the Firebase Auth account
      await user.delete();

      // Navigate to login
      if (context.mounted) {
        if (loadingShown && navigator.canPop()) {
          navigator.pop();
          loadingShown = false;
        }
        RestartWidget.restartApp(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error deleting account';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect password';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please log out and log back in before deleting your account';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please wait a moment and try again.';
      }

      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (loadingShown && navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLight = cs.brightness == Brightness.light;
    final background = isLight
        ? Color.alphaBlend(cs.primary.withValues(alpha: 0.055), cs.surface)
        : cs.surfaceContainerHighest.withValues(alpha: 0.48);
    final iconBackground = isLight
        ? cs.primary.withValues(alpha: 0.11)
        : cs.primaryContainer.withValues(alpha: 0.58);
    final borderColor = isLight
        ? cs.primary.withValues(alpha: 0.16)
        : cs.outlineVariant.withValues(alpha: 0.70);
    final foreground = isLight ? cs.primary : cs.onSurface;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.logout_rounded, size: 21, color: foreground),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  'Log out',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: cs.onSurfaceVariant.withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 12),

            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),

            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ProfileSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
