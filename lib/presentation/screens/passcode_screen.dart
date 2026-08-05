import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:vault/data/services/vault_service.dart';
import 'package:vault/logic/blocs/auth_bloc.dart';
import 'package:vault/presentation/screens/dashboard_screen.dart';
import 'package:vault/presentation/widgets/animated_background.dart';
import 'package:vault/presentation/widgets/glass_box.dart';

/// Passcode screen presenting PIN pad authentication, biometric trigger, touch rhythm lock, and stealth search camouflage.
class PasscodeScreen extends StatefulWidget {
  const PasscodeScreen({super.key});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> with TickerProviderStateMixin {
  final VaultService _vaultService = VaultService();
  String _inputPin = '';
  String _firstEnteredPin = '';
  bool _isSetupMode = false;
  bool _isConfirming = false;
  String _headerText = 'Enter Passcode';
  String _errorText = '';
  bool _canCheckBiometrics = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Feature State Variables
  bool _isCamouflageActive = false;
  bool _showRhythmTouchpad = false;
  final List<int> _rhythmTaps = [];
  bool _swipeDecoyDetected = false;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchResults = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _isSetupMode = !_vaultService.isPinSet;
    _headerText = _isSetupMode ? 'Create a 4-Digit Passcode' : 'Enter Your Passcode';
    _isCamouflageActive = _vaultService.isCamouflageEnabled && !_isSetupMode;

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 20.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reset();
        }
      });

    _checkBiometricsSupport();
  }

  Future<void> _checkBiometricsSupport() async {
    final canUse = await _vaultService.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _canCheckBiometrics = canUse;
    });

    if (canUse && _vaultService.isBiometricsEnabled && !_isSetupMode && !_isCamouflageActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), _authenticateBiometric);
      });
    }
  }

  void _authenticateBiometric() {
    context.read<VaultAuthBloc>().add(AuthenticateBiometricEvent(swipeDecoy: _swipeDecoyDetected));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onKeyPress(String val) {
    if (_inputPin.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorText = '';
      _inputPin += val;
    });

    if (_inputPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _processPasscode);
    }
  }

  void _onBackspace() {
    if (_inputPin.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _errorText = '';
      _inputPin = _inputPin.substring(0, _inputPin.length - 1);
    });
  }

  void _triggerError(String msg) {
    HapticFeedback.vibrate();
    _shakeController.forward();
    setState(() {
      _errorText = msg;
      _inputPin = '';
      _rhythmTaps.clear();
    });
  }

  void _processPasscode() {
    if (_isSetupMode) {
      if (!_isConfirming) {
        _firstEnteredPin = _inputPin;
        setState(() {
          _isConfirming = true;
          _headerText = 'Confirm Your Passcode';
          _inputPin = '';
        });
      } else {
        if (_inputPin == _firstEnteredPin) {
          context.read<VaultAuthBloc>().add(SetupPinEvent(_inputPin));
        } else {
          _triggerError('Passcodes do not match! Start over.');
          setState(() {
            _isConfirming = false;
            _headerText = 'Create a 4-Digit Passcode';
            _firstEnteredPin = '';
          });
        }
      }
    } else {
      context.read<VaultAuthBloc>().add(VerifyPinEvent(_inputPin));
    }
  }

  void _triggerFakeCrash() {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Row(
          children: [
            Icon(Icons.report_problem, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('System Alert', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Google Play Services keeps stopping. Access to secure sandbox storage has been terminated by the operating system.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            child: const Text('Close App', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _onRhythmTap() {
    HapticFeedback.lightImpact();
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _rhythmTaps.add(now);
    });

    if (_rhythmTaps.length == 4) {
      final List<int> intervals = [];
      for (int i = 0; i < _rhythmTaps.length - 1; i++) {
        intervals.add(_rhythmTaps[i + 1] - _rhythmTaps[i]);
      }

      final verified = _verifyRhythm(intervals);
      if (verified) {
        HapticFeedback.mediumImpact();
        _unlockWithStoredPin();
      } else {
        _triggerError('Incorrect rhythm pattern');
      }
    }
  }

  bool _verifyRhythm(List<int> enteredIntervals) {
    final savedStr = _vaultService.rhythmPattern;
    if (savedStr.isEmpty) return false;
    final savedIntervals = savedStr.split(',').map((x) => int.parse(x)).toList();
    if (enteredIntervals.length != savedIntervals.length) return false;

    for (int i = 0; i < enteredIntervals.length; i++) {
      final diff = (enteredIntervals[i] - savedIntervals[i]).abs();
      if (diff > 350) {
        return false;
      }
    }
    return true;
  }

  Future<void> _unlockWithStoredPin() async {
    final pin = await const FlutterSecureStorage().read(key: 'vault_master_pin');
    if (pin != null) {
      if (!mounted) return;
      context.read<VaultAuthBloc>().add(VerifyPinEvent(pin));
    } else {
      _triggerError('Rhythm cached key empty. Unlock with PIN once.');
      setState(() {
        _showRhythmTouchpad = false;
      });
    }
  }

  Widget _buildCamouflageView() {
    if (_showSearchResults) {
      return _buildSearchResultsView();
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onDoubleTap: () {
                HapticFeedback.mediumImpact();
                _authenticateBiometric();
              },
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853)],
                ).createShader(bounds),
                child: const Text(
                  'WebSearch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -2.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            GlassBox(
              blur: 15,
              opacity: 0.05,
              borderRadius: 30,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: _onSearchSubmit,
                      decoration: const InputDecoration(
                        hintText: 'Search the web...',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic_none, color: Colors.white30),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _authenticateBiometric();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => _onSearchSubmit(_searchController.text),
                  child: const Text('Search', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _onSearchSubmit('trending security news');
                  },
                  child: const Text('Trending Now', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _showSearchResults = false;
                    _searchController.clear();
                  });
                },
              ),
              Expanded(
                child: GlassBox(
                  blur: 10,
                  opacity: 0.04,
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onSubmitted: _onSearchSubmit,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                'About 4,210,000 results for "$_searchQuery"',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _buildFakeResultTile(
                title: 'Official Web Search - Explore trending items',
                url: 'https://www.websearch.com/trends/$_searchQuery',
                snippet: 'Find news, articles, and real-time results for $_searchQuery. Find updated descriptions on our main page.',
              ),
              const SizedBox(height: 24),
              _buildFakeResultTile(
                title: '$_searchQuery - Wikipedia page description',
                url: 'https://en.wikipedia.org/wiki/$_searchQuery',
                snippet: '$_searchQuery is a globally searched query. Read about the history, definition, and general information about this topic.',
              ),
              const SizedBox(height: 24),
              _buildFakeResultTile(
                title: 'Latest news and updates about $_searchQuery',
                url: 'https://www.technews.com/search?q=$_searchQuery',
                snippet: 'Get expert analysis, breaking articles, and forum community conversations regarding $_searchQuery.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFakeResultTile({required String title, required String url, required String snippet}) {
    return GlassBox(
      blur: 5,
      opacity: 0.02,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      glowBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(url, style: const TextStyle(color: Colors.green, fontSize: 11), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(snippet, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  void _onSearchSubmit(String val) {
    final query = val.trim();
    if (query.isEmpty) return;

    HapticFeedback.lightImpact();

    if (RegExp(r'^\d{4}$').hasMatch(query)) {
      _inputPin = query;
      _processPasscode();
      return;
    }

    setState(() {
      _searchQuery = query;
      _showSearchResults = true;
    });
  }

  Widget _buildPasscodeView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(
          _isSetupMode ? Icons.shield_outlined : Icons.lock_outline_rounded,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          _showRhythmTouchpad ? 'Tap Your Rhythm' : _headerText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: Text(
            _errorText,
            style: const TextStyle(
              color: Color(0xFFFF5252),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 40),

        if (_showRhythmTouchpad)
          _buildRhythmTouchpad()
        else
          _buildPinDotsAndKeypad(),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRhythmTouchpad() {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isTapped = index < _rhythmTaps.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTapped ? Theme.of(context).colorScheme.primary : Colors.white10,
                  border: Border.all(color: isTapped ? Theme.of(context).colorScheme.primary : Colors.white30),
                ),
              );
            }),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: GestureDetector(
              onTap: _onRhythmTap,
              child: GlassBox(
                blur: 20,
                opacity: 0.05,
                borderRadius: 32,
                padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'TAP HERE IN RHYTHM',
                        style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.pin, size: 16, color: Colors.white54),
            label: const Text('Use PIN Unlock', style: TextStyle(color: Colors.white54)),
            onPressed: () {
              setState(() {
                _showRhythmTouchpad = false;
                _rhythmTaps.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPinDotsAndKeypad() {
    return Expanded(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final offset = _shakeAnimation.value * (1.5 * (_shakeController.value - 0.5)).sign;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isActive = index < _inputPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const Spacer(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
            child: GlassBox(
              blur: 20,
              opacity: 0.04,
              borderRadius: 32,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBiometricButton(),
                      _buildNumberButton('0'),
                      _buildBackspaceButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_vaultService.isRhythmLockEnabled && !_isSetupMode) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.music_note_outlined, size: 16, color: Colors.white54),
              label: const Text('Use Rhythm Unlock', style: TextStyle(color: Colors.white54)),
              onPressed: () {
                setState(() {
                  _showRhythmTouchpad = true;
                  _inputPin = '';
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VaultAuthBloc, VaultAuthState>(
      listener: (context, state) {
        if (state is VaultAuthUnlockedState) {
          HapticFeedback.mediumImpact();
          _navigateToDashboard();
        } else if (state is VaultAuthErrorState) {
          if (_isCamouflageActive && state.message == 'Incorrect Passcode') {
            setState(() {
              _searchQuery = _inputPin;
              _showSearchResults = true;
              _errorText = '';
              _inputPin = '';
            });
          } else {
            _triggerError(state.message);
          }
        } else if (state is VaultAuthFakeCrashState) {
          _triggerFakeCrash();
        }
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
            setState(() {
              _swipeDecoyDetected = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Decoy authorization sequence armed.'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          }
        },
        child: Scaffold(
          body: AnimatedBackground(
            child: SafeArea(
              child: _isCamouflageActive
                  ? _buildCamouflageView()
                  : _buildPasscodeView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> values) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: values.map((val) => _buildNumberButton(val)).toList(),
    );
  }

  Widget _buildNumberButton(String value) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onKeyPress(value),
          customBorder: const CircleBorder(),
          splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return SizedBox(
      width: 70,
      height: 70,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onBackspace,
          customBorder: const CircleBorder(),
          splashColor: Colors.redAccent.withValues(alpha: 0.15),
          highlightColor: Colors.redAccent.withValues(alpha: 0.05),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    final showButton = _canCheckBiometrics && _vaultService.isBiometricsEnabled && !_isSetupMode;
    return SizedBox(
      width: 70,
      height: 70,
      child: showButton
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _authenticateBiometric,
                customBorder: const CircleBorder(),
                splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                child: Center(
                  child: Icon(
                    Icons.fingerprint_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
              ),
            )
          : const SizedBox(),
    );
  }
}
