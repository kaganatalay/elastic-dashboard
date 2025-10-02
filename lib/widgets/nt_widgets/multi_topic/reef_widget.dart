import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';

class ReefWidgetModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefWidget.widgetType;

  // Subscriptions
  late NT4Subscription sideSubscription;
  late NT4Subscription stateSubscription;

  int _selectedSide = 0; // 0–5
  String _state = "ready"; // default

  int get selectedSide => _selectedSide;
  String get state => _state;

  Color get stateColor {
    switch (_state) {
      case "ready":
        return Colors.red;
      case "moving":
        return Colors.yellow;
      case "done":
        return Colors.green;
      default:
        return Colors.grey; // fallback
    }
  }

  ReefWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    super.dataType,
    super.period,
  }) : super();

  ReefWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required super.jsonData,
  }) : super.fromJson();

  @override
  void initializeSubscriptions() {
    // Main topics
    sideSubscription = ntConnection.subscribe('$topic/Side', period);
    stateSubscription = ntConnection.subscribe('$topic/State', period);
  }

  @override
  List<NT4Subscription> get subscriptions => [
        sideSubscription,
        stateSubscription,
      ];

  void updateValues() {
    // Update side
    final sideValue = tryCast<int>(sideSubscription.value);
    if (sideValue != null && sideValue >= 0 && sideValue <= 5) {
      _selectedSide = sideValue;
    }

    // Update state
    final stateValue = tryCast<String>(stateSubscription.value);
    if (stateValue != null) {
      _state = stateValue;
    }

    refresh();
  }
}

class ReefWidget extends NTWidget {
  static const String widgetType = 'Reef';

  const ReefWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ReefWidgetModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([
        model.sideSubscription,
        model.stateSubscription,
      ]),
      builder: (context, child) {
        model.updateValues();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  'Reef Station',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: CustomPaint(
                    painter: ReefHexagonPainter(
                      selectedSide: model.selectedSide,
                      selectedSideColor: model.stateColor,
                      defaultSideColor: Colors.grey.shade400,
                      strokeWidth: 56.0,
                    ),
                    child: Container(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Side ${model.selectedSide + 1} (${model.state})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ReefHexagonPainter extends CustomPainter {
  final int selectedSide;
  final Color selectedSideColor;
  final Color defaultSideColor;
  final double strokeWidth;

  const ReefHexagonPainter({
    required this.selectedSide,
    required this.selectedSideColor,
    required this.defaultSideColor,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - strokeWidth;

    // Calculate hexagon vertices (rotated 30 degrees for flat top/bottom)
    List<Offset> vertices = [];
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 60) * pi / 180; // Start with flat top
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      vertices.add(Offset(x, y));
    }

    // First, draw all non-selected sides
    for (int i = 0; i < 6; i++) {
      if (i != selectedSide) {
        final paint = Paint()
          ..color = defaultSideColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final startVertex = vertices[i];
        final endVertex = vertices[(i + 1) % 6];

        canvas.drawLine(startVertex, endVertex, paint);
      }
    }

    // Then draw the selected side on top
    final selectedPaint = Paint()
      ..color = selectedSideColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startVertex = vertices[selectedSide];
    final endVertex = vertices[(selectedSide + 1) % 6];

    canvas.drawLine(startVertex, endVertex, selectedPaint);

    // Draw small circles at vertices for visual appeal
    final vertexPaint = Paint()
      ..color = defaultSideColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (final vertex in vertices) {
      canvas.drawCircle(vertex, strokeWidth / 2, vertexPaint);
    }

    // // Draw center point
    // final centerPaint = Paint()
    //   ..color = selectedSideColor.withValues(alpha: 0.8)
    //   ..style = PaintingStyle.fill;

    // canvas.drawCircle(center, strokeWidth, centerPaint);
  }

  @override
  bool shouldRepaint(ReefHexagonPainter oldDelegate) {
    return oldDelegate.selectedSide != selectedSide ||
        oldDelegate.selectedSideColor != selectedSideColor ||
        oldDelegate.defaultSideColor != defaultSideColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
