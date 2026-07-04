import 'package:flutter/material.dart';
import '../../colors/app_colors.dart';
import '../../spacing/app_spacing.dart';
import '../../typography/app_typography.dart';

/// Design System — Page scaffold with consistent padding
class AppPageLayout extends StatelessWidget {
  const AppPageLayout({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.leading,
    this.padding,
    this.scrollable = true,
    this.fab,
    this.bottomBar,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final Widget? fab;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePaddingH,
            vertical: AppSpacing.pagePaddingV,
          ),
      child: child,
    );

    return Scaffold(
      appBar: title != null
          ? AppBar(title: Text(title!), leading: leading, actions: actions)
          : null,
      body: scrollable
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: body,
            )
          : body,
      floatingActionButton: fab,
      bottomNavigationBar: bottomBar,
    );
  }
}

/// Section header used throughout pages
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTypography.titleMedium),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: AppTypography.labelMedium.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.linkDark
                    : AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Gradient header used on splash/onboarding screens
class AppGradientHeader extends StatelessWidget {
  const AppGradientHeader({super.key, required this.child, this.height = 240});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: child,
    );
  }
}
