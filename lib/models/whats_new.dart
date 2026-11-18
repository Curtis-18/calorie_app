import 'package:flutter/cupertino.dart';

/// One thing that changed, in plain words.
class WhatsNewItem {
  const WhatsNewItem({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// A batch of changes shown together under one heading. Add a new release at
/// the top of [whatsNewReleases] and everyone gets a fresh unread dot.
class WhatsNewRelease {
  const WhatsNewRelease({required this.id, required this.title, required this.items});

  /// Stored as "seen" per person, so it must never change once shipped.
  final String id;
  final String title;
  final List<WhatsNewItem> items;
}

/// Newest first.
const whatsNewReleases = <WhatsNewRelease>[
  WhatsNewRelease(
    id: 'nov-2026',
    title: 'What’s new in November',
    items: [
      WhatsNewItem(
        icon: CupertinoIcons.book,
        title: 'Your own recipes',
        body: 'Recipes → Mine. Save a dish you cook, or save a meal you logged with the book icon on Today, then log it in one tap. '
            'Pin favourites, sort them into collections and send one to a friend.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.camera,
        title: 'Faster photo logging',
        body: 'Take a photo and carry on: the scan finishes in the background. Tap the mic on a scan to add a note like '
            '“half of this, cooked in butter”.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.barcode,
        title: 'Barcodes and quick add-ons',
        body: 'Scan a packaged food from the food search. On a photo, one tap adds the oil, butter or dressing that a photo can’t show.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.calendar,
        title: 'A flexible weekly target',
        body: 'Settings → Weekly budget. A bigger day eases the rest of the week a little, inside your healthy range. '
            'It’s off until you turn it on, and gentle nudges are optional.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.chart_bar,
        title: 'Your week, on Insights',
        body: 'Days logged, days at your protein goal and, after about two weeks of logging, a habit or two worth knowing about.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.camera_viewfinder,
        title: 'Open on the camera',
        body: 'Settings → Today screen, if you’d like the app to start on the camera.',
      ),
    ],
  ),
];

WhatsNewRelease get latestWhatsNew => whatsNewReleases.first;
