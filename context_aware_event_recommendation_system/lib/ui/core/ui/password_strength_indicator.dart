import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';

/// Password strength indicator widget
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  PasswordStrength _calculateStrength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    if (password.length < 6) return PasswordStrength.weak;
    if (password.length < 10) return PasswordStrength.medium;
    if (password.length >= 10 &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      return PasswordStrength.strong;
    }
    return PasswordStrength.medium;
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.xxs),
          child: LinearProgressIndicator(
            value: strength.value,
            minHeight: 4,
            valueColor: AlwaysStoppedAnimation<Color>(strength.color),
            backgroundColor: Colors.grey[300],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          strength.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: strength.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

enum PasswordStrength {
  none,
  weak,
  medium,
  strong;

  double get value {
    switch (this) {
      case PasswordStrength.none:
        return 0;
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.medium:
        return 0.5;
      case PasswordStrength.strong:
        return 1.0;
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.none:
        return Colors.grey;
      case PasswordStrength.weak:
        return AppColors.error;
      case PasswordStrength.medium:
        return Colors.orange;
      case PasswordStrength.strong:
        return AppColors.success;
    }
  }

  String get label {
    switch (this) {
      case PasswordStrength.none:
        return 'No password';
      case PasswordStrength.weak:
        return 'Weak password';
      case PasswordStrength.medium:
        return 'Medium password';
      case PasswordStrength.strong:
        return 'Strong password';
    }
  }
}
