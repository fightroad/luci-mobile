import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/l10n/app_localizations.dart';
import 'package:luci_mobile/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:luci_mobile/utils/url_parser.dart';
import 'package:luci_mobile/utils/app_navigation.dart';

/// When true in [RouteSettings.arguments], skip a second auto-login attempt.
const String kLoginSkipAutoLogin = 'skipAutoLogin';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _usernameController = TextEditingController(text: 'root');
  final _passwordController = TextEditingController();
  bool _isCheckingAutoLogin = true;
  bool _passwordVisible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAutoLogin());
    });
  }

  Future<void> _maybeAutoLogin() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    final skipAutoLogin = args is Map && args[kLoginSkipAutoLogin] == true;

    if (skipAutoLogin) {
      // Splash already tried auto-login; show the form with saved device hints.
      if (!mounted) return;
      _prefillFromSavedRouter();
      setState(() {
        _isCheckingAutoLogin = false;
      });
      return;
    }

    unawaited(_tryAutoLogin());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final appState = ref.read(appStateProvider);
    final success = await appState.tryAutoLogin(context: context);
    if (success && mounted) {
      goToMainWithoutTransition(context);
    } else if (mounted) {
      _prefillFromSavedRouter();
      setState(() {
        _isCheckingAutoLogin = false;
      });
    }
  }

  void _prefillFromSavedRouter() {
    final appState = ref.read(appStateProvider);
    final router = appState.selectedRouter ??
        (appState.routers.isNotEmpty ? appState.routers.first : null);
    if (router == null) return;

    if (_ipController.text.trim().isEmpty) {
      _ipController.text = router.useHttps
          ? 'https://${router.ipAddress}'
          : router.ipAddress;
    }
    _usernameController.text = router.username;
    // Leave password empty — session ended; user must confirm credentials.
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
        replaceExistingRouters: true,
        context: context,
      );

      if (success && mounted) {
        goToMainWithoutTransition(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block iOS back-swipe / Android back from revealing Main underneath.
    return PopScope(
      canPop: false,
      child: _buildLoginBody(context),
    );
  }

  Widget _buildLoginBody(BuildContext context) {
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
