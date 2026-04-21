import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'feed_filter_bar.dart';

class FeedSkeleton extends StatelessWidget {
  final bool isLandscape;

  const FeedSkeleton({super.key, this.isLandscape = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Column(
      children: [
        // We still show the filter bar while loading so the UI doesn't jump
        FeedFilterBar(
          selectedFilter: FeedFilter.thisWeek,
          onFilterChanged: (_) {},
        ),
        Expanded(
          child: CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              // "the i's" Title Skeleton
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Container(
                      height: 36,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),

              // Mock Category 1 (e.g., Action Needed)
              _buildCategorySkeleton(baseColor, highlightColor, isLandscape),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Mock Category 2 (e.g., The Agenda)
              _buildCategorySkeleton(baseColor, highlightColor, isLandscape),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySkeleton(Color baseColor, Color highlightColor, bool isLandscape) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header Skeleton
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 12),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 20,
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          
          // Horizontal Cards Skeleton
          SizedBox(
            height: 310,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Container(
                      width: 260,
                      height: 310,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
