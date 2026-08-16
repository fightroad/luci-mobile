import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import '../design/luci_design_system.dart';

/// Pull-to-refresh with a short haptic when the refresh is triggered.
class LuciPullToRefresh extends StatelessWidget {
  const LuciPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.backgroundColor,
    this.color,
    this.strokeWidth = RefreshProgressIndicator.defaultStrokeWidth,
    this.semanticsLabel,
    this.semanticsValue,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final double displacement;
  final double edgeOffset;
  final Color? backgroundColor;
  final Color? color;
  final double strokeWidth;
  final String? semanticsLabel;
  final String? semanticsValue;
  final RefreshIndicatorTriggerMode triggerMode;
  final ScrollNotificationPredicate notificationPredicate;

  Future<void> _handleRefresh(BuildContext context) async {
    await HapticFeedback.mediumImpact();
    try {
      await onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.refreshFailed(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(LuciSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LuciSpacing.sm),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => _handleRefresh(context),
      displacement: displacement,
      edgeOffset: edgeOffset,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      color: color ?? colorScheme.primary,
      strokeWidth: strokeWidth,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
      triggerMode: triggerMode,
      notificationPredicate: notificationPredicate,
      child: child,
    );
  }
}
