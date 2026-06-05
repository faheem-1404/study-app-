import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/payout_method.dart';
import '../../shared/widgets/metric_card.dart';
import '../viewmodels/wallet_view_model.dart';

class RedemptionScreen extends StatefulWidget {
  const RedemptionScreen({super.key});

  @override
  State<RedemptionScreen> createState() => _RedemptionScreenState();
}

class _RedemptionScreenState extends State<RedemptionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _destinationController = TextEditingController();
  final List<double> _presetCredits = <double>[10, 25, 50, 100];

  double _selectedCredits = 50;
  PayoutMethod _method = PayoutMethod.upi;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  String _destinationLabel(PayoutMethod method) {
    switch (method) {
      case PayoutMethod.upi:
        return 'UPI ID';
      case PayoutMethod.paypal:
        return 'PayPal email';
      case PayoutMethod.giftCard:
        return 'Gift card email';
    }
  }

  Future<void> _submitRedemption() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<WalletViewModel>().createRedemption(
            credits: _selectedCredits,
            method: _method,
            destination: _destinationController.text.trim(),
          );

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.schedule_send_rounded, size: 42),
                const SizedBox(height: 12),
                Text(
                  'Redemption submitted',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This is a mock payout flow. The request is marked as processing and will appear in your wallet history.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Redeem Credits')),
      body: Consumer<WalletViewModel>(
        builder: (context, walletViewModel, _) {
          final double cashValue = _selectedCredits / 10.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Turn credits into cash value',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This MVP uses a simple conversion rate of 10 credits = 1 currency unit.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: MetricCard(
                                title: 'Available',
                                value: walletViewModel.credits.toStringAsFixed(1),
                                subtitle: 'Spendable credits',
                                icon: Icons.account_balance_wallet_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MetricCard(
                                title: 'Value',
                                value: cashValue.toStringAsFixed(2),
                                subtitle: 'Estimated payout',
                                icon: Icons.payments_rounded,
                                accentColor: colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Choose payout amount',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _presetCredits.map((double credits) {
                            final bool selected = credits == _selectedCredits;
                            return ChoiceChip(
                              label: Text('${credits.toStringAsFixed(0)} credits'),
                              selected: selected,
                              onSelected: walletViewModel.canRedeem(credits)
                                  ? (_) {
                                      setState(() {
                                        _selectedCredits = credits;
                                      });
                                    }
                                  : null,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Payout method',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<PayoutMethod>(
                            value: _method,
                            decoration: const InputDecoration(labelText: 'Method'),
                            items: PayoutMethod.values
                                .map(
                                  (PayoutMethod method) => DropdownMenuItem<PayoutMethod>(
                                    value: method,
                                    child: Text(method.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (PayoutMethod? value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _method = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _destinationController,
                            decoration: InputDecoration(
                              labelText: _destinationLabel(_method),
                              hintText: _method.subtitle,
                            ),
                            validator: (String? value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a destination for this payout';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Mock payout details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Requests are stored locally as processing and deducted immediately from the wallet. No real transfer occurs in the MVP.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : walletViewModel.canRedeem(_selectedCredits)
                            ? _submitRedemption
                            : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Submitting...'
                          : 'Redeem ${_selectedCredits.toStringAsFixed(0)} credits',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}