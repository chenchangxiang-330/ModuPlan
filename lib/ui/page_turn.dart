import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Turns the outgoing, painted page over the incoming page.
///
/// Give this widget a bounded viewport. Update [pageKey] only when the next
/// page's data is ready, together with [child]. Changes to [child] with the same
/// key (for example completing a task) do not turn the page. Horizontal gestures
/// are deliberately left to the caller so vertical lists remain scrollable.
class NotebookPageTurn extends StatefulWidget {
  final Object pageKey;
  final Widget child;
  final int direction;
  final Color paperColor;

  const NotebookPageTurn({
    super.key,
    required this.pageKey,
    required this.child,
    this.direction = 1,
    this.paperColor = const Color(0xfffaf8f3),
  });

  @override
  State<NotebookPageTurn> createState() => _NotebookPageTurnState();
}

class _NotebookPageTurnState extends State<NotebookPageTurn>
    with SingleTickerProviderStateMixin {
  final _pageBoundary = GlobalKey();
  late final AnimationController _controller;
  late Widget _visibleChild;
  ui.Image? _outgoingPage;
  bool _capturing = false;
  bool _reduceMotion = false;
  int _generation = 0;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _visibleChild = widget.child;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(_releaseImage);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && !_reduceMotion) {
      _cancelTurn();
      _visibleChild = widget.child;
    }
    _reduceMotion = reduce;
  }

  @override
  void didUpdateWidget(covariant NotebookPageTurn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey == widget.pageKey) {
      // A pending capture still needs the old page's painted render tree.
      if (!_capturing) _visibleChild = widget.child;
      return;
    }
    _cancelTurn();
    if (_reduceMotion) {
      _visibleChild = widget.child;
      return;
    }
    _capturing = true;
    _direction = widget.direction < 0 ? -1 : 1;
    final generation = _generation;
    // Retain the old child through this frame. This also handles a key change
    // immediately after scrolling, before the old boundary has been repainted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePage(generation);
    });
  }

  Future<void> _capturePage(int generation) async {
    if (!mounted || generation != _generation) return;
    ui.Image? image;
    try {
      final boundary =
          _pageBoundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null &&
          boundary.attached &&
          boundary.hasSize &&
          !boundary.size.isEmpty &&
          !boundary.debugNeedsPaint) {
        // One bounded snapshot, at most 1.5x, rather than a second live page
        // tree or a full-resolution screenshot on high-density phones.
        final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 1.5);
        image = await boundary.toImage(pixelRatio: ratio);
      }
    } catch (_) {
      // A disappearing surface must never prevent navigation to the new day.
      image?.dispose();
      image = null;
    }
    if (!mounted || generation != _generation) {
      image?.dispose();
      return;
    }
    setState(() {
      _capturing = false;
      _visibleChild = widget.child;
      _outgoingPage = image;
    });
    if (image != null) _controller.forward(from: 0);
  }

  void _releaseImage() {
    _outgoingPage?.dispose();
    _outgoingPage = null;
  }

  void _cancelTurn() {
    _generation++;
    _capturing = false;
    _controller.stop();
    _releaseImage();
  }

  @override
  void dispose() {
    _cancelTurn();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          // A visible old task must not activate a different, incoming task.
          ignoring: _capturing || _outgoingPage != null,
          child: RepaintBoundary(key: _pageBoundary, child: _visibleChild),
        ),
        if (_outgoingPage case final image?)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    key: const ValueKey('notebook.pageTurn.overlay'),
                    painter: _CurledPagePainter(
                      image: image,
                      progress: Curves.easeInOutCubic.transform(_controller.value),
                      direction: _direction,
                      paperColor: widget.paperColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CurledPagePainter extends CustomPainter {
  final ui.Image image;
  final double progress;
  final int direction;
  final Color paperColor;

  _CurledPagePainter({
    required this.image,
    required this.progress,
    required this.direction,
    required this.paperColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress >= 1) return;
    const strips = 36;
    final width = size.width;
    final height = size.height;
    final stripWidth = width / strips;
    final hinge = direction > 0 ? 0.0 : width;
    final baseAngle = math.pi * progress;
    final bend = math.sin(math.pi * progress) * 1.2;
    final top = <Offset>[];
    final bottom = <Offset>[];
    final angles = <double>[];
    var x = 0.0;
    var z = 0.0;

    // Integrating tangent angles makes adjacent strips a single curved sheet.
    // Project each joint once so neighboring texture strips share exact edges.
    for (var i = 0; i <= strips; i++) {
      final perspective = 1 / (1 - z / (width * 3.5));
      final screenX = hinge + direction * x * perspective;
      top.add(Offset(screenX, height * (1 - perspective) / 2));
      bottom.add(Offset(screenX, height * (1 + perspective) / 2));
      if (i < strips) {
        final angle = baseAngle + bend * ((i + .5) / strips - .5);
        angles.add(angle);
        x += stripWidth * math.cos(angle);
        z += stripWidth * math.sin(angle);
      }
    }

    final outline = Path()..addPolygon([...top, ...bottom.reversed], true);
    canvas.drawShadow(
      outline,
      const Color(0xff382919).withValues(alpha: .36),
      18 * math.sin(math.pi * progress),
      false,
    );
    final shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Float64List.fromList([
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]),
      filterQuality: FilterQuality.low,
    );
    final texturePaint = Paint()
      ..shader = shader
      ..isAntiAlias = false;
    final paperPaint = Paint()..isAntiAlias = false;
    final shadePaint = Paint()..isAntiAlias = false;

    for (var i = 0; i < strips; i++) {
      final corners = [top[i], top[i + 1], bottom[i + 1], bottom[i]];
      final quad = Path()..addPolygon(corners, true);
      if (!quad.getBounds().overlaps(Offset.zero & size)) continue;
      final angle = angles[i];
      final front = math.cos(angle) >= 0;
      paperPaint.color = front
          ? paperColor
          : Color.lerp(paperColor, const Color(0xffe4d5b8), .20)!;
      canvas.drawPath(quad, paperPaint);
      if (front) {
        final u0 = (direction > 0 ? i / strips : 1 - i / strips) * image.width;
        final u1 = (direction > 0 ? (i + 1) / strips : 1 - (i + 1) / strips) *
            image.width;
        final v1 = image.height.toDouble();
        final vertices = ui.Vertices(
          ui.VertexMode.triangles,
          [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]],
          textureCoordinates: [
            Offset(u0, 0), Offset(u1, 0), Offset(u1, v1),
            Offset(u0, 0), Offset(u1, v1), Offset(u0, v1),
          ],
        );
        canvas.drawVertices(vertices, BlendMode.srcOver, texturePaint);
        vertices.dispose();
      } else {
        // The reverse is blank ruled paper, never mirrored text.
        final rulePaint = Paint()
          ..color = const Color(0xff8e806a).withValues(alpha: .10)
          ..strokeWidth = .7;
        for (var y = 28.0; y < height; y += 28) {
          final fraction = y / height;
          canvas.drawLine(
            Offset.lerp(top[i], bottom[i], fraction)!,
            Offset.lerp(top[i + 1], bottom[i + 1], fraction)!,
            rulePaint,
          );
        }
      }
      shadePaint.color = const Color(0xff4b341c).withValues(
        alpha: math.sin(angle).abs() * .17,
      );
      canvas.drawPath(quad, shadePaint);
    }
    shader.dispose();
  }

  @override
  bool shouldRepaint(covariant _CurledPagePainter oldDelegate) =>
      image != oldDelegate.image ||
      progress != oldDelegate.progress ||
      direction != oldDelegate.direction ||
      paperColor != oldDelegate.paperColor;
}
