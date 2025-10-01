import 'dart:math';

import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_color_picker.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ReefWidgetModel extends SingleTopicNTWidgetModel {
  @override
  String type = 'Reef';

  Color _selectedSideColor = Colors.orange;
  Color _defaultSideColor = Colors.cyan;
  int _selectedSide = 0; // 0-5 for the six sides of the hexagon

  Color get selectedSideColor => _selectedSideColor;

  set selectedSideColor(Color value) {
    _selectedSideColor = value;
    refresh();
  }

  Color get defaultSideColor => _defaultSideColor;

  set defaultSideColor(Color value) {
    _defaultSideColor = value;
    refresh();
  }

  int get selectedSide => _selectedSide;

  ReefWidgetModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    Color selectedSideColor = Colors.orange,
    Color defaultSideColor = Colors.cyan,
    super.dataType = 'int',
    super.period,
  })  : _selectedSideColor = selectedSideColor,
        _defaultSideColor = defaultSideColor,
        super();

  ReefWidgetModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _selectedSideColor = Color(
      tryCast(jsonData['selected_side_color']) ?? Colors.orange.toARGB32(),
    );
    _defaultSideColor = Color(
      tryCast(jsonData['default_side_color']) ?? Colors.cyan.toARGB32(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'selected_side_color': _selectedSideColor.toARGB32(),
      'default_side_color': _defaultSideColor.toARGB32(),
    };
  }

  @override
  List<String> getAvailableDisplayTypes() {
    return [
      ReefWidget.widgetType,
    ];
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      Center(
        child: Text(
          'Reef Widget Settings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: DialogColorPicker(
                onColorPicked: (color) {
                  selectedSideColor = color;
                },
                label: 'Selected Side Color',
                initialColor: selectedSideColor,
                defaultColor: Colors.orange,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: DialogColorPicker(
                onColorPicked: (color) {
                  defaultSideColor = color;
                },
                label: 'Default Side Color',
                initialColor: defaultSideColor,
                defaultColor: Colors.cyan,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Topic: $topic',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 5),
      Text(
        'Publish an integer value (0-5) to select which side of the hexagon to highlight.',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ];
  }

  void updateSelectedSide() {
    if (subscription?.value == null) {
      return;
    }

    int? newSelectedSide = subscription!.value?.tryCast<int>();
    if (newSelectedSide != null &&
        newSelectedSide >= 0 &&
        newSelectedSide <= 5) {
      _selectedSide = newSelectedSide;
      refresh();
    }
  }
}

class ReefWidget extends NTWidget {
  static const String widgetType = 'Reef';

  const ReefWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ReefWidgetModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: model.subscription ?? ValueNotifier(null),
      builder: (context, child) {
        model.updateSelectedSide();

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
                      selectedSideColor: model.selectedSideColor,
                      defaultSideColor: model.defaultSideColor,
                      strokeWidth: 36.0,
                    ),
                    child: Container(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Side ${model.selectedSide + 1}',
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

    // Draw each side of the hexagon
    for (int i = 0; i < 6; i++) {
      final paint = Paint()
        ..color = (i == selectedSide) ? selectedSideColor : defaultSideColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final startVertex = vertices[i];
      final endVertex = vertices[(i + 1) % 6];

      canvas.drawLine(startVertex, endVertex, paint);
    }

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
