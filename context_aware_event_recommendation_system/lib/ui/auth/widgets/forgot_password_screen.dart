import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../../utils/validators.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/ui/app_text_field.dart';
import '../../core/ui/brand_mark.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final success = await ref
        .read(authProvider.notifier)
        .sendPasswordReset(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() => _emailSent = true);
    } else {
      final error = ref.read(authProvider).error;
      AppSnackbar.show(
        context,
        message: error?.userMessage ?? AppStrings.somethingWentWrong,
        kind: SnackKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: _emailSent ? _SuccessView(email: _emailController.text.trim()) : Form(
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
                  AppStrings.forgotPasswordTitle,
                  style: theme.textTheme.displayLarge?.copyWith(fontSize: 30),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.forgotPasswordSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _emailController,
                  label: AppStrings.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  validator: Validators.email,
                  onEditingComplete: _handleSendReset,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  text: AppStrings.sendResetLink,
                  onPressed: _handleSendReset,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.goNamed('login'),
                  child: Text(
                    AppStrings.backToLogin,
                    style: TextStyle(color: secondaryText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: BrandMark(),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Check your inbox',
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'If $email is registered, you\'ll receive a reset link shortly.',
          style: theme.textTheme.bodyLarge?.copyWith(color: secondaryText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        TextButton(
          onPressed: () => context.goNamed('login'),
          child: const Text(AppStrings.backToLogin),
        ),
      ],
    );
  }
}
