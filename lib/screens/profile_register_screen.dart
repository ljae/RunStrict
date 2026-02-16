import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/country_utils.dart';

class ProfileRegisterScreen extends StatefulWidget {
  const ProfileRegisterScreen({super.key});

  @override
  State<ProfileRegisterScreen> createState() => _ProfileRegisterScreenState();
}

class _ProfileRegisterScreenState extends State<ProfileRegisterScreen> {
  final _usernameController = TextEditingController();
  final _manifestoController = TextEditingController();

  Timer? _debounceTimer;
  String? _selectedSex;
  String? _selectedNationality;
  DateTime? _birthday;

  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _manifestoController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();

    setState(() {
      _isUsernameAvailable = null;
    });

    if (value.isEmpty) return;

    if (value.length > 20) {
      // Max length handled by maxLength property, but good to be safe
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      try {
        final isAvailable = await AuthService().checkUsernameAvailable(value);
        if (mounted) {
          setState(() {
            _isUsernameAvailable = isAvailable;
            _isCheckingUsername = false;
          });
        }
      } catch (e) {
        debugPrint('Error checking username: $e');
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = null; // Reset on error
          });
        }
      }
    });
  }

  void _selectBirthday() {
    final now = DateTime.now();
    final initialDate =
        _birthday ?? DateTime(now.year - 18, now.month, now.day);
    final minDate = DateTime(1940);
    final maxDate = DateTime(now.year - 10, now.month, now.day);

    DateTime tempDate = initialDate;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 280,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header bar with Cancel / Done
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.sora(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _birthday = tempDate;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Done',
                      style: GoogleFonts.sora(
                        color: AppTheme.electricBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Wheel picker
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: minDate,
                  maximumDate: maxDate,
                  backgroundColor: AppTheme.surfaceColor,
                  onDateTimeChanged: (DateTime date) {
                    tempDate = date;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final appState = context.read<AppStateProvider>();
      await appState.completeProfileRegistration(
        username: _usernameController.text.trim(),
        sex: _selectedSex!,
        birthday: _birthday!,
        nationality: _selectedNationality,
        manifesto: _manifestoController.text.trim().isEmpty
            ? null
            : _manifestoController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/season-register');
      }
    } catch (e) {
      debugPrint('Profile registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration failed. Please try again.',
              style: GoogleFonts.sora(color: Colors.white),
            ),
            backgroundColor: AppTheme.athleticRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool get _canSubmit {
    final username = _usernameController.text.trim();
    return username.isNotEmpty &&
        username.length <= 20 &&
        (_isUsernameAvailable == true) &&
        _selectedSex != null &&
        _birthday != null &&
        _selectedNationality != null &&
        !_isSubmitting &&
        !_isCheckingUsername;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundStart,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'PROFILE',
                style: AppTheme.themeData.textTheme.headlineLarge,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Set up your runner identity',
                style: AppTheme.themeData.textTheme.bodyMedium,
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Username Input
              Text(
                'RUNNER ID',
                style: AppTheme.themeData.textTheme.labelLarge?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextField(
                controller: _usernameController,
                onChanged: _onUsernameChanged,
                maxLength: 20,
                style: GoogleFonts.sora(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter unique ID',
                  counterText: '', // Hide default counter
                  suffixIcon: _buildUsernameSuffix(),
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Nationality Selection
              Text(
                'REGION',
                style: AppTheme.themeData.textTheme.labelLarge?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CountryUtils.countries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final country = CountryUtils.countries[index];
                    final isSelected = _selectedNationality == country['code'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedNationality = country['code'];
                        });
                      },
                      child: Container(
                        width: 60,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.electricBlue.withValues(alpha: 0.2)
                              : AppTheme.surfaceColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.electricBlue
                                : Colors.white.withValues(alpha: 0.1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            country['flag']!,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Sex Selection
              Text(
                'SEX',
                style: AppTheme.themeData.textTheme.labelLarge?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Row(
                children: [
                  _buildSexChip('Male', 'male'),
                  const SizedBox(width: AppTheme.spacingM),
                  _buildSexChip('Female', 'female'),
                  const SizedBox(width: AppTheme.spacingM),
                  _buildSexChip('Other', 'other'),
                ],
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Birthday
              Text(
                'BIRTHDAY',
                style: AppTheme.themeData.textTheme.labelLarge?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              GestureDetector(
                onTap: _selectBirthday,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _birthday == null
                            ? 'Select birthday'
                            : DateFormat('MMM d, yyyy').format(_birthday!),
                        style: GoogleFonts.sora(
                          color: _birthday == null
                              ? AppTheme.textSecondary.withValues(alpha: 0.5)
                              : AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Manifesto
              Text(
                'MANIFESTO (OPTIONAL)',
                style: AppTheme.themeData.textTheme.labelLarge?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextField(
                controller: _manifestoController,
                maxLength: 30,
                style: GoogleFonts.sora(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Your motto',
                  helperText: 'Shown on leaderboard',
                  helperStyle: GoogleFonts.sora(color: AppTheme.textMuted),
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit
                        ? AppTheme.electricBlue
                        : AppTheme.surfaceColor,
                    foregroundColor: _canSubmit
                        ? Colors.white
                        : AppTheme.textMuted,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('CONTINUE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildUsernameSuffix() {
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.electricBlue),
          ),
        ),
      );
    }

    if (_usernameController.text.isEmpty) return null;

    if (_isUsernameAvailable == true) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (_isUsernameAvailable == false) {
      return const Icon(Icons.cancel, color: AppTheme.athleticRed);
    }

    return null;
  }

  Widget _buildSexChip(String label, String value) {
    final isSelected = _selectedSex == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSex = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.electricBlue
                : AppTheme.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.electricBlue
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.sora(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
