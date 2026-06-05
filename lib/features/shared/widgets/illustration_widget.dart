import 'package:flutter/material.dart';

class IllustrationWidget extends StatelessWidget {
  const IllustrationWidget({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IllustrationPainter(cs.primary, cs.secondary),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter(this.primary, this.secondary);

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..isAntiAlias = true;

    // soft background blob
    p.color = primary.withOpacity(0.12);
    canvas.drawOval(Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.7), p);

    // inner circle
    p.color = secondary.withOpacity(0.22);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.35), size.width * 0.28, p);

    // book-like rectangle
    p.color = primary;
    final RRect book = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.45, size.width * 0.76, size.height * 0.36),
      const Radius.circular(10),
    );
    canvas.drawRRect(book, p);

    // highlight stripe
    p.color = Colors.white.withOpacity(0.14);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.2, size.height * 0.5, size.width * 0.5, size.height * 0.06), p);

    // small accent circle
    p.color = secondary;
    canvas.drawCircle(Offset(size.width * 0.28, size.height * 0.3), size.width * 0.06, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
