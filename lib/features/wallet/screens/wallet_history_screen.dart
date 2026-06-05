import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/models/redemption_request.dart';
import '../../../core/models/payout_method.dart';
import '../../shared/widgets/illustration_widget.dart';
import '../../wallet/viewmodels/wallet_view_model.dart';
import 'redemption_receipt_screen.dart';

class WalletHistoryScreen extends StatelessWidget {
  const WalletHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet & History'),
      ),
      body: Consumer<WalletViewModel>(
        builder: (context, wallet, _) {
          final List<RedemptionRequest> list = wallet.redemptions;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  IllustrationWidget(size: 160),
                  SizedBox(height: 16),
                  Text('No payouts yet', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final RedemptionRequest r = list[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text('${r.credits.toStringAsFixed(0)} credits • ${r.method.label}'),
                  subtitle: Text('${r.destination} • ${DateFormat.yMMMd().add_jm().format(r.createdAt)}'),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(r.status.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('\$${r.cashValue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RedemptionReceiptScreen(request: r)));
                  },
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: list.length,
          );
        },
      ),
    );
  }
}
