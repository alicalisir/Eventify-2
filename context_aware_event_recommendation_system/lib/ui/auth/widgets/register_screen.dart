import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../../utils/validators.dart';
import '../../core/ui/app_back_button.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_pressable.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/ui/app_text_field.dart';
import '../../core/ui/password_strength_indicator.dart';
import '../providers/auth_provider.dart';

/// Register screen — "Calm Intelligence" design.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      AppSnackbar.show(
        context,
        message: AppStrings.acceptTermsPrompt,
        kind: SnackKind.warning,
      );
      return;
    }
    setState(() => _isLoading = true);
    final success = await ref
        .read(authProvider.notifier)
        .signUp(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      context.goNamed('onboarding');
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
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(AppStrings.createAccountTitle),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Start your\npersonalized journey',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.registerSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _nameController,
                        label: AppStrings.fullName,
                        textInputAction: TextInputAction.next,
                        autofocus: true,
                        validator: Validators.name,
                      ),
                      const SizedBox(height: AppSpacing.md),
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
                        hint: AppStrings.passwordRequirements,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validator: Validators.password,
                        suffixIcon: AppPressable(
                          semanticLabel: 'Toggle password visibility',
                          onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
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
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: PasswordStrengthIndicator(password: _passwordController.text),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _confirmController,
                        label: AppStrings.confirmPassword,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        validator: (v) => Validators.confirmPassword(
                          v,
                          _passwordController.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _TermsCheckbox(
                        value: _agreedToTerms,
                        onChanged: (v) => setState(() => _agreedToTerms = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SafeArea(
                top: false,
                child: AppButton(
                  text: AppStrings.signUp,
                  onPressed: _handleSignUp,
                  isLoading: _isLoading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    // Semantics(excludeSemantics) replaces all descendant nodes so screen
    // readers see one button node with the correct checked state instead of
    // a nested hierarchy that omits toggle status.
    return Semantics(
      checked: value,
      label: value
          ? 'Terms of Service and Privacy Policy, agreed'
          : 'Agree to Terms of Service and Privacy Policy',
      button: true,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: AppPressable(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: value ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: value ? AppColors.primary : theme.dividerColor,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusSm,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check,
                        size: AppSpacing.iconSizeXs,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryText,
                    ),
                    children: const [
                      TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
