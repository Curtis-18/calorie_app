import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/messages.dart';
import '../providers/house_recipes_provider.dart';
import '../services/coach_service.dart';
import '../services/voice_note.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/house_recipe_sheet.dart';
import '../widgets/workout_sheet.dart';
import '../widgets/pressable.dart';

/// How the screen makes its service when it is not given one. Tests replace it.
@visibleForTesting
CoachService Function() coachServiceFactory = CoachService.new;

/// Open the chat with the AI coach, over the tab bar.
Future<void> openCoach(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute<void>(builder: (_) => const CoachScreen()));
}

/// The pinned "Coach" thread in Messages. Text only (speech is turned into
/// words on the phone; audio never leaves it). The coach is not a friend: no
/// read receipts, nothing to unsend, and the thread can be cleared.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, this.service, this.recognizer, this.openRecipe});

  final CoachService? service;
  final VoiceRecognizer? recognizer;

  /// Opens a recipe the coach named (its sheet has the servings and "Log this").
  /// Tests replace it; the app opens the person's own recipe by id.
  final Future<void> Function(BuildContext context, String recipeId)? openRecipe;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  late final CoachService _service = widget.service ?? coachServiceFactory();
  late final VoiceRecognizer _voice = widget.recognizer ?? DeviceVoiceRecognizer();

  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _waiting = false; // the coach is writing
  bool _micAvailable = false;
  bool _listening = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
    _voice.available().then((ok) {
      if (mounted) setState(() => _micAvailable = ok);
    });
  }

  @override
  void dispose() {
    _voice.stop();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final thread = await _service.thread();
      if (!mounted) return;
      setState(() {
        _messages = thread.messages;
        _hasMore = thread.hasMore;
        _loading = false;
        _loadError = null;
      });
    } on MessagesException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    }
  }

  Future<void> _loadEarlier() async {
    if (_loadingMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final older = await _service.thread(before: _messages.first.createdAt);
      if (!mounted) return;
      setState(() {
        _messages = [...older.messages, ..._messages];
        _hasMore = older.hasMore;
        _loadingMore = false;
      });
    } on MessagesException {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool get _canSend {
    final n = _input.text.trim().length;
    return !_waiting && n > 0 && n <= maxMessageChars;
  }

  Future<void> _submit([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _waiting) return;
    if (_listening) await _stopListening();
    final message = ChatMessage(
      id: newMessageId(),
      mine: true,
      body: text,
      createdAt: DateTime.now(),
      state: SendState.sending,
    );
    setState(() {
      _messages = [..._messages, message];
      _input.clear();
    });
    await _deliver(message);
  }

  /// Ask again with the same id after a failure: the server never answers one
  /// turn twice.
  Future<void> _deliver(ChatMessage message) async {
    setState(() {
      _waiting = true;
      _replace(message.copyWith(state: SendState.sending, clearError: true));
    });
    try {
      final reply = await _service.ask(id: message.id, text: message.body);
      if (!mounted) return;
      setState(() {
        _waiting = false;
        _replace(message.copyWith(state: SendState.sent, clearError: true));
        _messages = [..._messages, reply];
      });
    } on MessagesException catch (e) {
      if (!mounted) return;
      setState(() {
        _waiting = false;
        _replace(message.copyWith(state: SendState.failed, error: e.message));
      });
    }
  }

  Future<void> _openRecipe(String id) {
    final open = widget.openRecipe;
    if (open != null) return open(context, id);
    return openRecipeById(context, ProviderScope.containerOf(context).read(houseRecipesProvider.notifier), id);
  }

  void _replace(ChatMessage next) {
    _messages = [for (final m in _messages) m.id == next.id ? next : m];
  }

  Future<void> _toggleMic() async {
    if (_listening) return _stopListening();
    setState(() => _listening = true);
    await _voice.listen((words, done) {
      if (!mounted) return;
      setState(() {
        _input.text = words;
        _input.selection = TextSelection.collapsed(offset: words.length);
        if (done) _listening = false;
      });
    });
  }

  Future<void> _stopListening() async {
    await _voice.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _menu() async {
    final clear = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            key: const ValueKey('coach_clear'),
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Clear conversation')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('Cancel'))),
      ),
    );
    if (clear != true || !mounted) return;
    final sure = await showAppDialog(
      context: context,
      title: tr('Clear this conversation?'),
      message: tr('Your messages with the coach will be deleted. This can’t be undone.'),
      confirmLabel: tr('Clear'),
      cancelLabel: tr('Cancel'),
      destructive: true,
    );
    if (sure != true || !mounted) return;
    try {
      await _service.clear();
      if (mounted) {
        setState(() {
          _messages = const [];
          _hasMore = false;
        });
      }
    } on MessagesException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      child: Column(
        children: [
          _Header(onMenu: _menu),
          Expanded(child: _body()),
          if (_loadError != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
              child: Text(_loadError!,
                  textAlign: TextAlign.center, style: AppType.caption(color: TrackerColors.warning, size: 12.5)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
            child: Text(
              tr('AI coach. General information, not medical advice. Messages here are processed by Google Gemini.'),
              key: const ValueKey('coach_disclaimer'),
              textAlign: TextAlign.center,
              style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
            ),
          ),
          _Composer(
            controller: _input,
            canSend: _canSend,
            onChanged: () => setState(() {}),
            onSend: _submit,
            onMic: _micAvailable ? _toggleMic : null,
            listening: _listening,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_loadError != null && _messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: AppEmptyState(
          icon: CupertinoIcons.sparkles,
          title: tr("Couldn't open the coach"),
          message: _loadError,
          accent: TrackerColors.error,
        ),
      );
    }
    if (_messages.isEmpty) return _Greeting(onPick: _submit, enabled: !_waiting);

    final n = _messages.length;
    final extra = _waiting ? 1 : 0;
    final now = DateTime.now();
    return ListView.builder(
      key: const ValueKey('coach_list'),
      reverse: true,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: n + extra + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (_waiting && i == 0) return const _Typing(key: ValueKey('coach_typing'));
        final j = i - extra;
        if (j == n) {
          return Center(
            child: CupertinoButton(
              key: const ValueKey('coach_earlier'),
              onPressed: _loadingMore ? null : _loadEarlier,
              child: Text(_loadingMore ? tr('Loading…') : tr('Earlier messages'), style: AppType.caption(size: 13)),
            ),
          );
        }
        final index = n - 1 - j;
        final message = _messages[index];
        final previous = index > 0 ? _messages[index - 1] : null;
        final gap = previous == null ||
            message.createdAt.difference(previous.createdAt) > const Duration(minutes: 30) ||
            message.createdAt.day != previous.createdAt.day;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (gap)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(chatTimeLabel(message.createdAt, now),
                      style: AppType.caption(color: TrackerColors.textTertiary, size: 11.5)),
                ),
              ),
            _Bubble(message: message, onRetry: () => _deliver(message), onOpenRecipe: _openRecipe),
          ],
        );
      },
    );
  }
}

