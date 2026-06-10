import 'package:flutter/material.dart';

import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../core/ui/app_back_button.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(AppStrings.privacyPolicy),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          const _Section(
            title: '1. Data We Collect',
            body:
                'ContextAI collects GPS location data (every 5 minutes while the app is active), '
                'app usage statistics (app names, foreground durations), screen events '
                '(unlock/lock counts, notification counts), and activity recognition data '
                '(walking, driving, stationary states).\n\n'
                'We do not collect the content of your messages, browsing history, '
                'or any personally identifiable financial information.',
          ),
          const _Section(
            title: '2. How We Use Your Data',
            body:
                'Your behavioral data is processed by our machine-learning pipeline to '
                'infer a lifestyle persona (e.g. Early Bird, Athlete, Professional). '
                'This persona is used exclusively to generate personalized event and '
                'activity recommendations. Data is never sold to third parties.',
          ),
          const _Section(
            title: '3. Data Storage',
            body:
                'All data is stored securely in Supabase (PostgreSQL) with row-level '
                'security policies. Raw sensor data is retained for 90 days, after which '
                'it is automatically deleted. Derived persona features are retained for '
                'as long as your account is active.',
          ),
          const _Section(
            title: '4. Third-Party Services',
            body:
                'We use the following third-party services:\n'
                '• Google Places API — to find nearby venues\n'
                '• OpenWeatherMap — to retrieve local weather\n'
                '• Sentry — for anonymized crash reporting\n\n'
                'Each service has its own privacy policy. We share only the minimum '
                'data required for each service to function.',
          ),
          const _Section(
            title: '5. Your Rights',
            body:
                'You may request deletion of all your data at any time from the '
                'Profile screen. You can also pause background data collection '
                'using the tracking toggle. You have the right to access, rectify, '
                'and erase your personal data in accordance with applicable law.',
          ),
          const _Section(
            title: '6. Contact',
            body:
                'For privacy-related questions, contact us at:\n'
                'privacy@contextai.app\n\n'
                'Last updated: June 2026',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'By using ContextAI you agree to this Privacy Policy.',
            style: theme.textTheme.labelSmall?.copyWith(color: secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
