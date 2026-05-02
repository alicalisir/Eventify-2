import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_raw_spacing_literals.dart';
import 'src/no_raw_text_style_font_size.dart';

PluginBase createPlugin() => _ContextAwareLints();

class _ContextAwareLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        NoRawSpacingLiterals(),
        NoRawTextStyleFontSize(),
      ];
}
