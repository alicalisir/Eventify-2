import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../../utils/validators.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_pressable.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/ui/app_text_field.dart';
import '../../core/ui/brand_mark.dart';
import '../providers/auth_provider.dart';

/// Login screen — "Calm Intelligence" design.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      context.goNamed('dashboard');
    } else {
      AppSnackbar.show(
        context,
        message: AppStrings.invalidCredentials,
        kind: SnackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final divider = theme.dividerColor;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BrandMark(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        AppStrings.welcomeBack,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Your context is ready when you are.',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: secondaryText),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        controller: _emailController,
                        label: AppStrings.email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _passwordController,
                        label: AppStrings.password,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        validator: Validators.password,
                        onEditingComplete: _handleSignIn,
                        suffixIcon: AppPressable(
                          semanticLabel: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onTap: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => AppSnackbar.show(
                            context,
                            message: 'Reset link sent to your email',
                            kind: SnackKind.info,
                          ),
                          child: const Text(AppStrings.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        text: AppStrings.signIn,
                        onPressed: _handleSignIn,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(child: Divider(color: divider)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm),
                            child: Text(
                              'OR',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: secondaryText),
                            ),
                          ),
                          Expanded(child: Divider(color: divider)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        text: 'Continue with Apple',
                        leadingIcon: Icons.apple,
                        isOutlined: true,
                        foregroundColor: AppColors.textPrimaryLight,
                        onPressed: () => context.goNamed('dashboard'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New here?',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: secondaryText),
                  ),
                  TextButton(
                    onPressed: () => context.pushNamed('register'),
                    child: const Text(
                      AppStrings.createAccount,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
