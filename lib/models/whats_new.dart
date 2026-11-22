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
    id: 'nov-26-2026-workouts',
    title: 'What’s new: Workouts, and Insights moved',
    items: [
      WhatsNewItem(
        icon: CupertinoIcons.bolt_fill,
        title: 'A Workouts tab',
        body: 'Short Move bites from 2 minutes, sessions up to 30, and a full-screen player that counts you through each move with rests in between. Pick by length or kind, or by how you feel.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.calendar,
        title: 'Your move plate',
        body: 'See your week: minutes, the days you moved and four kinds of movement. Rest days never count against you. Log a walk, a swim or a game too, anything counts.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.chart_bar_alt_fill,
        title: 'Insights has a new home',
        body: 'Find it on a slim row under your calorie ring on Today, and in Profile. The Tips card is gone to keep things simple.',
      ),
    ],
  ),
  WhatsNewRelease(
    id: 'nov-21-2026-bites-home',
    title: 'What’s new: bites on Today, Home Screen and more',
    items: [
      WhatsNewItem(
        icon: CupertinoIcons.camera_fill,
        title: 'Bites right on Today',
        body: 'Under your calorie ring there are now two tiles. Tap Bites to open the camera, take a photo and choose which friends get it. Messages shows who has written to you.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.chevron_down_circle,
        title: 'Fold your meals',
        body: 'Tap Today’s meals to fold it into a row of small chips with each meal’s calories, and tap again to open it. NuStreak remembers your choice.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.plus_app,
        title: 'Add NuStreak to your Home Screen',
        body: 'Open it like an app, one tap away. Use the card on Today or Add to Home Screen in Settings, then press and hold the icon for shortcuts to the camera, Bites, Messages and Insights.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.sparkles,
        title: 'Sharper bites',
        body: 'The camera now captures bites in higher quality, so what your friends see looks closer to what was on your plate.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.person_crop_circle,
        title: 'Your profile link moved',
        body: 'You will find your link on the Profile tab, under your name. Tap it to copy and share it with friends.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.hand_raised,
        title: 'A friendlier welcome',
        body: 'New people now get a warm hello by name, smoother steps through sign-up and a nicer way to choose a date of birth. You can open it again from Update my details.',
      ),
    ],
  ),
  WhatsNewRelease(
    id: 'nov-21-2026-coach-cards',
    title: 'What’s new: coach suggestions and routines',
    items: [
      WhatsNewItem(
        icon: CupertinoIcons.book,
        title: 'Recipes from your coach',
        body: 'When you ask the coach what to eat, it can now suggest your own saved recipes that fit what’s left today. Tap the card to open the recipe and log it in one tap.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.sportscourt,
        title: 'A move routine, when you want one',
        body: 'Ask the coach about moving more, or say you’re short on time, and it can offer a simple 5, 15 or 30 minute routine with no equipment. Tap the card to see the moves. It’s general information, not medical advice.',
      ),
    ],
  ),
  WhatsNewRelease(
    id: 'nov-2026-coach-languages',
    title: 'What’s new: your coach, your language and more',
    items: [
      WhatsNewItem(
        icon: CupertinoIcons.sparkles,
        title: 'Meet your coach',
        body: 'Messages → Coach. Ask what to eat today, for ideas from your own recipes, or how your week is going. It’s an AI, not a doctor, and your messages are processed by Google Gemini.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.globe,
        title: 'In your language',
        body: 'The app now follows your phone’s language: Spanish, French, German, Portuguese, Italian or English. Settings → Language lets you choose another. Weekly reports, badges, Insights and notifications use it too.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.flame,
        title: 'Dishes from home',
        body: 'If a dish isn’t in the food database, you now get a typical estimate, marked Estimated, that you can edit and save. Settings → Food → Where you mostly eat helps us name your dishes.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'Recipes with photos',
        body: 'Add a cover photo and up to five slides to a recipe, let friends open it, and see a friend’s recipes from Friends → ⋯ → Their recipes. You can also edit a recipe’s ingredients, or start one from a photo of the finished dish.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.bell,
        title: 'Notifications in your browser',
        body: 'On Today, open the bell, tap the gear and turn on Notifications in this browser to get friend bites and reminders even when NuStreak isn’t open. On iPhone, add NuStreak to your Home Screen first.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.chart_bar_alt_fill,
        title: 'Smarter habits and barcodes',
        body: 'After about two weeks of logging, your weekly report can notice things like sugar late in the evening or low-fibre days. Barcodes from outside the US now work too.',
      ),
    ],
  ),
  WhatsNewRelease(
    id: 'nov-2026',
    title: 'What’s new in November',
    items: [
      WhatsNewItem(
        icon: CupertinoIcons.book,
        title: 'Your own recipes',
        body: 'Recipes → Mine. Save a dish you cook, or save a meal you logged with the book icon on Today, then log it in one tap. Pin favourites, sort them into collections and send one to a friend.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.camera,
        title: 'Faster photo logging',
        body: 'Take a photo and carry on: the scan finishes in the background. Tap the mic on a scan to add a note like “half of this, cooked in butter”.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.barcode,
        title: 'Barcodes and quick add-ons',
        body: 'Scan a packaged food from the food search. On a photo, one tap adds the oil, butter or dressing that a photo can’t show.',
      ),
      WhatsNewItem(
        icon: CupertinoIcons.calendar,
        title: 'A flexible weekly target',
        body: 'Settings → Weekly budget. A bigger day eases the rest of the week a little, inside your healthy range. It’s off until you turn it on, and gentle nudges are optional.',
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
