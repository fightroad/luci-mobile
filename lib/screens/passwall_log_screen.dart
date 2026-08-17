import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/design/luci_design_system.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/widgets/luci_refresh_components.dart';

class PasswallLogScreen extends ConsumerStatefulWidget {
  const PasswallLogScreen({super.key});

  @override
  ConsumerState<PasswallLogScreen> createState() => _PasswallLogScreenState();
}

class _PasswallLogScreenState extends ConsumerState<PasswallLogScreen> {
  final _scrollController = ScrollController();
  String _log = '';
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_busy) return;
    final hadLog = _log.isNotEmpty;
    setState(() {
      _busy = true;
      _error = null;
      if (!hadLog) _loading = true;
    });

    try {
      final text = await ref
          .read(appStateProvider)
          .fetchPasswallLog(context: context);
      if (!mounted) return;
      setState(() {
        _log = text;
        _loading = false;
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _busy = false;
      });
      if (hadLog) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.passwallLogFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(max);
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.passwallClearLogTitle),
        content: Text(l10n.passwallClearLogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.passwallClearLog),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final ok = await ref
        .read(appStateProvider)
        .clearPasswallLog(context: context);
    if (!mounted) return;

    if (!ok) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.passwallClearLogFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _log = '';
      _error = null;
      _busy = false;
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: LuciAppBar(
        title: l10n.passwallLog,
        showBack: true,
        actions: [
          IconButton(
            tooltip: l10n.passwallRefreshLog,
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: l10n.passwallClearLog,
            onPressed: _busy ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _log.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(LuciSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.passwallLogFailed,
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: LuciSpacing.sm),
                          Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: LuciSpacing.md),
                          FilledButton(
                            onPressed: _reload,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  )
                : LuciPullToRefresh(
                    onRefresh: _reload,
                    child: _log.trim().isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.25,
                              ),
                              Center(
                                child: Text(
                                  l10n.passwallLogEmpty,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : SelectionArea(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(LuciSpacing.md),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  _log,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontFamilyFallback: const [
                                      'Roboto Mono',
                                      'Courier New',
                                      'Courier',
                                    ],
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
