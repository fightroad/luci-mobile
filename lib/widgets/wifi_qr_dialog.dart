import 'package:flutter/material.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/utils/wifi_qr.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showWifiQrDialog(
  BuildContext context, {
  required WifiQrPayload payload,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (!payload.canGenerate) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.wifiQrUnavailable),
          content: Text(l10n.wifiQrUnavailableMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l10n.wifiQrTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: payload.toWifiString(),
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.wifiQrScanHint(payload.ssid),
              textAlign: TextAlign.center,
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      );
    },
  );
}
