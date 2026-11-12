import 'package:flutter/material.dart';

/// An opaque page surface, so the same paper is included in page-turn captures.
/// The decoration stays behind the content and never intercepts input.
class NotebookPaper extends StatelessWidget {
  final Widget child;

  const NotebookPaper({super.key, required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _PaperPainter(),
    child: child,
  );
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = const Color(0xfff8f3e7));

    // Quiet ruled paper; avoiding bitmap noise keeps text crisp at any scale.
    final rule = Paint()
      ..color = const Color(0x0ca69679)
      ..strokeWidth = .5;
    for (double y = 27; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final fiber = Paint()
      ..color = const Color(0x048f816d)
      ..strokeWidth = .5;
    for (double x = 4; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fiber);
    }

    // The narrow gutter suggests a binding without darkening the reading area.
    final gutter = Rect.fromLTWH(0, 0, 18, size.height);
    canvas.drawRect(
      gutter,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0x205a4e38),
            Color(0x0a827456),
            Color(0x60ffffff),
            Color(0x00ffffff),
          ],
          stops: [0, .18, .44, 1],
        ).createShader(gutter),
    );
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) => false;
}
