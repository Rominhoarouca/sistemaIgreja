import 'package:flutter/material.dart';
import '../../spacing/app_spacing.dart';
import '../../typography/app_typography.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// Design System — Primary Button component
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final height = switch (size) {
      AppButtonSize.sm => AppSpacing.buttonHeightSm,
      AppButtonSize.md => AppSpacing.buttonHeightMd,
      AppButtonSize.lg => AppSpacing.buttonHeightLg,
    };

    final fontSize = switch (size) {
      AppButtonSize.sm => 13.0,
      AppButtonSize.md => 14.0,
      AppButtonSize.lg => 16.0,
    };

    return SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : null,
      child: _buildButton(context, fontSize),
    );
  }

  Widget _buildButton(BuildContext context, double fontSize) {
    return switch (variant) {
      AppButtonVariant.primary => _PrimaryButton(
        label: label,
        onPressed: isLoading ? null : onPressed,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
        fontSize: fontSize,
      ),
      AppButtonVariant.secondary => _SecondaryButton(
        label: label,
        onPressed: isLoading ? null : onPressed,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
        fontSize: fontSize,
      ),
      AppButtonVariant.outline => _OutlineButton(
        label: label,
        onPressed: isLoading ? null : onPressed,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
        fontSize: fontSize,
      ),
      AppButtonVariant.ghost => _GhostButton(
        label: label,
        onPressed: isLoading ? null : onPressed,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
        fontSize: fontSize,
      ),
      AppButtonVariant.danger => _DangerButton(
        label: label,
        onPressed: isLoading ? null : onPressed,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
        fontSize: fontSize,
      ),
    };
  }
}

// ── Private button flavors ────────────────────────────────────────────────────

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.fontSize,
    required this.color,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
  });

  final String label;
  final double fontSize;
  final Color color;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    final text = Text(
      label,
      style: AppTypography.buttonLabel.copyWith(
        fontSize: fontSize,
        color: color,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    // `Flexible` no rótulo: num Row com `mainAxisSize.min`, um filho não
    // flexível é medido sem limite de largura e leva o próprio tamanho
    // natural — então em `Expanded`/`SizedBox` estreito o texto estourava o
    // botão. Flexível, ele cede espaço e corta com "…".
    //
    // Sem LayoutBuilder de propósito: ele não sabe responder dimensões
    // intrínsecas e quebraria AppButton dentro de IntrinsicWidth/DataTable.
    // RenderFlex sabe, inclusive com filho flexível.
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (prefixIcon != null) ...[
          Icon(prefixIcon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: text),
        if (suffixIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(suffixIcon, size: 18, color: color),
        ],
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.fontSize,
    this.onPressed,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
  });

  final String label;
  final double fontSize;
  final VoidCallback? onPressed;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      child: _ButtonContent(
        label: label,
        fontSize: fontSize,
        color: onPressed == null
            ? colorScheme.onSurfaceVariant
            : colorScheme.onPrimary,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.fontSize,
    this.onPressed,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
  });

  final String label;
  final double fontSize;
  final VoidCallback? onPressed;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      child: _ButtonContent(
        label: label,
        fontSize: fontSize,
        color: colorScheme.onSecondaryContainer,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.fontSize,
    this.onPressed,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
  });

  final String label;
  final double fontSize;
  final VoidCallback? onPressed;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      child: _ButtonContent(
        label: label,
        fontSize: fontSize,
        color: colorScheme.primary,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.fontSize,
    this.onPressed,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
  });

  final String label;
  final double fontSize;
  final VoidCallback? onPressed;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: onPressed,
      child: _ButtonContent(
        label: label,
        fontSize: fontSize,
        color: colorScheme.primary,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.fontSize,
    this.onPressed,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
  });

  final String label;
  final double fontSize;
  final VoidCallback? onPressed;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      child: _ButtonContent(
        label: label,
        fontSize: fontSize,
        color: colorScheme.onError,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isLoading: isLoading,
      ),
    );
  }
}
