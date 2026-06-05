import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/services/razorpay_payout_service.dart';
import '../viewmodels/wallet_view_model.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _bankCtrl = TextEditingController();
  final TextEditingController _accCtrl = TextEditingController();
  final TextEditingController _ifscCtrl = TextEditingController();
  final TextEditingController _upiCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();

  BankVerificationResult? _verifyResult;
  bool _isVerifying = false;
  bool _isSubmitting = false;

  // Track if we're on the success screen
  PayoutResult? _successResult;
  double? _successAmount;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _accCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyBank() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _accCtrl.text.trim().isEmpty ||
        _ifscCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fill in name, account number, and IFSC first')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _verifyResult = null;
    });

    final result = await context.read<WalletViewModel>().verifyBankAccount(
          accountNumber: _accCtrl.text.trim(),
          ifscCode: _ifscCtrl.text.trim().toUpperCase(),
          accountHolderName: _nameCtrl.text.trim(),
        );

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _verifyResult = result;
      });
    }
  }

  Future<void> _showConfirmation(WalletViewModel wallet) async {
    if (!_formKey.currentState!.validate()) return;

    final double? amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmDialog(
        name: _nameCtrl.text.trim(),
        bank: _bankCtrl.text.trim(),
        account: _accCtrl.text.trim(),
        ifsc: _ifscCtrl.text.trim().toUpperCase(),
        upi: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
        amountInr: amount,
      ),
    );

    if (confirmed == true && mounted) {
      await _submitWithdrawal(wallet, amount);
    }
  }

  Future<void> _submitWithdrawal(WalletViewModel wallet, double amount) async {
    setState(() => _isSubmitting = true);

    try {
      final PayoutResult result = await wallet.withdraw(
        accountHolderName: _nameCtrl.text.trim(),
        bankName: _bankCtrl.text.trim(),
        accountNumber: _accCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        upiId: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text.trim(),
        amountInr: amount,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _successResult = result;
          _successAmount = amount;
        });
      }
    } on StateError catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message),
              backgroundColor: const Color(0xFFFF4C4C)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Withdrawal failed: $e'),
              backgroundColor: const Color(0xFFFF4C4C)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show success screen once payout succeeds
    if (_successResult != null && _successAmount != null) {
      return _SuccessScreen(
        result: _successResult!,
        amountInr: _successAmount!,
      );
    }

    // Show processing overlay
    if (_isSubmitting) {
      return const _ProcessingScreen();
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text(
          'Withdraw Money',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor:
            isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF2F4F8),
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
      ),
      body: Consumer<WalletViewModel>(
        builder: (context, wallet, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Balance card ────────────────────────────────────────
                  _BalanceCard(
                    balanceInr: wallet.balanceInr,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),

                  // ── Section: Bank Details ───────────────────────────────
                  _SectionHeader('Bank Details', isDark: isDark),
                  const SizedBox(height: 12),

                  _FormCard(
                    isDark: isDark,
                    children: [
                      _Field(
                        controller: _nameCtrl,
                        label: 'Account Holder Name',
                        icon: Icons.person_rounded,
                        hint: 'As per bank records',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter account holder name'
                            : null,
                        onChanged: (_) => setState(() => _verifyResult = null),
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: _bankCtrl,
                        label: 'Bank Name',
                        icon: Icons.account_balance_rounded,
                        hint: 'e.g. State Bank of India',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter bank name'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: _accCtrl,
                        label: 'Account Number',
                        icon: Icons.credit_card_rounded,
                        hint: '9–18 digit account number',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(18),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter account number';
                          }
                          if (v.length < 9) {
                            return 'Account number too short (min 9 digits)';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() => _verifyResult = null),
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: _ifscCtrl,
                        label: 'IFSC Code',
                        icon: Icons.qr_code_rounded,
                        hint: 'e.g. SBIN0001234',
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          LengthLimitingTextInputFormatter(11),
                          _UpperCaseFormatter(),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter IFSC code';
                          }
                          if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                              .hasMatch(v.toUpperCase())) {
                            return 'Invalid IFSC. Format: ABCD0123456';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() => _verifyResult = null),
                      ),
                    ],
                  ),

                  // ── Verify Bank Button ──────────────────────────────────
                  const SizedBox(height: 12),
                  _VerifyButton(
                    isVerifying: _isVerifying,
                    result: _verifyResult,
                    onVerify: _verifyBank,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  // ── Section: UPI (optional) ─────────────────────────────
                  _SectionHeader('UPI ID (Optional)', isDark: isDark),
                  const SizedBox(height: 12),
                  _FormCard(
                    isDark: isDark,
                    children: [
                      _Field(
                        controller: _upiCtrl,
                        label: 'UPI ID',
                        icon: Icons.smartphone_rounded,
                        hint: 'yourname@upi (optional)',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!v.contains('@')) return 'Invalid UPI format';
                          return null;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Section: Amount ─────────────────────────────────────
                  _SectionHeader('Withdrawal Amount', isDark: isDark),
                  const SizedBox(height: 12),
                  _FormCard(
                    isDark: isDark,
                    children: [
                      _Field(
                        controller: _amountCtrl,
                        label: 'Amount (₹)',
                        icon: Icons.currency_rupee_rounded,
                        hint: 'Min ₹1.00',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter withdrawal amount';
                          }
                          final double? amt = double.tryParse(v);
                          if (amt == null || amt <= 0) {
                            return 'Enter a valid amount';
                          }
                          if (amt < 1.0) {
                            return 'Minimum withdrawal is ₹1.00';
                          }
                          if (amt > wallet.balanceInr) {
                            return 'Insufficient balance (₹${wallet.balanceInr.toStringAsFixed(2)} available)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Quick amount chips
                      Wrap(
                        spacing: 8,
                        children: [10, 25, 50, 100]
                            .map((amt) => ActionChip(
                                  label: Text('₹$amt'),
                                  onPressed: wallet.balanceInr >= amt
                                      ? () => setState(
                                          () => _amountCtrl.text = '$amt.00')
                                      : null,
                                ))
                            .toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Info box ────────────────────────────────────────────
                  _InfoBox(isDark: isDark),
                ],
              ),
            ),
          );
        },
      ),

      // ── Submit FAB ──────────────────────────────────────────────────────
      floatingActionButton: Consumer<WalletViewModel>(
        builder: (context, wallet, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: FloatingActionButton.extended(
              heroTag: 'withdraw_fab',
              onPressed: _isSubmitting ? null : () => _showConfirmation(wallet),
              backgroundColor: const Color(0xFF0E4D45),
              icon: const Icon(Icons.account_balance_rounded,
                  color: Colors.white),
              label: const Text(
                'Withdraw Now',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceInr, required this.isDark});
  final double balanceInr;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E4D45), Color(0xFF145E6D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E4D45).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Balance',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${balanceInr.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white54, size: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.isDark});
  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children, required this.isDark});
  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
    );
  }
}

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
    required this.isVerifying,
    required this.result,
    required this.onVerify,
    required this.isDark,
  });

  final bool isVerifying;
  final BankVerificationResult? result;
  final VoidCallback onVerify;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bool verified = result?.success == true;
    final bool failed = result?.success == false;

    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: isVerifying ? null : onVerify,
          icon: isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0E4D45)))
              : Icon(
                  verified
                      ? Icons.verified_rounded
                      : Icons.shield_rounded,
                  size: 18,
                ),
          label: Text(isVerifying
              ? 'Verifying...'
              : verified
                  ? 'Account Verified ✓'
                  : 'Verify Bank Account'),
          style: OutlinedButton.styleFrom(
            foregroundColor: verified
                ? const Color(0xFF4CAF50)
                : const Color(0xFF0E4D45),
            side: BorderSide(
              color: verified
                  ? const Color(0xFF4CAF50)
                  : failed
                      ? const Color(0xFFFF4C4C)
                      : const Color(0xFF0E4D45),
            ),
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                verified ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: verified
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF4C4C),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result!.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: verified
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF4C4C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF2196F3), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Settlement Info',
                  style: TextStyle(
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '• NEFT: Settles within 1–3 business days\n'
                  '• UPI: Instant to same-day settlement\n'
                  '• ₹1 = 10 credits',
                  style: TextStyle(
                      color: Color(0xFF2196F3),
                      fontSize: 12,
                      height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirmation Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.name,
    required this.bank,
    required this.account,
    required this.ifsc,
    required this.upi,
    required this.amountInr,
  });

  final String name;
  final String bank;
  final String account;
  final String ifsc;
  final String? upi;
  final double amountInr;

  @override
  Widget build(BuildContext context) {
    final String maskedAcc = account.length > 4
        ? '••••${account.substring(account.length - 4)}'
        : account;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Confirm Withdrawal',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Amount highlight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E4D45).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('You are withdrawing',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '₹${amountInr.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0E4D45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow('Name', name),
          _DetailRow('Bank', bank),
          _DetailRow('Account', maskedAcc),
          _DetailRow('IFSC', ifsc),
          if (upi != null) _DetailRow('UPI', upi!),
          _DetailRow('Settlement', '1–3 business days'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0E4D45)),
          child: const Text('Confirm & Withdraw'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600))),
          Expanded(
              flex: 3,
              child:
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Processing Screen
// ─────────────────────────────────────────────────────────────────────────────
class _ProcessingScreen extends StatelessWidget {
  const _ProcessingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFF0E4D45),
              ),
            ),
            SizedBox(height: 24),
            Text('Processing Withdrawal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('Please do not close the app',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Screen
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen({
    required this.result,
    required this.amountInr,
  });

  final PayoutResult result;
  final double amountInr;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime settlement =
        result.estimatedSettlement ?? now.add(const Duration(hours: 48));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),

              // Success animation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF4CAF50), size: 60),
              ),
              const SizedBox(height: 24),

              const Text(
                'Withdrawal Initiated!',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your money is on its way',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 36),

              // Details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1A1A)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _SuccessRow('Amount',
                        '₹${amountInr.toStringAsFixed(2)}',
                        highlight: true),
                    const Divider(height: 20),
                    _SuccessRow('Transaction ID', result.transactionId),
                    _SuccessRow('Payout ID', result.payoutId),
                    _SuccessRow(
                        'Initiated on',
                        DateFormat('dd MMM yyyy, hh:mm a').format(now)),
                    _SuccessRow(
                        'Expected by',
                        DateFormat('dd MMM yyyy').format(settlement),
                        color: const Color(0xFF4CAF50)),
                    _SuccessRow('Status', 'Processing',
                        color: const Color(0xFF2196F3)),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Pop back to WalletScreen
                    Navigator.of(context)
                      ..pop()
                      ..pop();
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E4D45),
                      minimumSize: const Size.fromHeight(54)),
                  child: const Text('Back to Wallet',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  const _SuccessRow(this.label, this.value,
      {this.highlight = false, this.color});
  final String label;
  final String value;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(
                fontSize: highlight ? 16 : 13,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: label.contains('ID') ? 'monospace' : null,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upper-case text formatter
// ─────────────────────────────────────────────────────────────────────────────
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue current) {
    return current.copyWith(text: current.text.toUpperCase());
  }
}
