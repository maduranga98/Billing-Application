// lib/widgets/error_boundary.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_constants.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final VoidCallback? onReport;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.onRetry,
    this.onReport,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();

    // Set up error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      setState(() {
        _hasError = true;
        _errorDetails = details;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    return widget.child;
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ThemeConstants.spacingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ThemeConstants.radiusXl),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: AppTheme.errorColor,
                ),
              ),

              const SizedBox(height: ThemeConstants.spacingLg),

              // Error title
              Text(
                widget.title ?? 'Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: ThemeConstants.spacingMd),

              // Error subtitle
              Text(
                widget.subtitle ??
                    'We encountered an unexpected error. Please try again.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: ThemeConstants.spacingXl),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.onRetry != null) ...[
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _errorDetails = null;
                        });
                        widget.onRetry!();
                      },
                      child: const Text('Try Again'),
                    ),
                    const SizedBox(width: ThemeConstants.spacingMd),
                  ],

                  OutlinedButton(
                    onPressed: widget.onReport ?? () {},
                    child: const Text('Report Issue'),
                  ),
                ],
              ),

              // Debug info (only in debug mode)
              if (_errorDetails != null) ...[
                const SizedBox(height: ThemeConstants.spacingXl),
                ExpansionTile(
                  title: const Text('Debug Info'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(ThemeConstants.spacingMd),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(ThemeConstants.spacingMd),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(
                            ThemeConstants.radiusSm,
                          ),
                          border: Border.all(color: AppTheme.dividerColor),
                        ),
                        child: Text(
                          _errorDetails!.toString(),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Network error widget
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;

  const NetworkErrorWidget({super.key, this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Network error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThemeConstants.radiusXl),
              ),
              child: Icon(
                Icons.wifi_off,
                size: 40,
                color: AppTheme.warningColor,
              ),
            ),

            const SizedBox(height: ThemeConstants.spacingLg),

            Text(
              'No Internet Connection',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: ThemeConstants.spacingMd),

            Text(
              message ?? 'Please check your connection and try again.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),

            if (onRetry != null) ...[
              const SizedBox(height: ThemeConstants.spacingXl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Loading error widget
class LoadingErrorWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  const LoadingErrorWidget({super.key, this.title, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeConstants.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: AppTheme.warningColor,
            ),

            const SizedBox(height: ThemeConstants.spacingLg),

            Text(
              title ?? 'Loading Failed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: ThemeConstants.spacingMd),

            Text(
              message ?? 'Failed to load data. Please try again.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),

            if (onRetry != null) ...[
              const SizedBox(height: ThemeConstants.spacingXl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Global error handler utility
class GlobalErrorHandler {
  static void init() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log error
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');

      // Report to crash analytics (if implemented)
      // FirebaseCrashlytics.instance.recordFlutterError(details);
    };
  }
}
