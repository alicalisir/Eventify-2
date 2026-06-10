import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../../utils/validators.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_pressable.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/ui/app_text_field.dart';
import '../../core/ui/brand_mark.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final success = await ref
        .read(authProvider.notifier)
        .updatePassword(_passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      AppSnackbar.show(
        context,
        message: AppStrings.passwordUpdated,
        kind: SnackKind.success,
      );
      // Router redirect handles navigation to dashboard automatically.
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
                  AppStrings.resetPasswordTitle,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.resetPasswordSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _passwordController,
                  label: AppStrings.newPassword,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  validator: Validators.password,
                  suffixIcon: AppPressable(
                    semanticLabel:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    onTap: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _confirmController,
                  label: AppStrings.confirmPassword,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _handleUpdatePassword,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return AppStrings.passwordsDoNotMatch;
                    }
                    return Validators.password(value);
                  },
                  suffixIcon: AppPressable(
                    semanticLabel:
                        _obscureConfirm ? 'Show password' : 'Hide password',
                    onTap: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: secondaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  text: AppStrings.updatePassword,
                  onPressed: _handleUpdatePassword,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
