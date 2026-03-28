import 'dart:ui';

import 'package:activefriends/src/app/theme/app_palette.dart';
import 'package:flutter/material.dart';

// ─── Tab Item ─────────────────────────────────────────────────────────────────

class TabItem {
  const TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

// ─── Animated Gradient Tab Bar ────────────────────────────────────────────────
// Sliding orange→amber pill that animates between tabs. The pill glows.

class AnimatedGradientTabBar extends StatefulWidget {
  const AnimatedGradientTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<TabItem> items;

  @override
  State<AnimatedGradientTabBar> createState() => _AnimatedGradientTabBarState();
}

class _AnimatedGradientTabBarState extends State<AnimatedGradientTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _pillPos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _pillPos = AlwaysStoppedAnimation<double>(widget.selectedIndex.toDouble());
  }

  @override
  void didUpdateWidget(AnimatedGradientTabBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      final double from = _pillPos.value;
      _pillPos = Tween<double>(
        begin: from,
        end: widget.selectedIndex.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    const double barH = 64.0;
    const double pillH = 46.0;
    const double pillVPad = (barH - pillH) / 2;
    const double pillHPad = 6.0;

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double totalW = constraints.maxWidth;
        final int count = widget.items.length;
        final double tabW = totalW / count;
        final double pillW = tabW - pillHPad * 2;

        return Container(
          height: barH + bottomPad,
          decoration: BoxDecoration(
            color: AppPalette.dark1,
            border: Border(
              top: BorderSide(
                color: AppPalette.darkBorder.withValues(alpha: 0.8),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: AnimatedBuilder(
              animation: _pillPos,
              builder: (BuildContext _, Widget? _) {
                final double left = _pillPos.value * tabW + pillHPad;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    // ── Sliding gradient pill ──────────────────────────
                    Positioned(
                      left: left,
                      top: pillVPad,
                      width: pillW,
                      height: pillH,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppPalette.tabGradient,
                          borderRadius: BorderRadius.circular(pillH / 2),
                          boxShadow: AppPalette.tabGlow,
                        ),
                      ),
                    ),
                    // ── Tab labels & icons row ─────────────────────────
                    Row(
                      children: List<Widget>.generate(count, (int i) {
                        final bool sel = i == widget.selectedIndex;
                        final TabItem item = widget.items[i];
                        final Color fg =
                            sel ? Colors.black : AppPalette.darkMuted;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => widget.onTap(i),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              height: barH,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: <Widget>[
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: Icon(
                                          sel ? item.activeIcon : item.icon,
                                          key: ValueKey<bool>(sel),
                                          color: fg,
                                          size: 22,
                                        ),
                                      ),
                                      if (item.badge > 0)
                                        Positioned(
                                          right: -7,
                                          top: -5,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppPalette.emergency,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              item.badge > 9
                                                  ? '9+'
                                                  : '${item.badge}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w800,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: TextStyle(
                                      color: fg,
                                      fontSize: 10,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      letterSpacing: 0.1,
                                    ),
                                    child: Text(item.label),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Glass Navigation Bar ─────────────────────────────────────────────────────
// Legacy wrapper — use AnimatedGradientTabBar for new screens.

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppPalette.dark1.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: AppPalette.darkBorder.withValues(alpha: 0.8),
                width: 0.5,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}

// ─── Gradient Button ──────────────────────────────────────────────────────────

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient,
    this.padding,
    this.borderRadius = 14.0,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Gradient? gradient;
  final EdgeInsets? padding;
  final double borderRadius;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Gradient gradient = widget.gradient ?? AppPalette.brandGradient;

    return GestureDetector(
      onTapDown: enabled ? (_) => _ctrl.forward() : null,
      onTapUp: enabled
          ? (_) {
              _ctrl.reverse();
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: enabled ? gradient : null,
            color: enabled ? null : AppPalette.dark2,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: enabled ? AppPalette.brandShadow : null,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: enabled ? Colors.black : AppPalette.darkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.1,
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
