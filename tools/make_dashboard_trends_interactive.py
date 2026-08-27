from pathlib import Path

p = Path('lib/screens/restaurant_dashboard_screen_v3.dart')
s = p.read_text()

# 1) Sales Overview: hover/tap should select nearest point and painter should highlight it.
old = """              builder: (_, c) => GestureDetector(\n                behavior: HitTestBehavior.opaque,\n                onTapDown: (d) {\n                  if (values.isEmpty || c.maxWidth <= 0) return;\n                  final x = d.localPosition.dx.clamp(0.0, c.maxWidth);\n                  final index = ((x / c.maxWidth) * (values.length - 1))\n                      .round()\n                      .clamp(0, values.length - 1);\n                  setState(() => _selectedIndex = index);\n                },\n                child: Stack(\n"""
new = """              builder: (_, c) => MouseRegion(\n                onHover: (event) {\n                  if (values.isEmpty || c.maxWidth <= 0) return;\n                  final x = event.localPosition.dx.clamp(0.0, c.maxWidth);\n                  final index = ((x / c.maxWidth) * (values.length - 1))\n                      .round()\n                      .clamp(0, values.length - 1);\n                  if (_selectedIndex != index) {\n                    setState(() => _selectedIndex = index);\n                  }\n                },\n                child: GestureDetector(\n                  behavior: HitTestBehavior.opaque,\n                  onTapDown: (d) {\n                    if (values.isEmpty || c.maxWidth <= 0) return;\n                    final x = d.localPosition.dx.clamp(0.0, c.maxWidth);\n                    final index = ((x / c.maxWidth) * (values.length - 1))\n                        .round()\n                        .clamp(0, values.length - 1);\n                    setState(() => _selectedIndex = index);\n                  },\n                  child: Stack(\n"""
if old not in s:
    raise SystemExit('ERROR: Sales Overview gesture anchor not found')
s = s.replace(old, new, 1)

old = "CustomPaint(painter: _LineChartPainter(values))"
new = "CustomPaint(\n                          painter: _LineChartPainter(\n                            values,\n                            selectedIndex: selected,\n                          ),\n                        )"
if old not in s:
    raise SystemExit('ERROR: Sales Overview painter anchor not found')
s = s.replace(old, new, 1)

# Close the extra MouseRegion layer after GestureDetector.
old = """                  ],\n                ),\n              ),\n            ),\n          ),\n"""
new = """                    ],\n                  ),\n                ),\n              ),\n            ),\n          ),\n"""
if old not in s:
    raise SystemExit('ERROR: Sales Overview close anchor not found')
s = s.replace(old, new, 1)

# 2) KPI expanded trend: replace passive CustomPaint with reusable interactive chart.
old = """                            child: CustomPaint(\n                              painter: _SparklinePainter(kpi.trend, kpi.color),\n                            ),\n"""
new = """                            child: _InteractiveTrendChart(\n                              values: kpi.trend,\n                              color: kpi.color,\n                              valueMode: kpi.id == 'sales' || kpi.id == 'avg'\n                                  ? _TrendValueMode.currency\n                                  : kpi.id == 'pra'\n                                  ? _TrendValueMode.percent\n                                  : _TrendValueMode.number,\n                            ),\n"""
if old not in s:
    raise SystemExit('ERROR: KPI trend chart anchor not found')
s = s.replace(old, new, 1)

# 3) Replace line painter with selected point support.
start = s.find('class _LineChartPainter extends CustomPainter')
if start < 0:
    raise SystemExit('ERROR: _LineChartPainter not found')
end = s.find('\nclass ', start + 10)
if end < 0:
    end = len(s)
old_block = s[start:end]
new_block = r'''class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final int? selectedIndex;

  _LineChartPainter(this.values, {this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFF2F4F7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.length < 2) return;

    final maxV = math.max(1.0, values.reduce(math.max));
    final path = Path();
    final fill = Path();
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxV) * (size.height - 10);
      final point = Offset(x, y);
      points.add(point);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x246B4EFF), Color(0x006B4EFF)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = _purple
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final index = selectedIndex;
    if (index != null && index >= 0 && index < points.length) {
      final point = points[index];
      canvas.drawLine(
        Offset(point.dx, 0),
        Offset(point.dx, size.height),
        Paint()
          ..color = _purple.withValues(alpha: .18)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 6, Paint()..color = Colors.white);
      canvas.drawCircle(point, 4, Paint()..color = _purple);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.selectedIndex != selectedIndex;
}
'''
s = s[:start] + new_block + s[end:]

# 4) Add a reusable interactive 7-day trend inspector before _LineChartPainter.
insert_at = s.find('class _LineChartPainter extends CustomPainter')
widget_code = r'''
enum _TrendValueMode { currency, percent, number }

class _InteractiveTrendChart extends StatefulWidget {
  final List<double> values;
  final Color color;
  final _TrendValueMode valueMode;

  const _InteractiveTrendChart({
    required this.values,
    required this.color,
    required this.valueMode,
  });

  @override
  State<_InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<_InteractiveTrendChart> {
  int? selectedIndex;

  void _select(double x, double width) {
    if (widget.values.isEmpty || width <= 0) return;
    final index = ((x.clamp(0.0, width) / width) * (widget.values.length - 1))
        .round()
        .clamp(0, widget.values.length - 1);
    if (selectedIndex != index) setState(() => selectedIndex = index);
  }

  String _value(double value) {
    switch (widget.valueMode) {
      case _TrendValueMode.currency:
        return 'Rs ${NumberFormat('#,##0').format(value.round())}';
      case _TrendValueMode.percent:
        return '${value.toStringAsFixed(1)}%';
      case _TrendValueMode.number:
        return value % 1 == 0 ? '${value.round()}' : value.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final selected = selectedIndex ?? (values.isEmpty ? 0 : values.length - 1);
    final now = DateTime.now();
    final dates = List.generate(
      values.length,
      (i) => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: values.length - 1 - i)),
    );

    return LayoutBuilder(
      builder: (_, c) => MouseRegion(
        onHover: (event) => _select(event.localPosition.dx, c.maxWidth),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _select(d.localPosition.dx, c.maxWidth),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: CustomPaint(
                    painter: _InteractiveSparklinePainter(
                      values,
                      widget.color,
                      selectedIndex: selected,
                    ),
                  ),
                ),
              ),
              if (values.isNotEmpty)
                Positioned(
                  left: 8,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _line),
                    ),
                    child: Text(
                      '${DateFormat('dd MMM').format(dates[selected])} • ${_value(values[selected])}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int selectedIndex;

  _InteractiveSparklinePainter(
    this.values,
    this.color, {
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final span = math.max(1.0, maxV - minV);
    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / span) * size.height;
      final point = Offset(x, y);
      points.add(point);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (selectedIndex >= 0 && selectedIndex < points.length) {
      final point = points[selectedIndex];
      canvas.drawLine(
        Offset(point.dx, 0),
        Offset(point.dx, size.height),
        Paint()
          ..color = color.withValues(alpha: .18)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 6, Paint()..color = Colors.white);
      canvas.drawCircle(point, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _InteractiveSparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.selectedIndex != selectedIndex;
}

'''
s = s[:insert_at] + widget_code + s[insert_at:]

p.write_text(s)
print('OK: Sales Overview trend supports hover + click point inspection')
print('OK: selected sales point gets guide line + marker')
print('OK: expanded KPI trend charts support hover + click')
print('OK: KPI trend tooltip shows exact day + value')
