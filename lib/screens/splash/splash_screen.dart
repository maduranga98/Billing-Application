// lib/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Progress animation controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Logo animations
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Text animation
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    // Progress animation
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() async {
    // Start logo animation
    await _logoController.forward();

    // Start text animation with delay
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();

    // Start progress animation
    await Future.delayed(const Duration(milliseconds: 500));
    _progressController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo section
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacityAnimation.value,
                          child: Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: _buildLogo(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: ThemeConstants.spacingXl),

                    // App name and tagline
                    AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textOpacityAnimation.value,
                          child: _buildAppInfo(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Bottom section with progress
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(ThemeConstants.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.receipt_long, size: 60, color: Colors.white),
    );
  }

  Widget _buildAppInfo() {
    return Column(
      children: [
        // App name
        Text(
          'LumoraBiz',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
          ),
        ),

        const SizedBox(height: ThemeConstants.spacingSm),

        // Tagline
        Text(
          'Billing Made Simple',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: ThemeConstants.spacingXs),

        // Version
        Text(
          'Version 1.0.0',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.all(ThemeConstants.spacingXl),
      child: Column(
        children: [
          // Loading indicator
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return Column(
                children: [
                  // Progress bar
                  Container(
                    width: 200,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(
                        ThemeConstants.radiusXs,
                      ),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(
                            ThemeConstants.radiusXs,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: ThemeConstants.spacingMd),

                  // Loading text
                  Text(
                    'Loading...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: ThemeConstants.spacingXl),

          // Company info
          Text(
            'Powered by LumoraBiz',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

// Alternative minimal splash screen
class MinimalSplashScreen extends StatelessWidget {
  const MinimalSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(ThemeConstants.radiusLg),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  size: 40,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: ThemeConstants.spacingLg),

              // App name
              Text(
                'LumoraBiz',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: ThemeConstants.spacingXl),

              // Loading indicator
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryBlue,
                  ),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