/// A round "coach" mark, used in the header, the Messages row and the greeting.
class CoachBadge extends StatelessWidget {
  const CoachBadge({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: TrackerColors.calorieGradient),
      child: Icon(CupertinoIcons.sparkles, size: size * 0.5, color: TrackerColors.onAccent),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      opacity: 0.9,
      tint: TrackerColors.navFill,
      blur: 24,
      borderRadius: BorderRadius.zero,
      border: Border(bottom: BorderSide(color: TrackerColors.border, width: 1)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              CupertinoButton(
                key: const ValueKey('coach_back'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                child: Icon(CupertinoIcons.chevron_left, color: TrackerColors.textPrimary, size: 22),
              ),
              const CoachBadge(size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(tr('Coach'), style: AppType.headline())),
              CupertinoButton(
                key: const ValueKey('coach_menu'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                onPressed: onMenu,
                child: Icon(CupertinoIcons.ellipsis, color: TrackerColors.textPrimary, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.onPick, required this.enabled});

  final void Function(String) onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ideas = [
      tr('What should I eat for dinner?'),
      tr('Ideas that fit my protein today'),
      tr('How is my week going?'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        const Center(child: CoachBadge(size: 64)),
        const SizedBox(height: 16),
        Text(tr('Your coach'), textAlign: TextAlign.center, style: AppType.headline()),
        const SizedBox(height: 8),
        Text(
          tr('Ask about what to eat today, ideas from your own recipes, or how your week is going.'),
          textAlign: TextAlign.center,
          style: AppType.body(size: 14.5, color: TrackerColors.textSecondary),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < ideas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable(
              key: ValueKey('coach_idea_$i'),
              onTap: enabled ? () => onPick(ideas[i]) : null,
              borderRadius: AppRadii.buttonAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: AppDecor.card(borderRadius: AppRadii.buttonAll),
                child: Text(ideas[i], style: AppType.body(size: 15)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onRetry, required this.onOpenRecipe});

  final ChatMessage message;
  final VoidCallback onRetry;
  final void Function(String recipeId) onOpenRecipe;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final failed = message.state == SendState.failed;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(mine ? 20 : 6),
      bottomRight: Radius.circular(mine ? 6 : 20),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
            child: GestureDetector(
              key: ValueKey('coach_msg_${message.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: failed ? onRetry : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  gradient: mine ? TrackerColors.calorieGradient : null,
                  color: mine ? null : TrackerColors.surface,
                  borderRadius: radius,
                  border: mine || !TrackerColors.isDark ? null : Border.all(color: TrackerColors.border),
                ),
                child: Text(
                  message.body,
                  style: AppType.body(size: 15.5, color: mine ? TrackerColors.onAccent : TrackerColors.textPrimary),
                ),
              ),
            ),
          ),
          for (final suggestion in message.suggestions)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _SuggestionCard(suggestion: suggestion, onTap: () => onOpenRecipe(suggestion.recipeId)),
            ),
          for (final workout in message.workouts)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _WorkoutCard(workout: workout, onTap: () => showWorkoutSheet(context, workout)),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
              child: Text(
                tr('{error}. Tap to try again.', {'error': message.error ?? tr('Not sent')}),
                style: AppType.caption(color: TrackerColors.error, size: 11),
              ),
            ),
        ],
      ),
    );
  }
}

