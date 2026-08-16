import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/models/router.dart' as model;
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/utils/url_parser.dart';

class ManageRoutersScreen extends ConsumerStatefulWidget {
  const ManageRoutersScreen({super.key});

  @override
  ConsumerState<ManageRoutersScreen> createState() =>
      _ManageRoutersScreenState();
}

class _ManageRoutersScreenState extends ConsumerState<ManageRoutersScreen> {
  String? _switchingRouterId;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final List<model.Router> routers = appState.routers;
    final String? selectedId = appState.selectedRouter?.id;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: LuciAppBar(title: l10n.routers, showBack: true),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => appState.loadRouters(),
              child: routers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                        ),
                        Center(
                          child: Text(
                            l10n.noRoutersAdded,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      children: [
                        ...List.generate(routers.length, (index) {
                          final model.Router router = routers[index];
                          final bool isSelected = router.id == selectedId;
                          final bool isSwitching =
                              router.id == _switchingRouterId;
                          String routerTitle;
                          if (isSelected && appState.dashboardData != null) {
                            final boardInfo =
                                appState.dashboardData?['boardInfo']
                                    as Map<String, dynamic>?;
                            final hostname = boardInfo?['hostname']?.toString();
                            routerTitle =
                                (hostname != null && hostname.isNotEmpty)
                                ? hostname
                                : (router.lastKnownHostname ??
                                      router.ipAddress);
                          } else if (router.lastKnownHostname != null &&
                              router.lastKnownHostname!.isNotEmpty) {
                            routerTitle = router.lastKnownHostname!;
                          } else {
                            routerTitle = router.ipAddress;
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: _UnifiedRouterCard(
                              routerTitle: routerTitle,
                              subtitle:
                                  '${router.ipAddress} (${router.username})',
                              isSelected: isSelected,
                              isSwitching: isSwitching,
                              onTap: () async {
                                if (!isSelected && !isSwitching) {
                                  setState(() {
                                    _switchingRouterId = router.id;
                                  });

                                  try {
                                    await appState.selectRouter(
                                      router.id,
                                      context: context,
                                    );
                                    // Fetch dashboard data before navigating
                                    await appState.fetchDashboardData();
                                    if (!context.mounted) return;
                                    // Pop all the way back to MainScreen
                                    Navigator.of(
                                      context,
                                    ).popUntil((route) => route.isFirst);
                                    // Set Dashboard tab as active
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          ref
                                              .read(appStateProvider)
                                              .requestTab(0);
                                        });
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _switchingRouterId = null;
                                      });
                                    }
                                  }
                                }
                              },
                              onDelete: () async {
                                String routerLabel;
                                if (isSelected &&
                                    appState.dashboardData != null) {
                                  final boardInfo =
                                      appState.dashboardData?['boardInfo']
                                          as Map<String, dynamic>?;
                                  final hostname = boardInfo?['hostname']
                                      ?.toString();
                                  routerLabel =
                                      (hostname != null && hostname.isNotEmpty)
                                      ? hostname
                                      : router.ipAddress;
                                } else {
                                  routerLabel = router.ipAddress;
                                }
                                final l10n = AppLocalizations.of(context)!;
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(l10n.removeRouter),
                                    content: Text(
                                      l10n.removeRouterMessage(routerLabel),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(l10n.cancel),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(l10n.remove),
                                      ),
                                    ],
                                  ),
                                );
                                if (!context.mounted) return;
                                if (confirm == true) {
                                  await appState.removeRouter(router.id);
                                }
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 20),
                              label: Text(l10n.addRouter),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 24,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                                elevation: 2,
                              ),
                              onPressed: () async {
                                final ipController = TextEditingController();
                                final userController = TextEditingController(
                                  text: 'root',
                                );
                                final passController = TextEditingController();
                                final formKey = GlobalKey<FormState>();
                                bool obscureText = true;
                                bool isConnecting = false;
                                String? errorMessage;
                                await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setState) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withValues(alpha: 0.95),
                                          shadowColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.10),
                                          insetPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 60,
                                              ), // Make dialog larger
                                          content: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 400,
                                              minWidth: 320,
                                              minHeight: 380,
                                            ),
                                            child: Form(
                                              key: formKey,
                                              child: SingleChildScrollView(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 32,
                                                      ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Builder(
                                                        builder: (context) {
                                                          final l10n = AppLocalizations.of(context)!;
                                                          return TextFormField(
                                                            controller:
                                                                ipController,
                                                            decoration: InputDecoration(
                                                              labelText: l10n.routerAddress,
                                                              border:
                                                                  const OutlineInputBorder(),
                                                              prefixIcon: const Icon(
                                                                Icons
                                                                    .router_outlined,
                                                              ),
                                                              helperText: l10n.routerAddressHelper,
                                                            ),
                                                            validator: (value) {
                                                              if (value == null ||
                                                                  value.isEmpty) {
                                                                return l10n.pleaseEnterRouterAddress;
                                                              }
                                                              final parsed =
                                                                  UrlParser.parse(
                                                                    value,
                                                                  );
                                                              if (!parsed.isValid) {
                                                                return parsed
                                                                        .error ??
                                                                    l10n.invalidAddressFormat;
                                                              }
                                                              return null;
                                                            },
                                                            autofillHints: const [
                                                              AutofillHints.url,
                                                              AutofillHints
                                                                  .username,
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      Builder(
                                                        builder: (context) {
                                                          final l10n = AppLocalizations.of(context)!;
                                                          return TextFormField(
                                                            controller:
                                                                userController,
                                                            decoration: InputDecoration(
                                                              labelText: l10n.username,
                                                              border:
                                                                  const OutlineInputBorder(),
                                                              prefixIcon: const Icon(
                                                                Icons
                                                                    .person_outline,
                                                              ),
                                                              helperText: l10n.usernameHelper,
                                                            ),
                                                            validator: (v) =>
                                                                v == null ||
                                                                    v.isEmpty
                                                                ? l10n.required
                                                                : null,
                                                            autofillHints: const [
                                                              AutofillHints
                                                                  .username,
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      Builder(
                                                        builder: (context) {
                                                          final l10n = AppLocalizations.of(context)!;
                                                          return TextFormField(
                                                            controller:
                                                                passController,
                                                            decoration: InputDecoration(
                                                              labelText: l10n.password,
                                                              border:
                                                                  const OutlineInputBorder(),
                                                              prefixIcon: const Icon(
                                                                Icons.lock_outline,
                                                              ),
                                                              helperText: l10n.passwordHelper,
                                                              suffixIcon: IconButton(
                                                                icon: Icon(
                                                                  obscureText
                                                                      ? Icons
                                                                            .visibility_outlined
                                                                      : Icons
                                                                            .visibility_off_outlined,
                                                                ),
                                                                onPressed: () => setState(
                                                                  () => obscureText =
                                                                      !obscureText,
                                                                ),
                                                                tooltip: obscureText
                                                                    ? l10n.hidePassword
                                                                    : l10n.showPassword,
                                                              ),
                                                            ),
                                                            obscureText:
                                                                obscureText,
                                                            autofillHints: const [
                                                              AutofillHints
                                                                  .password,
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                      if (errorMessage !=
                                                          null) ...[
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                10,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .errorContainer
                                                                    .withValues(
                                                                      alpha: 1,
                                                                    ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .error_outline,
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .onErrorContainer,
                                                              ),
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  errorMessage!,
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .bodyMedium
                                                                      ?.copyWith(
                                                                        color: Theme.of(
                                                                          context,
                                                                        ).colorScheme.onErrorContainer,
                                                                      ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(
                                                        height: 28,
                                                      ),
                                                      SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton(
                                                          onPressed:
                                                              isConnecting
                                                              ? null
                                                              : () async {
                                                                  if (formKey
                                                                      .currentState!
                                                                      .validate()) {
                                                                    final input =
                                                                        ipController
                                                                            .text
                                                                            .trim();
                                                                    final user =
                                                                        userController
                                                                            .text
                                                                            .trim();
                                                                    final pass =
                                                                        passController
                                                                            .text;

                                                                    // Parse the input to extract host, port, and protocol
                                                                    final parsedUrl =
                                                                        UrlParser.parse(
                                                                          input,
                                                                        );

                                                                    if (!parsedUrl
                                                                        .isValid) {
                                                                      final l10n = AppLocalizations.of(context)!;
                                                                      setState(() {
                                                                        errorMessage =
                                                                            parsedUrl.error ??
                                                                            l10n.invalidAddressFormat;
                                                                      });
                                                                      return;
                                                                    }

                                                                    final hostWithPort =
                                                                        parsedUrl
                                                                            .hostWithPort;
                                                                    final useHttps =
                                                                        parsedUrl
                                                                            .useHttps;
                                                                    final id =
                                                                        '$hostWithPort-$user';

                                                                    if (routers.any(
                                                                      (r) =>
                                                                          r.id ==
                                                                          id,
                                                                    )) {
                                                                      final l10n = AppLocalizations.of(context)!;
                                                                      setState(() {
                                                                        errorMessage = l10n.routerAlreadyExists;
                                                                      });
                                                                      return;
                                                                    }

                                                                    // Show connecting state
                                                                    setState(() {
                                                                      errorMessage =
                                                                          null;
                                                                      isConnecting =
                                                                          true;
                                                                    });

                                                                    // Always fetch hostname from router after login
                                                                    try {
                                                                      // Attempt login with the new router's credentials
                                                                      final loginSuccess = await appState.login(
                                                                        hostWithPort,
                                                                        user,
                                                                        pass,
                                                                        useHttps,
                                                                        fromRouter:
                                                                            false,
                                                                        context:
                                                                            context,
                                                                      );
                                                                      if (!loginSuccess) {
                                                                        final l10n = AppLocalizations.of(context)!;
                                                                        setState(() {
                                                                          errorMessage =
                                                                              appState.errorMessage ??
                                                                              l10n.failedToConnectInvalidCredentials;
                                                                          isConnecting =
                                                                              false;
                                                                        });
                                                                        return;
                                                                      }
                                                                      // Do NOT addRouter here; login already adds it if needed
                                                                      if (!context
                                                                          .mounted) {
                                                                        return;
                                                                      }
                                                                      Navigator.pop(
                                                                        context,
                                                                      );
                                                                    } catch (
                                                                      e
                                                                    ) {
                                                                      final l10n = AppLocalizations.of(context)!;
                                                                      setState(() {
                                                                        errorMessage = l10n.failedToConnect(e.toString());
                                                                        isConnecting =
                                                                            false;
                                                                      });
                                                                    } finally {
                                                                      if (mounted) {
                                                                        setState(() {
                                                                          _switchingRouterId =
                                                                              null;
                                                                        });
                                                                      }
                                                                    }
                                                                  }
                                                                },
                                                          style: ElevatedButton.styleFrom(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 18,
                                                                ),
                                                            textStyle:
                                                                const TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    14,
                                                                  ),
                                                            ),
                                                            elevation: 4,
                                                            backgroundColor:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                            foregroundColor:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onPrimary,
                                                          ),
                                                          child: isConnecting
                                                              ? Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 22,
                                                                      height:
                                                                          22,
                                                                      child: CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            3,
                                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                                          Theme.of(
                                                                            context,
                                                                          ).colorScheme.onPrimary,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 12,
                                                                    ),
                                                                    Text(
                                                                      AppLocalizations.of(context)!.connecting,
                                                                    ),
                                                                  ],
                                                                )
                                                              : Builder(
                                                                  builder: (context) {
                                                                    final l10n = AppLocalizations.of(context)!;
                                                                    return Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        const Icon(
                                                                          Icons.add,
                                                                        ),
                                                                        const SizedBox(
                                                                          width: 12,
                                                                        ),
                                                                        Text(l10n.add),
                                                                      ],
                                                                    );
                                                                  },
                                                                ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                                if (!context.mounted) return;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedRouterCard extends StatelessWidget {
  final String routerTitle;
  final String subtitle;
  final bool isSelected;
  final bool isSwitching;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _UnifiedRouterCard({
    required this.routerTitle,
    required this.subtitle,
    required this.isSelected,
    required this.isSwitching,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: isSelected ? 6 : 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.router,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  size: 22,
                  semanticLabel: AppLocalizations.of(context)!.routerIcon,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected && !isSwitching)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Builder(
                    builder: (context) {
                      return Chip(
                        label: Text(AppLocalizations.of(context)!.active),
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                    ),
                    backgroundColor: colorScheme.primary,
                    visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      );
                    },
                  ),
                ),
              if (isSwitching)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              if (onDelete != null)
                Builder(
                  builder: (context) {
                    return IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: AppLocalizations.of(context)!.removeTooltip,
                      onPressed: onDelete,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
