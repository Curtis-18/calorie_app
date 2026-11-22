import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/workouts.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';

/// One page of the walkthrough.
class WalkthroughPage {
  const WalkthroughPage({required this.emoji, required this.title, required this.body, this.showPlate = false});

  final String emoji;
  final String title;
  final String body;

  /// Show the four slices of the move plate under the words.
  final bool showPlate;
}

/// The pages, in order. Plain, playful words; nothing here is a rule or a
/// target, and nothing mentions burning, earning or making up for food.
List<WalkthroughPage> walkthroughPages() => [
      WalkthroughPage(
        emoji: '👋',
        title: tr('Hey, welcome to Workouts!'),
        body: tr('Short, simple sessions you can do anywhere. No gym, no pressure. Let’s take a quick lap round the place.'),
      ),
      WalkthroughPage(
        emoji: '🍽️',
        title: tr('Fill your move plate'),
        body: tr('Each week, see if you can give every slice a turn. Nothing is a must, and a rest day never counts against you.'),
        showPlate: true,
      ),
      WalkthroughPage(
        emoji: '🍪',
        title: tr('Tiny bites, big wins'),
        body: tr('Only got 2 minutes? Perfect. Move bites are little sessions for between meetings or while the kettle boils.'),
      ),
      WalkthroughPage(
        emoji: '🎧',
        title: tr('The player counts for you'),
        body: tr('Tap Start and we count you through every move: timers, reps, rests and a peek at what’s next. Pause any time.'),
      ),
      WalkthroughPage(
        emoji: '🙂',
        title: tr('Pick by how you feel'),
        body: tr('Tired? Stressed? Feeling good? Choose a feeling and get a few ideas that suit. We never save it or share it.'),
      ),
      WalkthroughPage(
        emoji: '🥗',
        title: tr('Moving and eating, friends'),
        body: tr('What you log shows on Today, and your coach can cheer you on. Your calories stay as they are unless you choose to add some at the bottom of this tab.'),
      ),
      WalkthroughPage(
        emoji: '🌟',
        title: tr('Weeks, not days'),
        body: tr('About 75 minutes, or 3 days of moving, and your week counts. Miss a week now and then? We’ll forgive it.'),
      ),
    ];

/// Opens the walkthrough full screen. Done and Skip both just close it.
Future<void> showWorkoutsWalkthrough(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(fullscreenDialog: true, builder: (_) => const WorkoutsWalkthrough()),
  );
}

class WorkoutsWalkthrough extends StatefulWidget {
  const WorkoutsWalkthrough({super.key});

  @override
  State<WorkoutsWalkthrough> createState() => _WorkoutsWalkthroughState();
}

class _WorkoutsWalkthroughState extends State<WorkoutsWalkthrough> {
  final PageController _controller = PageController();
  int _page = 0;

  late final List<WalkthroughPage> _pages = walkthroughPages();

  bool get _last => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      Navigator.of(context).pop();
      return;
    }
    HapticFeedback.selectionClick();
    _controller.nextPage(duration: AppMotion.medium, curve: AppMotion.standard);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: _last ? 0 : 1,
                  child: CupertinoButton(
                    key: const ValueKey('walkthrough_skip'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    minimumSize: const Size(44, 36),
                    onPressed: _last ? null : () => Navigator.of(context).pop(),
                    child: Text(tr('Skip'), style: AppType.body(size: 15, color: TrackerColors.textSecondary)),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('walkthrough_pages'),
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _PageView(key: ValueKey('walkthrough_page_$i'), page: _pages[i], active: i == _page),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: AppMotion.quick,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _page ? TrackerColors.accentStartText : TrackerColors.glassFill,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              AppButton(
                key: const ValueKey('walkthrough_next'),
                label: _last ? tr('Let’s move!') : tr('Next'),
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({super.key, required this.page, required this.active});

  final WalkthroughPage page;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Bounce(
          active: active,
          child: Container(
            width: 150,
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                TrackerColors.alpha(TrackerColors.flameEnd, 0.28),
                TrackerColors.alpha(TrackerColors.flameStart, 0.06),
              ]),
            ),
            child: Text(page.emoji, style: const TextStyle(fontSize: 76)),
          ),
        ),
        const SizedBox(height: 28),
        Text(page.title, textAlign: TextAlign.center, style: AppType.title().copyWith(fontSize: 28)),
        const SizedBox(height: 12),
        Text(page.body, textAlign: TextAlign.center, style: AppType.body(size: 16, color: TrackerColors.textSecondary)),
        if (page.showPlate) ...[
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final s in MoveSlice.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: TrackerColors.glassFill, borderRadius: BorderRadius.circular(16)),
                        child: Text(s.emoji, style: const TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 64,
                        child: Text(s.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.caption(size: 11)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A little hop each time a page arrives, so the emoji feel alive.
class _Bounce extends StatefulWidget {
  const _Bounce({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(_Bounce old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (_, child) {
        final t = Curves.elasticOut.transform(_controller.value);
        return Transform.scale(scale: 0.6 + 0.4 * t, child: child);
      },
    );
  }
}