/// A recipe of the person's own that the coach named: tap to open it and log it.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final CoachSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
      child: Pressable(
        key: ValueKey('coach_recipe_${suggestion.recipeId}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: TrackerColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TrackerColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 15, color: TrackerColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(tr('{n} kcal per serving · tap to open', {'n': '${suggestion.calories}'}),
                        style: AppType.caption(color: TrackerColors.textTertiary, size: 12)),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, size: 16, color: TrackerColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A routine the coach named: tap to see the moves.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout, required this.onTap});

  final CoachWorkout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
      child: Pressable(
        key: ValueKey('coach_workout_${workout.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: TrackerColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TrackerColors.border),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.sportscourt, size: 20, color: TrackerColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workout.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 15, color: TrackerColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text([workout.duration, workout.focus].where((x) => x.isNotEmpty).join(' · '),
                        style: AppType.caption(color: TrackerColors.textTertiary, size: 12)),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, size: 16, color: TrackerColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('The coach is writing'),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: TrackerColors.surface, borderRadius: BorderRadius.circular(20)),
          child: const CupertinoActivityIndicator(radius: 8),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
    required this.listening,
    this.onMic,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onChanged;
  final VoidCallback onSend;
  final VoidCallback? onMic;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: TrackerColors.navFill, border: AppDecor.hairlineTop),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CupertinoTextField(
                  key: const ValueKey('coach_input'),
                  controller: controller,
                  placeholder: listening ? tr('Listening…') : tr('Ask the coach'),
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(maxMessageChars)],
                  onChanged: (_) => onChanged(),
                  style: AppType.body(size: 15.5, color: TrackerColors.textPrimary),
                  placeholderStyle: AppType.body(size: 15.5, color: TrackerColors.textTertiary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: TrackerColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: TrackerColors.border),
                  ),
                ),
              ),
              if (onMic != null) ...[
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: listening ? tr('Stop listening') : tr('Speak your message'),
                  child: Pressable(
                    key: const ValueKey('coach_mic'),
                    onTap: onMic,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: listening ? TrackerColors.error : TrackerColors.surface,
                        border: Border.all(color: TrackerColors.border),
                      ),
                      child: Icon(
                        listening ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                        size: 18,
                        color: listening ? TrackerColors.onAccent : TrackerColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: tr('Send message'),
                child: Pressable(
                  key: const ValueKey('coach_send'),
                  onTap: canSend ? onSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: canSend ? TrackerColors.calorieGradient : null,
                      color: canSend ? null : TrackerColors.surface,
                      border: canSend ? null : Border.all(color: TrackerColors.border),
                    ),
                    child: Icon(
                      CupertinoIcons.arrow_up,
                      size: 19,
                      color: canSend ? TrackerColors.onAccent : TrackerColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
