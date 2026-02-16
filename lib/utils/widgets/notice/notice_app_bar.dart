import 'package:flutter/material.dart';

/// Shared app bar for notice list (Notice Board) and notice detail screens.
/// Use [title] for the main label; pass [subtitle] for the detail screen's two-line style.
class NoticeAppBar extends StatelessWidget {
  const NoticeAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.padding,
    this.iconContainerShadow = false,
  });

  /// Main title (e.g. "Notice Board" or "Notice").
  final String title;

  /// Optional subtitle for two-line layout (e.g. "View details").
  final String? subtitle;

  /// Custom padding; defaults to list-style padding when null.
  final EdgeInsets? padding;

  /// Whether to show shadow on the campaign icon container (detail screen style).
  final bool iconContainerShadow;

  /// Padding used when [padding] is null (notice list style).
  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(20, 16, 20, 8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = padding ?? defaultPadding;

    return Padding(
      padding: effectivePadding,
      child: Row(
        children: [
          _BackButton(onPressed: () => Navigator.maybePop(context)),
          const SizedBox(width: 14),
          _CampaignIcon(showShadow: iconContainerShadow),
          const SizedBox(width: 14),
          Expanded(
            child: subtitle != null
                ? _TwoLineTitle(
                    theme: theme,
                    title: title,
                    subtitle: subtitle!,
                  )
                : _SingleLineTitle(theme: theme, title: title),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _CampaignIcon extends StatelessWidget {
  const _CampaignIcon({this.showShadow = false});

  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: const Icon(
        Icons.campaign_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _SingleLineTitle extends StatelessWidget {
  const _SingleLineTitle({required this.theme, required this.title});

  final ThemeData theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _TwoLineTitle extends StatelessWidget {
  const _TwoLineTitle({
    required this.theme,
    required this.title,
    required this.subtitle,
  });

  final ThemeData theme;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.2,
          ),
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
