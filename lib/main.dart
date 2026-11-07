class XFireSliderTrackShape extends RectangularSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = true,
    bool isDiscrete = true,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      enabled: isEnabled,
    );

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blueAccent
      ..style = PaintingStyle.fill;

    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white12
      ..style = PaintingStyle.fill;

    // Черная разделительная полоска перед бегунком
    final Paint dividerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final Radius radius = Radius.circular(trackRect.height / 2);

    // Рисуем неактивную часть (справа от бегунка)
    final Rect inactiveRect = Rect.fromLTRB(thumbCenter.dx, trackRect.top, trackRect.right, trackRect.bottom);
    context.canvas.drawRRect(RRect.fromRectAndRadius(inactiveRect, radius), inactivePaint);

    // Рисуем активную часть (слева от бегунка) с небольшим отступом для черной полоски
    final double dividerWidth = 3.0; // Толщина черной полоски
    final Rect activeRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbCenter.dx - dividerWidth, trackRect.bottom);
    context.canvas.drawRRect(RRect.fromRectAndRadius(activeRect, radius), activePaint);

    // Рисуем саму черную полоску перед бегунком
    final Rect dividerRect = Rect.fromLTRB(thumbCenter.dx - dividerWidth, trackRect.top, thumbCenter.dx, trackRect.bottom);
    context.canvas.drawRect(dividerRect, dividerPaint);
  }
}

class XFireSliderCard extends StatelessWidget {
  final String title;
  final String commandName;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const XFireSliderCard({
    super.key,
    required this.title,
    required this.commandName,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(commandName, style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    "${value.toStringAsFixed(value.truncate() == value ? 0 : 2)} $unit",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Слайдер с отступом 3 мм, толстым треком 6.0, кружком 10.0 и черной полоской впереди
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: SizedBox(
                width: double.infinity,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackShape: XFireSliderTrackShape(),
                    trackHeight: 6.0,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
