import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/screens/dashboard_settings_list_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showReviewerModeResetDialog(BuildContext context, WidgetRef ref) {
    final appState = ref.read(appStateProvider);
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exitReviewerModeTitle),
        content: Text(l10n.exitReviewerModeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await appState.setReviewerMode(false);
              appState.logout();
              if (context.mounted) {
                unawaited(
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false),
                );
              }
            },
            child: Text(l10n.exit),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: LuciAppBar(title: l10n.settings, showBack: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          Builder(
            builder: (context) {
              final appState = ref.watch(appStateProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                    child: Text(
                      l10n.theme,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RadioGroup<ThemeMode>(
                    groupValue: appState.themeMode,
                    onChanged: (mode) {
                      if (mode != null) appState.setThemeMode(mode);
                    },
                    child: Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.systemDefault),
                          value: ThemeMode.system,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.light),
                          value: ThemeMode.light,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.dark),
                          value: ThemeMode.dark,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      l10n.dashboardSettings,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.dashboard_customize,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        l10n.customizeDashboard,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(l10n.customizeDashboardSubtitle),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const DashboardSettingsListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  if (appState.reviewerModeEnabled) ...[
                    const Divider(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        l10n.reviewerMode,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                      ),
                      title: Text(l10n.reviewerModeActive),
                      subtitle: Text(
                        l10n.reviewerModeActiveSubtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: FilledButton.icon(
                        onPressed: () =>
                            _showReviewerModeResetDialog(context, ref),
                        icon: const Icon(Icons.exit_to_app),
                        label: Text(l10n.exitReviewerMode),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onError,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
