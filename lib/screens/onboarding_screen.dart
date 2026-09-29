import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/glass.dart';
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
  static const int _stepCount = 3;
  bool _showWelcome = true;

  String _weightUnit = 'kg';
  DateTime? _dateOfBirth;
  Gender _gender = Gender.male;
  ActivityLevel _activity = ActivityLevel.sedentary;
  Goal _goal = Goal.maintain;
  SaveToastState _saveState = SaveToastState.initial;

  /// Material bridge: the step forms use Material inputs, so we hand them the
  /// same Obsidian palette instead of the default light scheme.
  ThemeData get _materialTheme {
    final scheme = const ColorScheme.dark(
      primary: TrackerColors.accentStart,
      onPrimary: TrackerColors.textPrimary,
      secondary: TrackerColors.accentEnd,
      surface: TrackerColors.surface,
      onSurface: TrackerColors.textPrimary,
      error: TrackerColors.error,
      onError: TrackerColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
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
        floatingLabelStyle: AppType.caption(color: TrackerColors.accentStart, size: 12),
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
    _weightController.text = p.weightKg.toString();
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_dateOfBirth == null) {
          showAppDialog(
            context: context,
            title: 'Date of birth',
            message: 'Please select your date of birth.',
            confirmLabel: 'OK',
          );
          return false;
        }
        return true;
      case 1:
        return _formKey.currentState?.validate() ?? false;
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

  Future<void> _submit() async {
    if (_dateOfBirth == null) return;
    setState(() => _saveState = SaveToastState.loading);

    try {
      final feet = int.tryParse(_heightFeetController.text) ?? 0;
      final inches = double.tryParse(_heightInchesController.text) ?? 0;
      final heightCm = (feet * 12 + inches) * 2.54;
      final rawWeight = double.tryParse(_weightController.text) ?? 0;
      final weightKg = _weightUnit == 'kg' ? rawWeight : rawWeight * 0.45359237;

      final profile = UserProfile(
        weightKg: weightKg,
        heightCm: heightCm,
        dateOfBirth: _dateOfBirth!,
        gender: _gender,
        activityLevel: _activity,
        goal: _goal,
      );

      await ref.read(userProfileProvider.notifier).saveProfile(profile);
      if (!mounted) return;
      setState(() => _saveState = SaveToastState.success);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() => _saveState = SaveToastState.initial);
        await showAppDialog(
          context: context,
          title: 'Could not save',
          message: 'Could not save your profile: $e',
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

  Widget _sectionHeader(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TrackerColors.alpha(color, 0.12),
            borderRadius: AppRadii.smallAll,
            border: Border.all(color: TrackerColors.alpha(color, 0.24), width: 1),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppType.title().copyWith(fontSize: 18)),
      ],
    );
  }

  Future<void> _pickDateOfBirth() async {
    var selected = _dateOfBirth ?? DateTime(2000, 1, 1);

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
                maximumDate: DateTime.now(),
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

  Widget _buildAboutYouStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('About You', Icons.cake_outlined, TrackerColors.macroProtein),
          const SizedBox(height: AppSpacing.xl),
          GestureDetector(
            onTap: _pickDateOfBirth,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                suffixIcon: Icon(Icons.calendar_today, size: 16),
              ),
              child: Text(
                _dateOfBirth == null
                    ? 'Tap to select'
                    : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                style: AppType.body(size: 15),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<Gender>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            dropdownColor: TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            style: AppType.body(size: 15),
            icon: const Icon(Icons.expand_more, color: TrackerColors.textTertiary, size: 18),
            items: Gender.values
                .map(
                  (g) => DropdownMenuItem(
                    value: g,
                    child: Text(
                      g.toString().split('.').last.toUpperCase(),
                      style: AppType.body(size: 15),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _gender = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMetricsStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Body Metrics', Icons.straighten, TrackerColors.accentStart),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppType.body(size: 15),
                  decoration: const InputDecoration(labelText: 'Weight'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: TrackerColors.surfaceElevated,
                    borderRadius: AppRadii.buttonAll,
                    border: Border.all(color: TrackerColors.border, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _weightUnit,
                      dropdownColor: TrackerColors.surfaceElevated,
                      borderRadius: AppRadii.buttonAll,
                      icon: const Icon(Icons.expand_more, color: TrackerColors.textTertiary, size: 18),
                      style: AppType.body(size: 15),
                      items: const [
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'lb', child: Text('lb')),
                      ],
                      onChanged: (v) => setState(() => _weightUnit = v!),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightFeetController,
                  keyboardType: TextInputType.number,
                  style: AppType.body(size: 15),
                  decoration: const InputDecoration(labelText: 'Height (ft)'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _heightInchesController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppType.body(size: 15),
                  decoration: const InputDecoration(labelText: 'Height (in)'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Lifestyle', Icons.local_fire_department_outlined, TrackerColors.macroCarbs),
          const SizedBox(height: AppSpacing.xl),
          DropdownButtonFormField<ActivityLevel>(
            initialValue: _activity,
            decoration: const InputDecoration(labelText: 'Activity level'),
            dropdownColor: TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            style: AppType.body(size: 15),
            icon: const Icon(Icons.expand_more, color: TrackerColors.textTertiary, size: 18),
            items: ActivityLevel.values
                .map(
                  (a) => DropdownMenuItem(
                    value: a,
                    child: Text(
                      a.toString().split('.').last.replaceAll('_', ' ').toUpperCase(),
                      style: AppType.body(size: 15),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _activity = v!),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<Goal>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Goal'),
            dropdownColor: TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            style: AppType.body(size: 15),
            icon: const Icon(Icons.expand_more, color: TrackerColors.textTertiary, size: 18),
            items: Goal.values
                .map(
                  (g) => DropdownMenuItem(
                    value: g,
                    child: Text(g.toString().split('.').last.toUpperCase(), style: AppType.body(size: 15)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _goal = v!),
          ),
        ],
      ),
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
              label: _currentStep == 2 ? 'Finish' : 'Next',
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
      _buildLifestyleStep(),
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
            decoration: const BoxDecoration(color: TrackerColors.background),
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
