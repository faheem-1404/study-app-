import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/redemption_request.dart';
import '../../../core/models/payout_method.dart';
import '../../shared/widgets/status_timeline.dart';
import '../../wallet/viewmodels/wallet_view_model.dart';

class RedemptionReceiptScreen extends StatelessWidget {
  const RedemptionReceiptScreen({super.key, required this.request});

  final RedemptionRequest request;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redemption Receipt'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: cs.primary,
                      child: const Icon(Icons.payments_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(request.method.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(request.destination, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Text('\$${request.cashValue.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            StatusTimeline(status: request.status),
            const SizedBox(height: 20),
            Text('Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _row('Request ID', request.id),
                    _row('Credits', '${request.credits.toStringAsFixed(0)}'),
                    _row('Requested', request.createdAt.toLocal().toString()),
                    _row('ETA', request.estimatedPayoutAt.toLocal().toString()),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Consumer<WalletViewModel>(builder: (context, wallet, _) {
              final bool canComplete = request.status != RedemptionStatus.completed;
              return FilledButton(
                onPressed: canComplete
                    ? () async {
                        // For the mock demo allow marking completed
                        await wallet.updateRedemptionStatus(request.id, RedemptionStatus.completed);
                        Navigator.of(context).pop();
                      }
                    : null,
                child: Text(canComplete ? 'Mark as completed (dev)' : 'Completed'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(flex: 3, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(flex: 5, child: Text(v)),
        ],
      ),
    );
  }
}
