import 'package:flutter/material.dart';
import '../../../core/models/redemption_request.dart';

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.status});

  final RedemptionStatus status;

  @override
  Widget build(BuildContext context) {
    final List<_Step> steps = <_Step>[
      _Step('Submitted', RedemptionStatus.pending),
      _Step('Processing', RedemptionStatus.processing),
      _Step('Completed', RedemptionStatus.completed),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: steps.map((s) {
        final bool active = _compareStatus(s.status, status);
        final Color color = active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.2);
        return Expanded(
          child: Column(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  s.status == RedemptionStatus.completed ? Icons.check : Icons.circle,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: active ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _compareStatus(RedemptionStatus step, RedemptionStatus current) {
    final List<RedemptionStatus> order = <RedemptionStatus>[
      RedemptionStatus.pending,
      RedemptionStatus.processing,
      RedemptionStatus.completed,
    ];
    return order.indexOf(step) <= order.indexOf(current);
  }
}

class _Step {
  _Step(this.label, this.status);
  final String label;
  final RedemptionStatus status;
}
