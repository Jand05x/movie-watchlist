import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movie_watchlist/widgets/animated_star_rating.dart';
import 'package:movie_watchlist/widgets/app_empty_state.dart';
import 'package:movie_watchlist/widgets/genre_chip.dart';
import 'package:movie_watchlist/widgets/initials_avatar.dart';
import 'package:movie_watchlist/widgets/poster_image.dart';

Widget _mobileHarness() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppEmptyState(
          icon: Icons.favorite_border,
          title: 'No taste match yet',
          message: 'Rate at least 3 movies to compare taste with a friend.',
          actionLabel: 'Discover movies',
          onAction: null,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            GenreChip(label: 'Action', genreId: 28),
            GenreChip(label: 'Science Fiction', genreId: 878),
            GenreChip(label: 'Very Long Genre Name That Must Wrap Cleanly'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            PosterImage(path: null, width: 112, height: 168),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'A watched movie title long enough to exercise ellipsis on a small phone',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            InitialsAvatar(name: 'Alex Morgan', radius: 24),
            SizedBox(width: 12),
            Expanded(child: Text('@alex_morgan')),
          ],
        ),
        const SizedBox(height: 20),
        const AnimatedStarRating(rating: 4, size: 34),
      ],
    ),
  );
}

void main() {
  const sizes = [
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
  ];
  const scales = [1.0, 1.3, 2.0];

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets(
        'mobile components fit ${size.width.toInt()}x${size.height.toInt()} at ${scale}x',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(body: _mobileHarness()),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('No taste match yet'), findsOneWidget);
          expect(find.byType(AnimatedStarRating), findsOneWidget);
        },
      );
    }
  }
}
