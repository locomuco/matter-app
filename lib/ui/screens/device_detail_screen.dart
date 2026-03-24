import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_type.dart';
import '../../models/matter_device.dart';
import '../../providers/device_provider.dart';
import '../../services/matter_channel.dart';
import '../widgets/online_badge.dart';
import 'device_settings_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().refreshDevice(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final device = provider.findById(widget.deviceId);
        if (device == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Device not found')),
          );
        }
        return _buildScaffold(context, device, provider);
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context, MatterDevice device, DeviceProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final isActive = device.isOnline && device.isOn;

    return Scaffold(
      backgroundColor: isActive ? cs.primaryContainer : cs.surface,
      appBar: AppBar(
        backgroundColor: isActive ? cs.primaryContainer : cs.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(device.deviceType.displayName,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Device settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DeviceSettingsScreen(device: device)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(
                device: device,
                onToggle: () => provider.toggle(device.id)),
            const SizedBox(height: 20),
            if (device.deviceType.hasBrightness && device.isOnline) ...[
              _BrightnessCard(
                brightness: device.brightness,
                onChanged: (v) => provider.setBrightness(device.id, v),
              ),
              const SizedBox(height: 20),
            ],
            if (device.deviceType == DeviceType.thermostat &&
                device.isOnline) ...[
              _ThermostatCard(device: device),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero card — no device icon, simplified state
// ---------------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onToggle;
  const _HeroCard({required this.device, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = device.isOnline && device.isOn;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (device.deviceType != DeviceType.thermostat)
                    OnlineBadge(isOnline: device.isOnline),
                  if (device.isOnline && device.isOn) ...[
                    const SizedBox(height: 6),
                    Text(
                      'On',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isActive ? cs.primary : cs.onSurfaceVariant,
                          ),
                    ),
                  ] else if (!device.isOnline &&
                      device.deviceType != DeviceType.thermostat) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Offline',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (device.deviceType.hasOnOff)
              Switch(
                value: device.isOn,
                onChanged: device.isOnline ? (_) => onToggle() : null,
                thumbIcon: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Icon(Icons.power_settings_new, size: 16)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brightness card
// ---------------------------------------------------------------------------

class _BrightnessCard extends StatelessWidget {
  final double brightness;
  final ValueChanged<double> onChanged;
  const _BrightnessCard({required this.brightness, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.brightness_6_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Brightness',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${(brightness * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            Slider(
              value: brightness,
              onChangeEnd: onChanged,
              onChanged: (_) {},
              min: 0.01,
              max: 1.0,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thermostat card
// ---------------------------------------------------------------------------

class _ThermostatCard extends StatefulWidget {
  final MatterDevice device;
  const _ThermostatCard({required this.device});

  @override
  State<_ThermostatCard> createState() => _ThermostatCardState();
}

class _ThermostatCardState extends State<_ThermostatCard> {
  ThermostatState? _state;
  bool   _loading = true; // kept to guard onSetpointEnd until data arrives
  int? _pendingSetpt;
  int? _pendingMode;
  String? _serialNumber;
  String? _softwareVersion;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final channel = context.read<MatterChannel>();
    final results = await Future.wait([
      channel.readThermostat(widget.device.nodeId),
      channel.readBasicInfo(widget.device.nodeId),
    ]);
    final s    = results[0] as ThermostatState?;
    final info = results[1] as ({String serialNumber, String softwareVersion})?;
    if (mounted) setState(() {
      _state           = s;
      _serialNumber    = info?.serialNumber.isNotEmpty == true    ? info!.serialNumber    : null;
      _softwareVersion = info?.softwareVersion.isNotEmpty == true ? info!.softwareVersion : null;
      _loading         = false;
    });
  }

  Future<void> _setSetpointC(double tempC) async {
    final centi = (tempC * 100).round().clamp(500, 3500);
    setState(() => _pendingSetpt = centi);
    await context.read<MatterChannel>()
        .writeHeatingSetpoint(widget.device.nodeId, centi);
    await _fetch();
    if (mounted) setState(() => _pendingSetpt = null);
  }

  Future<void> _setMode(int mode) async {
    setState(() => _pendingMode = mode);
    await context.read<MatterChannel>().writeSystemMode(widget.device.nodeId, mode);
    await _fetch();
    if (mounted) setState(() => _pendingMode = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Show dashes when data not yet available
    final measuredC = _state?.localTempC;
    final setpointC = _pendingSetpt != null
        ? _pendingSetpt! / 100.0
        : _state?.heatingSetptC;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Dial ───────────────────────────────────────────────────
            _ThermostatDial(
              measuredTempC:     measuredC,
              setpointC:         setpointC,
              supportsCooling:   _state?.supportsCooling ?? false,
              coolingSetptC:     _state?.coolingSetptC,
              onSetpointChanged: (v) =>
                  setState(() => _pendingSetpt = (v * 100).round()),
              onSetpointEnd:     _state != null ? _setSetpointC : (_) {},
            ),

            const SizedBox(height: 16),

            // ── Mode selector (centered, no label) ────────────────────
            if (_state != null)
              _ModeSelector(
                modes:    _state!.availableModes,
                current:  _pendingMode ?? _state!.systemMode,
                onSelect: _setMode,
              ),

            // ── Device info ───────────────────────────────────────────
            if (_serialNumber != null || _softwareVersion != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (_serialNumber != null)
                _InfoLine(label: 'Serial', value: _serialNumber!),
              if (_softwareVersion != null)
                _InfoLine(label: 'SW version', value: _softwareVersion!),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thermostat dial
// ---------------------------------------------------------------------------

// 5×7 dot matrix glyphs (shared subset — bit 4 = leftmost column).
const _dialGlyphs = <String, List<int>>{
  '0': [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
  '1': [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
  '2': [0x0E, 0x11, 0x01, 0x06, 0x08, 0x10, 0x1F],
  '3': [0x0E, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0E],
  '4': [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
  '5': [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
  '6': [0x0E, 0x10, 0x1E, 0x11, 0x11, 0x11, 0x0E],
  '7': [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
  '8': [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
  '9': [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x01, 0x0E],
  '.': [0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x02],
  '-': [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00],
};
int _dialCharCols(String ch) => ch == '.' ? 3 : 5;

// Arc constants
// Arc: starts at 135° (lower-left), sweeps 270° clockwise to 45° (lower-right).
// Gap is the bottom 90°. Low temp at start, high temp at end.
const _kArcStart = 135.0 * math.pi / 180.0; // radians
const _kArcSweep = 270.0 * math.pi / 180.0;
const _kTempMin  = 5.0;   // °C
const _kTempMax  = 35.0;  // °C

class _ThermostatDial extends StatefulWidget {
  final double? measuredTempC;
  final double? setpointC;       // null = data not yet loaded → show dashes
  final bool    supportsCooling;
  final double? coolingSetptC;
  final void Function(double) onSetpointChanged;
  final void Function(double) onSetpointEnd;

  const _ThermostatDial({
    required this.measuredTempC,
    required this.setpointC,
    required this.supportsCooling,
    required this.coolingSetptC,
    required this.onSetpointChanged,
    required this.onSetpointEnd,
  });

  @override
  State<_ThermostatDial> createState() => _ThermostatDialState();
}

class _ThermostatDialState extends State<_ThermostatDial> {
  double? _dragTemp; // live value while dragging, null otherwise

  double get _setpoint => _dragTemp ?? widget.setpointC ?? 20.0;

  /// Only allow drag when we have real data.
  bool get _hasData => widget.setpointC != null;

  double _angleToTemp(double angleDeg) {
    // Normalise angle relative to arc start (in degrees)
    final startDeg = _kArcStart * 180 / math.pi;
    var rel = ((angleDeg - startDeg) % 360 + 360) % 360;
    if (rel > 270) {
      // In the gap — snap to nearest endpoint
      rel = (rel - 270 < 360 - rel) ? 270 : 0;
    }
    return (_kTempMin + (rel / 270) * (_kTempMax - _kTempMin))
        .clamp(_kTempMin, _kTempMax);
  }

  void _handleDrag(Offset pos, Size size) {
    final c  = Offset(size.width / 2, size.height / 2);
    final dx = pos.dx - c.dx;
    final dy = pos.dy - c.dy;
    var angleDeg = math.atan2(dy, dx) * 180 / math.pi;
    if (angleDeg < 0) angleDeg += 360;

    final temp = _angleToTemp(angleDeg);
    final snapped = ((temp * 2).round() / 2.0)
        .clamp(_kTempMin, _kTempMax); // 0.5°C steps
    setState(() => _dragTemp = snapped);
    widget.onSetpointChanged(snapped);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final side = constraints.maxWidth; // use full card width
      return SizedBox(
        width: side,
        height: side,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            if (_hasData) _handleDrag(d.localPosition, Size(side, side));
          },
          onPanEnd: (_) {
            if (_dragTemp != null) {
              widget.onSetpointEnd(_dragTemp!);
              setState(() => _dragTemp = null);
            }
          },
          child: CustomPaint(
            painter: _DialPainter(
              measuredTempC:  widget.measuredTempC,
              setpointC:      _hasData ? _setpoint : null,
              coolingSetptC:  widget.supportsCooling ? widget.coolingSetptC : null,
            ),
          ),
        ),
      );
    });
  }
}

class _DialPainter extends CustomPainter {
  final double? measuredTempC;
  final double? setpointC;      // null → show dashes
  final double? coolingSetptC;

  const _DialPainter({
    required this.measuredTempC,
    required this.setpointC,
    this.coolingSetptC,
  });

  double _frac(double tempC) =>
      ((tempC - _kTempMin) / (_kTempMax - _kTempMin)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final center = Offset(cx, cy);
    final radius = math.min(cx, cy) - 20;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    // ── Background arc ────────────────────────────────────────────────────
    canvas.drawArc(rect, _kArcStart, _kArcSweep, false,
        Paint()
          ..color       = Colors.white.withAlpha(45)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap   = StrokeCap.round);

    // ── Active (setpoint) arc ─────────────────────────────────────────────
    if (setpointC != null) {
      final setFrac = _frac(setpointC!);
      if (setFrac > 0) {
        canvas.drawArc(rect, _kArcStart, _kArcSweep * setFrac, false,
            Paint()
              ..color       = Colors.white
              ..style       = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap   = StrokeCap.round);
      }

      // Setpoint knob
      final kAngle = _kArcStart + _kArcSweep * setFrac;
      final kPos   = center + Offset(math.cos(kAngle) * radius,
                                     math.sin(kAngle) * radius);
      canvas.drawCircle(kPos, 9.0,
          Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(kPos, 9.0,
          Paint()
            ..color       = Colors.white.withAlpha(80)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 3.0);
    }

    // ── Measured temperature tick ─────────────────────────────────────────
    if (measuredTempC != null) {
      final mAngle = _kArcStart + _kArcSweep * _frac(measuredTempC!);
      final dir    = Offset(math.cos(mAngle), math.sin(mAngle));
      canvas.drawLine(
        center + dir * (radius - 9),
        center + dir * (radius + 9),
        Paint()
          ..color       = Colors.white
          ..strokeWidth = 2.0
          ..strokeCap   = StrokeCap.round,
      );
    }

    // ── Cooling setpoint tick ─────────────────────────────────────────────
    if (coolingSetptC != null) {
      final cAngle = _kArcStart + _kArcSweep * _frac(coolingSetptC!);
      final dir    = Offset(math.cos(cAngle), math.sin(cAngle));
      canvas.drawLine(
        center + dir * (radius - 6),
        center + dir * (radius + 6),
        Paint()
          ..color       = Colors.lightBlue.withAlpha(200)
          ..strokeWidth = 1.5
          ..strokeCap   = StrokeCap.round,
      );
    }

    // ── Centre: setpoint in dot matrix (upper half) ───────────────────────
    final setLabel = setpointC != null
        ? setpointC!.toStringAsFixed(1)
        : '--.-';
    _paintDotMatrix(canvas, center + Offset(0, -radius * 0.18), setLabel,
        maxW: radius * 1.0, maxH: radius * 0.30, color: Colors.white);

    // ── Centre: measured in dot matrix (lower half, smaller) ─────────────
    final measLabel = measuredTempC != null
        ? measuredTempC!.toStringAsFixed(1)
        : '--.-';
    _paintDotMatrix(canvas, center + Offset(0, radius * 0.22), measLabel,
        maxW: radius * 0.70, maxH: radius * 0.20,
        color: Colors.white.withAlpha(160));
  }

  /// Draws [text] centred on [centre] using a 5×7 dot matrix font,
  /// fitting within [maxW] × [maxH] logical pixels.
  void _paintDotMatrix(Canvas canvas, Offset centre, String text,
      {required double maxW,
      required double maxH,
      required Color color}) {
    final chars = text.characters.toList();
    final n = chars.length;
    if (n == 0) return;

    final totalCols =
        chars.fold(0, (s, c) => s + _dialCharCols(c)) + (n - 1);
    const gap = 2.0;
    final stepW = (maxW + gap) / totalCols;
    final stepH = (maxH + gap) / 7;
    final step  = math.min(stepW, stepH);
    final r     = (step - gap) / 2;

    final matW = step * totalCols - gap;
    final matH = step * 7 - gap;
    final ox   = centre.dx - matW / 2;
    final oy   = centre.dy - matH / 2;

    final paint = Paint()..color = color..style = PaintingStyle.fill;
    double cx = ox;
    for (final ch in chars) {
      final glyph = _dialGlyphs[ch] ?? _dialGlyphs['-']!;
      final cols  = _dialCharCols(ch);
      for (int row = 0; row < 7; row++) {
        final bits = glyph[row];
        for (int col = 0; col < cols; col++) {
          if (((bits >> ((cols - 1) - col)) & 1) == 1) {
            canvas.drawCircle(
              Offset(cx + col * step + step / 2,
                     oy + row * step + step / 2),
              r, paint,
            );
          }
        }
      }
      cx += cols * step + step;
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.measuredTempC != measuredTempC ||
      old.setpointC     != setpointC     ||
      old.coolingSetptC != coolingSetptC;
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode selector
// ---------------------------------------------------------------------------

class _ModeSelector extends StatelessWidget {
  final List<({int mode, String label})> modes;
  final int? current;
  final ValueChanged<int> onSelect;
  const _ModeSelector(
      {required this.modes, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: modes.map((m) {
        final selected = current == m.mode;
        return ChoiceChip(
          label: Text(m.label),
          selected: selected,
          onSelected: (_) => onSelect(m.mode),
          selectedColor: Colors.black87,
          backgroundColor: Colors.transparent,
          labelStyle: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.black87,
          ),
          side: BorderSide(
            color: selected ? Colors.black87 : Colors.black26,
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}

// (temperature row, setpoint button and _Let extension removed — replaced by dial)
