import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:luci_mobile/config/app_config.dart';
import 'package:luci_mobile/services/secure_storage_service.dart';
import 'package:luci_mobile/utils/url_parser.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _usernameController = TextEditingController(text: 'root');
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isCheckingAutoLogin = true;
  bool _passwordVisible = false;
  late AnimationController _logoAnimController;
  late AnimationController _progressAnimController;
  bool _isActivatingReviewerMode = false;
  @override
  void initState() {
    super.initState();
    _checkReviewerModeAndAutoLogin();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnimController = AnimationController(
      vsync: this,
      duration: AppConfig.reviewerModeActivationDuration,
    );
    _logoAnimController.forward();
  }

  Future<void> _checkReviewerModeAndAutoLogin() async {
    // Check if reviewer mode is enabled
    final secureStorage = SecureStorageService();
    final reviewerModeEnabled = await secureStorage.readValue(
      AppConfig.reviewerModeKey,
    );

    if (reviewerModeEnabled == 'true' && mounted) {
      // Navigate directly to main screen in reviewer mode
      unawaited(Navigator.of(context).pushReplacementNamed('/'));
    } else {
      // Try auto login
      unawaited(_tryAutoLogin());
    }
  }

  void _startReviewerModeActivation() {
    setState(() {
      _isActivatingReviewerMode = true;
    });

    // Start progress animation
    _progressAnimController.forward();

    // Start a timer to check if the user has held for 5 seconds
    Future.delayed(AppConfig.reviewerModeActivationDuration, () {
      if (_isActivatingReviewerMode && mounted) {
        _showReviewerModeDialog();
      }
    });
  }

  void _cancelReviewerModeActivation() {
    setState(() {
      _isActivatingReviewerMode = false;
    });
    // Reset progress animation
    _progressAnimController.reset();
  }

  void _showReviewerModeDialog() {
    final l10n = AppLocalizations.of(context)!;
    _confirmationController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.activateReviewerMode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.reviewerModeDescription),
              const SizedBox(height: 16),
              Text(
                l10n.reviewerModeConfirm,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmationController,
                decoration: InputDecoration(
                  hintText: l10n.typeReviewer,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: _confirmationController.text == 'REVIEWER'
                  ? () {
                      Navigator.of(context).pop();
                      _activateReviewerMode();
                    }
                  : null,
              child: Text(l10n.activate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateReviewerMode() async {
    final appState = ref.read(appStateProvider);
    await appState.setReviewerMode(true);

    if (mounted) {
      unawaited(Navigator.of(context).pushReplacementNamed('/'));
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _logoAnimController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final appState = ref.read(appStateProvider);
    final success = await appState.tryAutoLogin(context: context);
    if (success && mounted) {
      unawaited(Navigator.of(context).pushReplacementNamed('/'));
    } else {
      if (mounted) {
        setState(() {
          _isCheckingAutoLogin = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    if (_formKey.currentState!.validate()) {
      final appState = ref.read(appStateProvider);
      final input = _ipController.text.trim();
      final user = _usernameController.text;
      final pass = _passwordController.text;

      // Parse the input to extract host, port, and protocol
      final parsedUrl = UrlParser.parse(input);

      if (!parsedUrl.isValid) {
        // Show error message
        final l10n = AppLocalizations.of(context)!;
        appState.setError(parsedUrl.error ?? l10n.invalidAddressFormat);
        return;
      }

      // Use the parsed values
      final success = await appState.login(
        parsedUrl.hostWithPort,
        user,
        pass,
        parsedUrl.useHttps,
        fromRouter: false,
        context: context,
      );

      if (success && mounted) {
        unawaited(Navigator.of(context).pushReplacementNamed('/'));
      }
    }
  }

  Future<void> _openGitHubIssues() async {
    final url = AppConfig.githubIssuesUrl;
    final success = await launchUrlString(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (!success && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.couldNotOpenGitHubIssues),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAutoLogin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Modern gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.18),
                  colorScheme.primaryContainer.withValues(alpha: 0.22),
                  colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        GestureDetector(
                          onLongPress: () {
                            _startReviewerModeActivation();
                          },
                          onLongPressUp: () {
                            _cancelReviewerModeActivation();
                          },
                          child: Column(
                            children: [
                              Builder(
                                builder: (context) {
                                  final l10n = AppLocalizations.of(context)!;
                                  return Column(
                                    children: [
                                      Text(
                                        l10n.appTitle,
                                        style: textTheme.headlineLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.appSubtitle,
                                        style: textTheme.titleMedium?.copyWith(
                                          color: colorScheme.onSurface.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l10n.appTagline,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isActivatingReviewerMode
                                    ? Padding(
                                        key: const ValueKey('progress'),
                                        padding: const EdgeInsets.only(top: 24),
                                        child: AnimatedBuilder(
                                          animation: _progressAnimController,
                                          builder: (context, child) {
                                            return Column(
                                              children: [
                                                Builder(
                                                  builder: (context) {
                                                    final l10n = AppLocalizations.of(context)!;
                                                    return Text(
                                                      l10n.holdToActivateReviewerMode,
                                                      style: textTheme.bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                colorScheme.primary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 13,
                                                          ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  width: 280,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    color: colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.4),
                                                    border: Border.all(
                                                      color: colorScheme.outline
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: LinearProgressIndicator(
                                                      value:
                                                          _progressAnimController
                                                              .value,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            colorScheme.primary
                                                                .withValues(
                                                                  alpha: 0.9,
                                                                ),
                                                          ),
                                                      minHeight: 6,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('empty'),
                                        height: 0,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Glassmorphism card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Card(
                              elevation: 8,
                              color: colorScheme.surface.withValues(
                                alpha: 0.85,
                              ),
                              shadowColor: colorScheme.primary.withValues(
                                alpha: 0.10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18.0,
                                  vertical: 16.0,
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Builder(
                                    builder: (context) {
                                      final appState = ref.watch(
                                        appStateProvider,
                                      );
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Builder(
                                            builder: (context) {
                                              final l10n = AppLocalizations.of(context)!;
                                              return Tooltip(
                                                message: l10n.enterRouterAddressTooltip,
                                                child: TextFormField(
                                                  controller: _ipController,
                                                  autofocus: true,
                                                  autofillHints: const [
                                                    AutofillHints.url,
                                                    AutofillHints.username,
                                                  ],
                                                  decoration: InputDecoration(
                                                    labelText: l10n.routerAddress,
                                                    border: const OutlineInputBorder(),
                                                    prefixIcon: const Icon(
                                                      Icons.router_outlined,
                                                    ),
                                                    helperText: l10n.routerAddressHelper,
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return l10n.pleaseEnterRouterAddress;
                                                    }
                                                    final parsed = UrlParser.parse(
                                                      value,
                                                    );
                                                    if (!parsed.isValid) {
                                                      return parsed.error ??
                                                          l10n.invalidAddressFormat;
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          Builder(
                                            builder: (context) {
                                              final l10n = AppLocalizations.of(context)!;
                                              return Tooltip(
                                                message: l10n.enterRouterUsernameTooltip,
                                                child: TextFormField(
                                                  controller: _usernameController,
                                                  autofillHints: const [
                                                    AutofillHints.username,
                                                  ],
                                                  decoration: InputDecoration(
                                                    labelText: l10n.username,
                                                    border: const OutlineInputBorder(),
                                                    prefixIcon: const Icon(
                                                      Icons.person_outline,
                                                    ),
                                                    helperText: l10n.usernameHelper,
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return l10n.pleaseEnterUsername;
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          Builder(
                                            builder: (context) {
                                              final l10n = AppLocalizations.of(context)!;
                                              return Tooltip(
                                                message: l10n.enterRouterPasswordTooltip,
                                                child: TextFormField(
                                                  controller: _passwordController,
                                                  obscureText: !_passwordVisible,
                                                  autofillHints: const [
                                                    AutofillHints.password,
                                                  ],
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
                                                        _passwordVisible
                                                            ? Icons
                                                                  .visibility_outlined
                                                            : Icons
                                                                  .visibility_off_outlined,
                                                      ),
                                                      onPressed: () => setState(
                                                        () => _passwordVisible =
                                                            !_passwordVisible,
                                                      ),
                                                      tooltip: _passwordVisible
                                                          ? l10n.hidePassword
                                                          : l10n.showPassword,
                                                    ),
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.done,
                                                ),
                                              );
                                            },
                                          ),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            child: appState.errorMessage != null
                                                ? Padding(
                                                    key: const ValueKey(
                                                      'error',
                                                    ),
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 12.0,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: colorScheme
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
                                                            Icons.error_outline,
                                                            color: colorScheme
                                                                .onErrorContainer,
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              appState
                                                                  .errorMessage!,
                                                              style: textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                    color: colorScheme
                                                                        .onErrorContainer,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                          const SizedBox(height: 16),
                                          TweenAnimationBuilder<double>(
                                            duration: const Duration(
                                              milliseconds: 100,
                                            ),
                                            tween: Tween<double>(
                                              begin: 1,
                                              end: appState.isLoading
                                                  ? 0.98
                                                  : 1,
                                            ),
                                            builder: (context, scale, child) {
                                              return Transform.scale(
                                                scale: scale,
                                                child: child,
                                              );
                                            },
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: appState.isLoading
                                                    ? null
                                                    : _connect,
                                                style: ElevatedButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 18,
                                                      ),
                                                  textStyle: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  elevation: 4,
                                                  backgroundColor:
                                                      colorScheme.primary,
                                                  foregroundColor:
                                                      colorScheme.onPrimary,
                                                ),
                                                child: appState.isLoading
                                                    ? const SizedBox(
                                                        height: 26,
                                                        width: 26,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 3,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                    :                                                     Builder(
                                                      builder: (context) {
                                                        final l10n = AppLocalizations.of(context)!;
                                                        return Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            const Icon(Icons.login),
                                                            const SizedBox(width: 12),
                                                            Text(l10n.loginConnect),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            return Tooltip(
                              message: l10n.openGitHubIssuesTooltip,
                              child: TextButton(
                                onPressed: _openGitHubIssues,
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                ),
                                child: Text(l10n.needHelp),
                              ),
                            );
                          },
                        ),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final info = snapshot.data!;
                            final l10n = AppLocalizations.of(context)!;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                l10n.version(info.version),
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
