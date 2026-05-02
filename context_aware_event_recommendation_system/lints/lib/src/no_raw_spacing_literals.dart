import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags raw numeric literals in layout constructors.
///
/// Exempt values (no AppSpacing constant needed):
///   0   — zero spacing / no padding
///   1   — hairline border or divider width
///   1.5 — standard Flutter border width
///   2   — drag-handle radius or micro-gap (half of xxs)
///
/// All other literals should use AppSpacing constants:
///   xxs=4  xs=8  sm=12  md=16  lg=24  xl=32  xxl=48
///   borderRadiusSm=8  borderRadius=12  borderRadiusLg=16  pill=999
///
/// To suppress a genuinely intentional value:
///   add `// ignore: no_raw_spacing_literals` on the offending line.
class NoRawSpacingLiterals extends DartLintRule {
  const NoRawSpacingLiterals() : super(code: _code);

  static const _code = LintCode(
    name: 'no_raw_spacing_literals',
    problemMessage: 'Raw number in layout constructor — use an AppSpacing constant.',
    correctionMessage:
        'Replace with AppSpacing.xxs(4), xs(8), sm(12), md(16), lg(24), '
        'xl(32), xxl(48), borderRadius(12), borderRadiusLg(16). '
        'Values 0, 1, 1.5, and 2 are exempt. '
        'Add // ignore: no_raw_spacing_literals for other intentional exceptions.',
  );

  // Exempt: zero, hairline, standard Flutter border (1.5), micro drag-handle gap.
  static bool _isAllowed(num value) =>
      value == 0 || value == 1 || value == 1.5 || value == 2;

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;

      switch (typeName) {
        case 'EdgeInsets':
        case 'SizedBox':
        case 'BorderRadius':
        case 'Radius':
          _checkArgs(node.argumentList.arguments, reporter);
      }
    });
  }

  void _checkArgs(NodeList<Expression> args, ErrorReporter reporter) {
    for (final arg in args) {
      final expr = arg is NamedExpression ? arg.expression : arg;
      if (_isRawNumber(expr)) {
        reporter.atNode(arg, _code);
      }
    }
  }

  bool _isRawNumber(Expression expr) {
    if (expr is IntegerLiteral) {
      return !_isAllowed(expr.value ?? 0);
    }
    if (expr is DoubleLiteral) {
      return !_isAllowed(expr.value);
    }
    return false;
  }
}
