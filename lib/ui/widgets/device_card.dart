import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_type.dart';
import '../../models/matter_device.dart';
import '../../providers/device_provider.dart';
import 'online_badge.dart';

// Shared tile style constants
const _kRadius    = 22.0;
const _kBorder    = BorderSide(color: Colors.white, width: 1.5);
const _kCardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(_kRadius)),
  side: _kBorder,
);

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

class DeviceCard extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onTap;

  const DeviceCard({super.key, required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (device.deviceType == DeviceType.thermostat) {
      return _ThermostatTile(device: device, onTap: onTap);
    }
    return _StandardTile(device: device, onTap: onTap);
  }
}

// ---------------------------------------------------------------------------
// Standard tile (lights, plugs, etc.)
// ---------------------------------------------------------------------------

class _StandardTile extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onTap;
  const _StandardTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isActive = device.isOnline && device.isOn;

    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: _kCardShape,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(device.deviceType.icon,
                        color: isActive ? cs.primary : Colors.white70,
                        size: 22),
                  ),
                  const Spacer(),
                  if (device.deviceType.hasOnOff)
                    _ToggleSwitch(device: device),
                ],
              ),
              const Spacer(),
              Text(
                device.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              OnlineBadge(isOnline: device.isOnline),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thermostat tile
// ---------------------------------------------------------------------------

class _ThermostatTile extends StatelessWidget {
  final MatterDevice device;
  final VoidCallback onTap;

  static const _litColor = Color(0xFFFFFFFF);

  const _ThermostatTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOffline = !device.isOnline;
    final temp      = device.localTempCenti;
    final tempStr   = isOffline
        ? 'offline'
        : (temp != null ? (temp / 100.0).toStringAsFixed(1) : '--.-');

    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: _kCardShape,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            children: [
              // Dot matrix — full canvas when offline, smaller when showing temp
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final w = isOffline
                          ? constraints.maxWidth  - 8
                          : constraints.maxWidth  * 0.80;
                      final h = isOffline
                          ? constraints.maxHeight - 8
                          : constraints.maxHeight * 0.72;
                      return CustomPaint(
                        size: Size(w, h),
                        painter: _DotMatrixPainter(
                          text: tempStr,
                          litColor: _litColor,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Name only shown when online
              if (!isOffline) ...[
                const SizedBox(height: 10),
                Text(
                  device.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5×7 dot matrix painter
// ---------------------------------------------------------------------------

/// Standard chars: 5 cols (bit 4 = leftmost).
/// Period: 3 cols (bit 2 = leftmost) — half the width of a digit.
const _glyphs = <String, List<int>>{
  // Digits
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
  // Punctuation
  '.': [0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x02],
  '-': [0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00],
  // Lowercase letters for "offline"
  'o': [0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x0E],
  'f': [0x06, 0x04, 0x0E, 0x04, 0x04, 0x04, 0x04],
  'l': [0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x06],
  'i': [0x04, 0x00, 0x04, 0x04, 0x04, 0x04, 0x04],
  'n': [0x00, 0x00, 0x0E, 0x11, 0x11, 0x11, 0x11],
  'e': [0x00, 0x00, 0x0E, 0x11, 0x1F, 0x10, 0x0E],
};

int _charCols(String ch) => ch == '.' ? 3 : 5;

class _DotMatrixPainter extends CustomPainter {
  final String text;
  final Color  litColor;

  const _DotMatrixPainter({required this.text, required this.litColor});

  @override
  void paint(Canvas canvas, Size size) {
    final chars = text.characters.toList();
    final n     = chars.length;
    if (n == 0) return;

    final totalCols =
        chars.fold(0, (s, c) => s + _charCols(c)) + (n - 1);

    const gap = 2.0;
    final stepW = (size.width  + gap) / totalCols;
    final stepH = (size.height + gap) / 7;
    final step  = math.min(stepW, stepH);
    final r     = (step - gap) / 2;

    final matW = step * totalCols - gap;
    final matH = step * 7 - gap;
    final ox   = (size.width  - matW) / 2;
    final oy   = (size.height - matH) / 2;

    final paint = Paint()..color = litColor..style = PaintingStyle.fill;

    double cx = ox;
    for (final ch in chars) {
      final glyph = _glyphs[ch] ?? _glyphs['-']!;
      final cols  = _charCols(ch);
      for (int row = 0; row < 7; row++) {
        final bits = glyph[row];
        for (int col = 0; col < cols; col++) {
          if (((bits >> ((cols - 1) - col)) & 1) == 1) {
            canvas.drawCircle(
              Offset(cx + col * step + step / 2, oy + row * step + step / 2),
              r,
              paint,
            );
          }
        }
      }
      cx += cols * step + step;
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter old) =>
      old.text != text || old.litColor != litColor;
}

// ---------------------------------------------------------------------------
// Toggle switch (standard tile)
// ---------------------------------------------------------------------------

class _ToggleSwitch extends StatelessWidget {
  final MatterDevice device;
  const _ToggleSwitch({required this.device});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (device.isOnline) context.read<DeviceProvider>().toggle(device.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: device.isOn && device.isOnline
              ? Theme.of(context).colorScheme.primary
              : Colors.white38,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              device.isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
