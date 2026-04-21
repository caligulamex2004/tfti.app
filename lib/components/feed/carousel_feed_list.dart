import 'package:flutter/material.dart';

class CarouselFeedList extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const CarouselFeedList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<CarouselFeedList> createState() => _CarouselFeedListState();
}

class _CarouselFeedListState extends State<CarouselFeedList> {
  late PageController _pageController;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    // 0.85 viewport means the center card takes up 85% of the screen width.
    _pageController = PageController(viewportFraction: 0.85);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.itemCount,
      // OverScroll physics give it that premium bouncy feel on iOS and Android
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final double difference = (_currentPage - index).abs();
        
        // Scale down to 90% (0.9) at adjacent pages
        final double scale = (1 - (difference * 0.1)).clamp(0.9, 1.0);
        
        // Fade down to 70% (0.7) at adjacent pages
        final double opacity = (1 - (difference * 0.3)).clamp(0.7, 1.0);

        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            );
          },
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}
