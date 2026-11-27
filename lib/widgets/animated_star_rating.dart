import 'package:flutter/material.dart';

class AnimatedStarRating extends StatefulWidget {
  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  const AnimatedStarRating({
    super.key,
    this.rating = 0,
    this.onChanged,
    this.size = 34,
  });

  @override
  State<AnimatedStarRating> createState() => _AnimatedStarRatingState();
}

class _AnimatedStarRatingState extends State<AnimatedStarRating>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _bounce = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: 1.45),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.45, end: 0.88),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 0.88, end: 1),
      weight: 40,
    ),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  int? _lastTapped;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int value) {
    setState(() => _lastTapped = value);
    _controller.forward(from: 0);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;
        final selected = value <= widget.rating;

        Widget star = Icon(
          selected ? Icons.star_rounded : Icons.star_border_rounded,
          color: selected ? Colors.amber : Colors.white38,
          size: widget.size,
        );

        if (_lastTapped == value) {
          star = ScaleTransition(scale: _bounce, child: star);
        }

        return InkWell(
          onTap: widget.onChanged == null ? null : () => _select(value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(padding: const EdgeInsets.all(4), child: star),
        );
      }),
    );
  }
}
