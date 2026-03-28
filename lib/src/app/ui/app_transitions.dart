import 'package:flutter/material.dart';

// ─── Custom Page Route ────────────────────────────────────────────────────────
// Zastępuje MaterialPageRoute — fade + subtelny slide up.

class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, animation, _) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

// ─── Staggered List Item ──────────────────────────────────────────────────────
// Owiń każdy element listy — wchodzi z lekkim opóźnieniem wg indeksu.

class AnimatedListItem extends StatefulWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(curved);

    final delay = Duration(milliseconds: 45 * widget.index.clamp(0, 8));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ─── Shimmer Loading ──────────────────────────────────────────────────────────
// Zastępuje CircularProgressIndicator w listach.

class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final delay = (i * 0.12).clamp(0.0, 0.6);
          final shifted = ((_ctrl.value + delay) % 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                _shimmerCircle(cs, shifted, 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _shimmerBar(cs, shifted, double.infinity, 14),
                      const SizedBox(height: 6),
                      _shimmerBar(cs, shifted, 180, 11),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _shimmerCircle(ColorScheme cs, double pos, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _shimmerGradient(cs, pos),
      ),
    );
  }

  Widget _shimmerBar(ColorScheme cs, double pos, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: _shimmerGradient(cs, pos),
      ),
    );
  }

  LinearGradient _shimmerGradient(ColorScheme cs, double pos) {
    final base = cs.surfaceContainerHighest;
    final highlight = cs.surfaceContainerHighest.withValues(alpha: 0.3);
    return LinearGradient(
      colors: <Color>[base, highlight, base],
      stops: <double>[
        (pos - 0.3).clamp(0.0, 1.0),
        pos.clamp(0.0, 1.0),
        (pos + 0.3).clamp(0.0, 1.0),
      ],
    );
  }
}

// ─── Animated Chat Bubble ─────────────────────────────────────────────────────
// Owija bąbel wiadomości — wchodzi slide z boku + fade.

class AnimatedChatBubble extends StatefulWidget {
  const AnimatedChatBubble({
    super.key,
    required this.mine,
    required this.child,
    this.isNew = false,
  });

  final bool mine;
  final Widget child;

  /// true dla wiadomości przychodzących w czasie rzeczywistym
  final bool isNew;

  @override
  State<AnimatedChatBubble> createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<AnimatedChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slide = Tween<Offset>(
      begin: Offset(widget.mine ? 0.08 : -0.08, 0),
      end: Offset.zero,
    ).animate(curved);

    if (widget.isNew) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0; // historyczne — od razu widoczne
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
