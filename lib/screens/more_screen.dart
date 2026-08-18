import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/screens/settings_screen.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/design/luci_design_system.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:luci_mobile/config/app_config.dart';
import 'package:luci_mobile/screens/manage_routers_screen.dart';
import 'package:luci_mobile/screens/easytier_screen.dart';
import 'package:luci_mobile/screens/passwall_screen.dart';
import 'package:luci_mobile/utils/http_client_manager.dart';
import 'package:luci_mobile/state/app_state.dart';

class _MoreScreenSection extends StatelessWidget {
  final List<Widget> tiles;

  const _MoreScreenSection({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: LuciSpacing.md,
        vertical: LuciSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: LuciCardStyles.standardRadius,
      ),
      child: Column(
        children: ListTile.divideTiles(context: context, tiles: tiles).toList(),
      ),
    );
  }
}

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  AppState? _appState;
  bool _passwallDetecting = false;
  bool _passwallTried = false;
  String? _passwallTriedRouterId;
  bool _easytierDetecting = false;
  bool _easytierTried = false;
  String? _easytierTriedRouterId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = ref.read(appStateProvider);
    _appState!.onRouterBackOnline = _showRouterBackOnlineMessage;
    _ensurePluginsDetected();
  }

  Future<void> _ensurePluginsDetected() async {
    await Future.wait([
      _ensurePasswallDetected(),
      _ensureEasyTierDetected(),
    ]);
  }

  Future<void> _ensureEasyTierDetected() async {
    final appState = ref.read(appStateProvider);
    if (!appState.isAuthenticated) {
      _easytierTried = false;
      _easytierTriedRouterId = null;
      return;
    }

    final routerId = appState.selectedRouter?.id;
    if (routerId != _easytierTriedRouterId) {
      _easytierTriedRouterId = routerId;
      _easytierTried = false;
    }

    if (appState.easytierInstalled != null ||
        _easytierDetecting ||
        _easytierTried) {
      return;
    }

    _easytierDetecting = true;
    _easytierTried = true;
    try {
      await appState.detectEasyTier(context: mounted ? context : null);
    } finally {
      _easytierDetecting = false;
      if (ref.read(appStateProvider).easytierInstalled == null) {
        _easytierTried = false;
      }
    }
  }

  Future<void> _ensurePasswallDetected() async {
    final appState = ref.read(appStateProvider);
    if (!appState.isAuthenticated) {
      _passwallTried = false;
      _passwallTriedRouterId = null;
      return;
    }

    final routerId = appState.selectedRouter?.id;
    if (routerId != _passwallTriedRouterId) {
      _passwallTriedRouterId = routerId;
      _passwallTried = false;
    }

    if (appState.passwallInstalled != null ||
        _passwallDetecting ||
        _passwallTried) {
      return;
    }

    _passwallDetecting = true;
    _passwallTried = true;
    try {
      await appState.detectPasswall(context: mounted ? context : null);
    } finally {
      _passwallDetecting = false;
    }
  }

  @override
  void dispose() {
    // Clear the callback before calling super.dispose()
    _appState?.onRouterBackOnline = null;
    super.dispose();
  }

  void _showRouterBackOnlineMessage() {
    if (mounted) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      // Dismiss the warning snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return Text(
                      l10n.routerBackOnline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          backgroundColor: colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(
            horizontal: LuciSpacing.lg,
            vertical: LuciSpacing.md,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final appState = ref.read(appStateProvider);
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.logoutTitle),
          content: Text(l10n.logoutMessage),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text(l10n.logout),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await appState.logout();
                await HttpClientManager().clearAcceptedCertificates();
                navigator.pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRebootDialog(BuildContext context) async {
    final appState = ref.read(appStateProvider);
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.rebootRouterTitle),
          content: Text(l10n.rebootRouterMessage),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(l10n.reboot),
              onPressed: () async {
                Navigator.of(context).pop();
                // Show persistent warning snackbar
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.onPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.rebooting,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    duration: const Duration(days: 1), // effectively indefinite
                  ),
                );
                final success = await appState.reboot();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? l10n.rebootCommandSent
                          : l10n.rebootCommandFailed,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    unawaited(
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final l10n = AppLocalizations.of(context)!;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.router, size: 32),
                const SizedBox(width: 12),
                Text(l10n.aboutDialogTitle),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.aboutDialogVersion(info.version)),
                const SizedBox(height: 16),
                Text(l10n.aboutDialogDescription),
                const SizedBox(height: 16),
                Text(l10n.aboutDialogOpenSource),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final url = AppConfig.githubRepositoryUrl;
                    final success = await launchUrlString(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.couldNotOpenRepository),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.githubRepository,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: LuciAppBar(title: l10n.more),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: LuciSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final passwallInstalled = ref.watch(
                  appStateProvider.select((state) => state.passwallInstalled),
                );
                final easytierInstalled = ref.watch(
                  appStateProvider.select((state) => state.easytierInstalled),
                );
                // Re-run when router changes (installed is cleared to null).
                ref.watch(
                  appStateProvider.select((state) => state.selectedRouter?.id),
                );
                if (passwallInstalled == null || easytierInstalled == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _ensurePluginsDetected();
                  });
                }
                final showPlugins =
                    passwallInstalled == true || easytierInstalled == true;
                if (!showPlugins) {
                  return const SizedBox.shrink();
                }
                final tiles = <Widget>[];
                if (passwallInstalled == true) {
                  tiles.add(
                    _buildMoreTile(
                      context,
                      icon: Icons.shield_outlined,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: l10n.passwall,
                      subtitle: l10n.passwallSubtitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PasswallScreen(),
                          ),
                        );
                      },
                    ),
                  );
                }
                if (easytierInstalled == true) {
                  tiles.add(
                    _buildMoreTile(
                      context,
                      icon: Icons.hub_outlined,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: l10n.easytier,
                      subtitle: l10n.easytierSubtitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const EasyTierScreen(),
                          ),
                        );
                      },
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LuciSectionHeader(l10n.plugins),
                    _MoreScreenSection(tiles: tiles),
                  ],
                );
              },
            ),
            LuciSectionHeader(l10n.deviceManagement),
            Builder(
              builder: (context) {
                final isRebooting = ref.watch(
                  appStateProvider.select((state) => state.isRebooting),
                );
                return _MoreScreenSection(
                  tiles: [
                    _buildMoreTile(
                      context,
                      icon: Icons.restart_alt,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: l10n.rebootRouter,
                      subtitle: l10n.rebootRouterSubtitle,
                      onTap: isRebooting
                          ? null
                          : () => _showRebootDialog(context),
                      enabled: !isRebooting,
                      showSpinner: isRebooting,
                    ),
                  ],
                );
              },
            ),
            LuciSectionHeader(l10n.application),
            Builder(
              builder: (context) {
                final routerCount = ref.watch(
                  appStateProvider.select((state) => state.routers.length),
                );
                return _MoreScreenSection(
                  tiles: [
                    _buildMoreTile(
                      context,
                      icon: Icons.router,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: l10n.manageRouters,
                      subtitle: l10n.manageRoutersSubtitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ManageRoutersScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMoreTile(
                      context,
                      icon: Icons.settings_outlined,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: l10n.settings,
                      subtitle: l10n.settingsSubtitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMoreTile(
                      context,
                      icon: Icons.info_outline,
                      iconColor: Theme.of(context).colorScheme.secondary,
                      title: l10n.about,
                      subtitle: l10n.aboutSubtitle,
                      onTap: () => _showAboutDialog(context),
                    ),
                    if (routerCount <= 1)
                      _buildMoreTile(
                        context,
                        icon: Icons.logout,
                        iconColor: Theme.of(context).colorScheme.error,
                        title: l10n.logout,
                        subtitle: l10n.logoutSubtitle,
                        titleColor: Theme.of(context).colorScheme.error,
                        subtitleColor: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.7),
                        onTap: () => _showLogoutDialog(context),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool enabled = true,
    Color? titleColor,
    Color? subtitleColor,
    bool showSpinner = false,
  }) {
    final theme = Theme.of(context);
    // Persistent spinning icon using AnimationController
    Widget spinningIconWidget = Icon(
      icon,
      color: iconColor,
      size: 24,
      semanticLabel: title,
    );
    if (showSpinner) {
      spinningIconWidget = _SpinningIcon(
        icon: icon,
        color: iconColor,
        label: title,
      );
    }
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(10),
          child: spinningIconWidget,
        ),
        title: Text(
          title,
          style: titleColor != null
              ? LuciTextStyles.cardTitle(context).copyWith(color: titleColor)
              : LuciTextStyles.cardTitle(context),
          semanticsLabel: title,
        ),
        subtitle: Text(
          subtitle,
          style: subtitleColor != null
              ? LuciTextStyles.cardSubtitle(
                  context,
                ).copyWith(color: subtitleColor)
              : LuciTextStyles.cardSubtitle(context),
          semanticsLabel: subtitle,
        ),
        enabled: enabled,
        onTap: enabled ? onTap : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LuciSpacing.lg,
          vertical: 10,
        ),
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.04),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        minVerticalPadding: LuciSpacing.md,
        minLeadingWidth: 0,
        visualDensity: VisualDensity.standard,
      ),
    );
  }
}

// Persistent spinning icon widget
class _SpinningIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SpinningIcon({
    required this.icon,
    required this.color,
    required this.label,
  });
  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 6.28319, // 2 * pi
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 24,
            semanticLabel: widget.label,
          ),
        );
      },
    );
  }
}
