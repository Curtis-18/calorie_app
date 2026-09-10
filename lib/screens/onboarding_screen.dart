import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
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

  // Class-level constant for the radius
  static const double _borderRadius = 28.0;

  int _currentStep = 0;
  static const int _stepCount = 3;
  bool _showWelcome = true;
  
  String _weightUnit = 'kg';
  DateTime? _dateOfBirth;
  Gender _gender = Gender.male;
  ActivityLevel _activity = ActivityLevel.sedentary;
  Goal _goal = Goal.maintain;
  SaveToastState _saveState = SaveToastState.initial;

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
          showCupertinoDialog<void>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              content: const Text('Please select your date of birth'),
              actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
            ),
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
        showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            content: Text('Could not save your profile: $e'),
            actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
          ),
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
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(label, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
      ],
    );
  }

  Widget _buildAboutYouStep() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('About You', Icons.cake_outlined, TrackerColors.secondary),
          const SizedBox(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(_borderRadius),
            onTap: () async {
              final picked = await showCupertinoModalPopup<DateTime>(
                context: context,
                builder: (context) => Container(
                  height: 280,
                  color: CupertinoColors.systemBackground,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _dateOfBirth ?? DateTime(2000, 1, 1),
                    minimumDate: DateTime(1920),
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (date) => _dateOfBirth = date,
                  ),
                ),
              );
              if (picked != null) setState(() => _dateOfBirth = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date of birth'),
              child: Text(
                _dateOfBirth == null
                    ? 'Tap to select'
                    : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: TrackerColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Gender>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            dropdownColor: TrackerColors.surface,
            items: Gender.values
                .map((g) => DropdownMenuItem(
                      value: g, 
                      child: Text(g.toString().split('.').last.toUpperCase(), style: const TextStyle(color: TrackerColors.textPrimary))
                    ))
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
          _sectionHeader('Body Metrics', Icons.straighten, TrackerColors.primary),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: TrackerColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Weight'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: TrackerColors.divider,
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _weightUnit,
                    dropdownColor: TrackerColors.surface,
                    items: const [
                      DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(color: TrackerColors.textPrimary))),
                      DropdownMenuItem(value: 'lb', child: Text('lb', style: TextStyle(color: TrackerColors.textPrimary))),
                    ],
                    onChanged: (v) => setState(() => _weightUnit = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightFeetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: TrackerColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Height (ft)'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _heightInchesController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: TrackerColors.textPrimary),
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
          _sectionHeader('Lifestyle', Icons.local_fire_department_outlined, TrackerColors.warning),
          const SizedBox(height: 20),
          DropdownButtonFormField<ActivityLevel>(
            value: _activity,
            decoration: const InputDecoration(labelText: 'Activity level'),
            dropdownColor: TrackerColors.surface,
            items: ActivityLevel.values
                .map((a) => DropdownMenuItem(
                      value: a, 
                      child: Text(a.toString().split('.').last.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: TrackerColors.textPrimary))
                    ))
                .toList(),
            onChanged: (v) => setState(() => _activity = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Goal>(
            value: _goal,
            decoration: const InputDecoration(labelText: 'Goal'),
            dropdownColor: TrackerColors.surface,
            items: Goal.values
                .map((g) => DropdownMenuItem(
                      value: g, 
                      child: Text(g.toString().split('.').last.toUpperCase(), style: const TextStyle(color: TrackerColors.textPrimary))
                    ))
                .toList(),
            onChanged: (v) => setState(() => _goal = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            CupertinoButton(onPressed: _prev, child: const Text('Back')),
          if (_currentStep == 0) const SizedBox.shrink(),
          CupertinoButton.filled(
            onPressed: _next,
            child: Text(_currentStep == 2 ? 'Finish' : 'Next'),
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

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) _prev();
      },
      child: CupertinoPageScaffold(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: showingWelcome
                ? WelcomeOverlay(onFinished: () => setState(() => _showWelcome = false))
                : Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: StepProgress(stepCount: _stepCount, currentStep: _currentStep),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
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
      ),
    );
  }
}
