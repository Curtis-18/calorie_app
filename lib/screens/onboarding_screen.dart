import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/body_input.dart';
import '../models/profile_copy.dart';
import '../models/user_profile.dart';
import '../models/weight.dart';
import '../providers/user_provider.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import '../widgets/onboarding/choice_card.dart';
import '../widgets/onboarding/plan_ready_sheet.dart';
import '../widgets/save_toast.dart';
import '../widgets/step_progress.dart';
import '../widgets/welcome_overlay.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final UserProfile? existingProfile;

  const OnboardingScreen({super.key, this.existingProfile});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();

  int _currentStep = 0;
  static const int _stepCount = 4;
  bool _showWelcome = true;

  // People nearly everywhere use kg and cm, a few countries use lb and ft.
  // Only a starting guess: both are one tap away.
  final bool _imperialDefault =
      usesImperialUnits(WidgetsBinding.instance.platformDispatcher.locale.countryCode);
  late WeightUnit _weightUnit = _imperialDefault ? WeightUnit.lb : WeightUnit.kg;
  late HeightUnit _heightUnit = _imperialDefault ? HeightUnit.ftIn : HeightUnit.cm;

  DateTime? _dateOfBirth;

  // No defaults for these: each is a real question the user should answer,
  // not a pre-ticked box.
  Gender? _gender;
  ActivityLevel? _activity;
  Goal? _goal;
  SaveToastState _saveState = SaveToastState.initial;

  /// Material bridge: the step forms use Material inputs, so we hand them the
  /// app's palette (dark or light) instead of Material's default scheme.
  ThemeData get _materialTheme {
    final isDark = TrackerColors.isDark;
    final scheme = (isDark ? ColorScheme.dark : ColorScheme.light)(
      primary: TrackerColors.accentStart,
      onPrimary: TrackerColors.onAccent,
      secondary: TrackerColors.accentEnd,
      surface: TrackerColors.surface,
      onSurface: TrackerColors.textPrimary,
      error: TrackerColors.error,
      onError: TrackerColors.onAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: TrackerColors.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: TrackerColors.background,
      splashFactory: NoSplash.splashFactory,
      textTheme: TextTheme(
        bodyMedium: AppType.body(),
        bodySmall: AppType.caption(),
        labelLarge: AppType.caption(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TrackerColors.surfaceElevated,
        floatingLabelStyle: AppType.caption(color: TrackerColors.accentStartText, size: 12),
        labelStyle: AppType.caption(color: TrackerColors.textTertiary, size: 13),
        hintStyle: AppType.body(color: TrackerColors.textTertiary, size: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: _inputBorder(TrackerColors.border),
        enabledBorder: _inputBorder(TrackerColors.border),
        focusedBorder: _inputBorder(TrackerColors.alpha(TrackerColors.accentStart, 0.5), width: 1.5),
        errorBorder: _inputBorder(TrackerColors.alpha(TrackerColors.error, 0.5)),
        focusedErrorBorder: _inputBorder(TrackerColors.error, width: 1.5),
        errorStyle: AppType.caption(color: TrackerColors.error, size: 11),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: AppRadii.buttonAll,
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  void initState() {
    super.initState();
    if (widget.existingProfile != null) {
      _showWelcome = false;
      _prepopulateData(widget.existingProfile!);
    }
  }

  void _prepopulateData(UserProfile p) {
    _gender = p.gender;
    _activity = p.activityLevel;
    _goal = p.goal;
    _dateOfBirth = p.dateOfBirth;
    _weightController.text = _tidy(_weightUnit.fromKg(p.weightKg));
    if (_heightUnit == HeightUnit.cm) {
      _heightFeetController.text = _tidy(p.heightCm);
    } else {
      final (feet, inches) = feetAndInches(p.heightCm);
      _heightFeetController.text = '$feet';
      _heightInchesController.text = _tidy(inches);
    }
  }

  /// "72" rather than "72.0", "72.5" as is.
  static String _tidy(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  void _ask(String title, String message) {
    showAppDialog(context: context, title: title, message: message, confirmLabel: 'OK');
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_dateOfBirth == null) {
          _ask('When were you born?', 'Please choose your date of birth.');
          return false;
        }
        if (_dateOfBirth!.isAfter(_latestAdultBirthday)) {
          // Mifflin-St Jeor is an adult equation, and paediatric guidance
          // advises against calorie counting for teens.
          _ask('Adults only', 'Calorie plans are designed for adults. You need to be 18 or older to use them.');
          return false;
        }
        if (_gender == null) {
          _ask('One more thing', 'Please choose Female or Male. It only affects the calorie maths.');
          return false;
        }
        return true;
      case 1:
        return _formKey.currentState?.validate() ?? false;
      case 2:
        if (_activity == null) {
          _ask('How active are you?', 'Pick the one that sounds most like your usual week.');
          return false;
        }
        return true;
      case 3:
        if (_goal == null) {
          _ask('What is your goal?', 'Pick the one that fits best. You can change it any time.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < _stepCount - 1) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prev() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  static DateTime get _latestAdultBirthday {
    final now = DateTime.now();
    return DateTime(now.year - 18, now.month, now.day);
  }

  Future<void> _submit() async {
    final weightKg = parseWeightKg(_weightController.text, _weightUnit);
    final heightCm = parseHeightCm(_heightUnit, _heightFeetController.text, inches: _heightInchesController.text);
    if (_dateOfBirth == null || _gender == null || _activity == null || _goal == null) return;
    if (weightKg == null || heightCm == null) {
      // The body step validates this, so it only happens if a field was
      // edited out from under us. Send the user back to fix it.
      setState(() => _currentStep = 1);
      return;
    }
    setState(() => _saveState = SaveToastState.loading);

    try {
      final profile = UserProfile(
        weightKg: weightKg,
        heightCm: heightCm,
        dateOfBirth: _dateOfBirth!,
        gender: _gender!,
        activityLevel: _activity!,
        goal: _goal!,
      );

      await ref.read(userProfileProvider.notifier).saveProfile(profile);
      if (!mounted) return;
      setState(() => _saveState = SaveToastState.success);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      // A weight-loss goal can land on "stay the same" when daily burn is
      // already at the safe minimum (1200 kcal women / 1500 men). Say so,
      // rather than silently showing a "lose" plan that isn't a deficit.
      final saved = ref.read(userProfileProvider) ?? profile;
      final target = saved.calorieTarget;
      final tdee = saved.tdee;
      final landedOnMaintenance = _goal == Goal.lose && target != null && tdee != null && target >= tdee.round();
      await showPlanReadySheet(
        context,
        profile: saved,
        maintenanceNotice: landedOnMaintenance
            ? 'Your body already uses close to the least we would suggest eating without medical advice, '
                'so your plan keeps you steady at $target calories. Moving a bit more is the safest way '
                'to make progress, and a doctor or dietitian can help with a bigger plan.'
            : null,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() => _saveState = SaveToastState.initial);
        await showAppDialog(
          context: context,
          title: 'Could not save',
          message: e is ProfileSaveException ? e.message : "We couldn't save your profile. Please try again.",
          confirmLabel: 'OK',
        );
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    super.dispose();
  }

  /// Big friendly heading for each step: what we're asking, and why.
  Widget _stepHeader(String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TrackerColors.alpha(color, 0.12),
              borderRadius: AppRadii.buttonAll,
              border: Border.all(color: TrackerColors.alpha(color, 0.28), width: 1),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppType.navLargeTitle(size: 28)),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: AppType.body(color: TrackerColors.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final latest = _latestAdultBirthday;
    var selected = _dateOfBirth ?? DateTime(2000, 1, 1);
    if (selected.isAfter(latest)) selected = latest;

    final picked = await showAppSheet<DateTime>(
      context: context,
      builder: (sheetContext) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date of birth', style: AppType.title()),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 220,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selected,
                minimumDate: DateTime(1920),
                maximumDate: latest, // adults only
                onDateTimeChanged: (date) => selected = date,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Done',
              onPressed: () => Navigator.of(sheetContext).pop(selected),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _dateOfBirth = picked);
  }

  Widget _fieldLabel(String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text(text, style: AppType.headline().copyWith(fontSize: 15))),
            ?trailing,
          ],
        ),
      );

  Widget _buildAboutYouStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          "Let's get to know you",
          'This helps us work out how much energy your body uses each day.',
          CupertinoIcons.hand_raised,
          TrackerColors.macroProtein,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('When were you born?'),
              GestureDetector(
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    hintText: 'Tap to choose',
                    suffixIcon: Icon(Icons.calendar_today, size: 16),
                  ),
                  child: Text(
                    _dateOfBirth == null ? 'Tap to choose' : DateFormat.yMMMMd().format(_dateOfBirth!),
                    style: AppType.body(
                      size: 15,
                      color: _dateOfBirth == null ? TrackerColors.textTertiary : TrackerColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('You need to be 18 or older.', style: AppType.caption(color: TrackerColors.textTertiary)),
              const SizedBox(height: AppSpacing.xl),
              _fieldLabel('Are you female or male?'),
              Row(
                children: [
                  for (final g in Gender.values) ...[
                    Expanded(
                      child: _SexOption(
                        label: g.title,
                        selected: _gender == g,
                        onTap: () => setState(() => _gender = g),
                      ),
                    ),
                    if (g != Gender.values.last) const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Bodies burn energy a little differently, so we need this for the maths. Nothing else.',
                style: AppType.caption(color: TrackerColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBodyMetricsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'Your body',
          'Just two numbers. A rough guess is fine, you can fix them later.',
          CupertinoIcons.person_crop_circle,
          TrackerColors.accentStart,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel(
                'How much do you weigh?',
                trailing: UnitPills<WeightUnit>(
                  options: {for (final u in WeightUnit.values) u: u.label},
                  value: _weightUnit,
                  onChanged: (u) => setState(() {
                    final typed = parseWeightKg(_weightController.text, _weightUnit);
                    _weightUnit = u;
                    if (typed != null) _weightController.text = _tidy(u.fromKg(typed));
                  }),
                ),
              ),
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppType.body(size: 15),
                decoration: InputDecoration(hintText: _weightUnit == WeightUnit.kg ? 'e.g. 70' : 'e.g. 154'),
                validator: (v) => parseWeightKg(v ?? '', _weightUnit) == null ? weightProblem(_weightUnit) : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              _fieldLabel(
                'How tall are you?',
                trailing: UnitPills<HeightUnit>(
                  options: {for (final u in HeightUnit.values) u: u.label},
                  value: _heightUnit,
                  onChanged: _changeHeightUnit,
                ),
              ),
              if (_heightUnit == HeightUnit.cm)
                TextFormField(
                  controller: _heightFeetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppType.body(size: 15),
                  decoration: const InputDecoration(hintText: 'e.g. 170', suffixText: 'cm'),
                  validator: (v) => parseHeightCm(HeightUnit.cm, v ?? '') == null ? heightProblem(HeightUnit.cm) : null,
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightFeetController,
                        keyboardType: TextInputType.number,
                        style: AppType.body(size: 15),
                        decoration: const InputDecoration(hintText: 'e.g. 5', suffixText: 'ft'),
                        validator: (v) => parseHeightCm(
                                  HeightUnit.ftIn,
                                  v ?? '',
                                  inches: _heightInchesController.text,
                                ) ==
                                null
                            ? heightProblem(HeightUnit.ftIn)
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _heightInchesController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: AppType.body(size: 15),
                        decoration: const InputDecoration(hintText: 'e.g. 9', suffixText: 'in'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Switch cm / ft+in, carrying over whatever was typed.
  void _changeHeightUnit(HeightUnit unit) {
    if (unit == _heightUnit) return;
    final cm = parseHeightCm(_heightUnit, _heightFeetController.text, inches: _heightInchesController.text);
    setState(() {
      _heightUnit = unit;
      _heightFeetController.clear();
      _heightInchesController.clear();
      if (cm == null) return;
      if (unit == HeightUnit.cm) {
        _heightFeetController.text = _tidy(cm);
      } else {
        final (feet, inches) = feetAndInches(cm);
        _heightFeetController.text = '$feet';
        _heightInchesController.text = _tidy(inches);
      }
    });
  }

  Widget _buildActivityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'How active are you?',
          'Think about a normal week, including your job. Choose the one that sounds most like you.',
          CupertinoIcons.flame,
          TrackerColors.macroCarbs,
        ),
        for (final level in ActivityLevel.values) ...[
          ChoiceCard(
            icon: level.icon,
            title: level.title,
            blurb: level.blurb,
            selected: _activity == level,
            onTap: () => setState(() => _activity = level),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Not sure? Pick the lower one. You can change it any time.',
            style: AppType.caption(color: TrackerColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          "What's your goal?",
          "We'll set a gentle daily plan to match.",
          CupertinoIcons.scope,
          TrackerColors.macroFat,
        ),
        for (final goal in Goal.values) ...[
          ChoiceCard(
            icon: goal.icon,
            title: goal.title,
            blurb: goal.blurb,
            selected: _goal == goal,
            onTap: () => setState(() => _goal = goal),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Your plan never goes below the minimum that health guidelines suggest.',
            style: AppType.caption(color: TrackerColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: AppButton.glass(
                label: 'Back',
                onPressed: _prev,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              label: _currentStep == _stepCount - 1 ? 'Build my plan' : 'Next',
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _buildAboutYouStep(),
      _buildBodyMetricsStep(),
      _buildActivityStep(),
      _buildGoalStep(),
    ];

    final bool showingWelcome = widget.existingProfile == null && _showWelcome;

    return Theme(
      data: _materialTheme,
      child: PopScope(
        canPop: _currentStep == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _currentStep > 0) _prev();
        },
        child: CupertinoPageScaffold(
          child: DecoratedBox(
            decoration: BoxDecoration(color: TrackerColors.background),
            child: SafeArea(
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    child: showingWelcome
                        ? WelcomeOverlay(onFinished: () => setState(() => _showWelcome = false))
                        : Form(
                            key: _formKey,
                            child: Material(
                              type: MaterialType.transparency,
                              child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Step ${_currentStep + 1} of $_stepCount',
                                        style: AppType.sectionLabel(),
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      StepProgress(
                                        stepCount: _stepCount,
                                        currentStep: _currentStep,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                                    child: AnimatedSwitcher(
                                      duration: AppMotion.quick,
                                      child: KeyedSubtree(
                                        key: ValueKey(_currentStep),
                                        child: steps[_currentStep],
                                      ),
                                    ),
                                  ),
                                ),
                                _buildFooter(),
                              ],
                            ),
                            ),
                          ),
                  ),
                  if (_saveState != SaveToastState.initial)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 90,
                      child: IgnorePointer(
                        child: Center(child: SaveToast(state: _saveState)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Female / male choice: two big buttons, not a dropdown.
class _SexOption extends StatelessWidget {
  const _SexOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.buttonAll,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? TrackerColors.calorieGradient : null,
            color: selected ? null : TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            border: Border.all(color: selected ? TrackerColors.alpha(TrackerColors.onAccent, 0.2) : TrackerColors.border),
          ),
          child: Text(label, style: AppType.button(color: selected ? TrackerColors.onAccent : TrackerColors.textPrimary)),
        ),
      ),
    );
  }
}
