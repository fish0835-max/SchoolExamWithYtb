import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/config/app_config.dart';

class PinGateScreen extends ConsumerStatefulWidget {
  const PinGateScreen({super.key});

  @override
  ConsumerState<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends ConsumerState<PinGateScreen> {
  final List<String> _enteredDigits = [];
  bool _isError = false;
  bool _isLoading = false;
  String _statusMessage = '請輸入家長 PIN 碼';

  Future<void> _onDigitTap(String digit) async {
    if (_enteredDigits.length >= AppConfig.pinMaxLength) return;

    setState(() {
      _enteredDigits.add(digit);
      _isError = false;
    });

    if (_enteredDigits.length >= AppConfig.pinMinLength) {
      final pin = _enteredDigits.join();
      if (_enteredDigits.length == AppConfig.pinMinLength ||
          _enteredDigits.length == AppConfig.pinMaxLength) {
        await _verifyPin(pin);
      }
    }
  }

  Future<void> _verifyPin(String pin) async {
    setState(() => _isLoading = true);

    final settings = ref.read(settingsServiceProvider);
    final hasPin = await settings.hasPin();

    if (!hasPin) {
      // First time: set the PIN
      setState(() {
        _statusMessage = '首次使用，請再次輸入以確認 PIN 碼';
        _enteredDigits.clear();
        _isLoading = false;
      });
      // Simple confirmation flow: just accept first entry as PIN
      await settings.setPin(pin);
      ref.read(parentModeProvider.notifier).state = true;
      if (mounted) context.go('/parent/dashboard');
      return;
    }

    final isValid = await settings.verifyPin(pin);
    setState(() => _isLoading = false);

    if (isValid) {
      ref.read(parentModeProvider.notifier).state = true;
      if (mounted) context.go('/parent/dashboard');
    } else {
      setState(() {
        _isError = true;
        _statusMessage = 'PIN 碼錯誤，請再試一次';
        _enteredDigits.clear();
      });
    }
  }

  void _onDelete() {
    if (_enteredDigits.isEmpty) return;
    setState(() {
      _enteredDigits.removeLast();
      _isError = false;
      _statusMessage = '請輸入家長 PIN 碼';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                '家長模式',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: _isError
                      ? Colors.red[300]
                      : Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  AppConfig.pinMinLength,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _enteredDigits.length
                          ? (_isError ? Colors.red : Colors.white)
                          : Colors.white.withOpacity(0.25),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Number pad
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.white)
              else
                _buildNumPad(),

              const SizedBox(height: 32),

              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    return Column(
      children: [
        _NumRow(digits: ['1', '2', '3'], onTap: _onDigitTap),
        const SizedBox(height: 12),
        _NumRow(digits: ['4', '5', '6'], onTap: _onDigitTap),
        const SizedBox(height: 12),
        _NumRow(digits: ['7', '8', '9'], onTap: _onDigitTap),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _NumButton(digit: '', onTap: null), // Empty
            const SizedBox(width: 12),
            _NumButton(digit: '0', onTap: () => _onDigitTap('0')),
            const SizedBox(width: 12),
            _DeleteButton(onTap: _onDelete),
          ],
        ),
      ],
    );
  }
}

class _NumRow extends StatelessWidget {
  final List<String> digits;
  final void Function(String) onTap;

  const _NumRow({required this.digits, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits
          .map(
            (d) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _NumButton(digit: d, onTap: () => onTap(d)),
            ),
          )
          .toList(),
    );
  }
}

class _NumButton extends StatelessWidget {
  final String digit;
  final VoidCallback? onTap;

  const _NumButton({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (digit.isEmpty) {
      return const SizedBox(width: 72, height: 72);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
