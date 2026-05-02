import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags `TextStyle(fontSize: <literal>)` outside the theme definition file.
///
/// Outside `app_theme.dart`, always use a theme text style:
///   theme.textTheme.bodyMedium
///   theme.textTheme.labelSmall?.copyWith(...)
///   GoogleFonts.inter(...)  ← allowed only in app_theme.dart
///
/// To suppress intentionally: add `// ignore: no_raw_text_style_font_size`
/// on the offending line.
class NoRawTextStyleFontSize extends DartLintRule {
  const NoRawTextStyleFontSize() : super(code: _code);

  static const _code = LintCode(
    name: 'no_raw_text_style_font_size',
    problemMessage:
        'Raw fontSize in TextStyle — use a theme text style instead.',
    correctionMessage:
        'Replace with theme.textTheme.bodyMedium (or other scale), '
        'possibly with .copyWith(). Raw fontSize is only allowed in '
        'app_theme.dart. Add // ignore: no_raw_text_style_font_size for '
        'intentional exceptions.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Exempt: the theme definition file where all scale values are declared.
    final path = resolver.path.replaceAll(r'\', '/');
    if (path.contains('/ui/core/themes/app_theme.dart')) return;

    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.type.name2.lexeme != 'TextStyle') return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'fontSize' &&
            _isRawNumber(arg.expression)) {
          reporter.atNode(arg, _code);
        }
      }
    });
  }

  bool _isRawNumber(Expression expr) =>
      expr is IntegerLiteral || expr is DoubleLiteral;
}
