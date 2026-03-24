import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/matter_device.dart';
import '../../providers/device_provider.dart';
import '../../services/matter_channel.dart';
import '../../services/thread_settings_service.dart';
import 'qr_scanner_screen.dart';

// ── Commissioning method ──────────────────────────────────────────────────
enum _CommissionMethod { ble, ip }

class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  // ── Form state ────────────────────────────────────────────────────────────
  final _nameCtrl    = TextEditingController();
  final _threadCtrl  = TextEditingController();
  final _ssidCtrl    = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _ipCtrl      = TextEditingController();
  final _discCtrl    = TextEditingController();
  final _pinCtrl     = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  String? _rawPayload;           // QR or manual code string
  ParsedPayload? _parsed;        // info extracted from the code
  bool _parsing = false;         // waiting for parsePayload call
  String? _parseError;           // last parse error

  _CommissionMethod _method = _CommissionMethod.ble;

  // Network: 0 = Thread, 1 = Wi-Fi, 2 = None
  int _netType = 0;
  bool _showThreadDataset = false;
  bool _showPassword      = false;

  // ── Live log state ────────────────────────────────────────────────────────
  bool _commissioning  = false;
  final List<_LogEntry> _log = [];
  final _logScrollCtrl = ScrollController();
  StreamSubscription<String>? _eventSub;
  bool _commissionDone   = false;
  bool _commissionFailed = false;

  @override
  void initState() {
    super.initState();
    ThreadSettingsService.load().then((ds) {
      if (mounted) _threadCtrl.text = ds;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _threadCtrl.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _ipCtrl.dispose();
    _discCtrl.dispose();
    _pinCtrl.dispose();
    _logScrollCtrl.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  // ── Payload handling ──────────────────────────────────────────────────────

  Future<void> _setPayload(String raw) async {
    setState(() {
      _rawPayload  = raw;
      _parsed      = null;
      _parseError  = null;
      _parsing     = true;
    });

    final result = await MatterChannel().parsePayload(raw);

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _parsing    = false;
        _parseError = 'Could not parse payload';
      });
      return;
    }

    // Auto-fill name if still empty / default.
    if (_nameCtrl.text.isEmpty) {
      _nameCtrl.text = result.suggestedName;
    }

    // Auto-select commissioning method from discoveryCapabilities.
    final method = result.prefersBle
        ? _CommissionMethod.ble
        : _CommissionMethod.ip;

    setState(() {
      _parsed  = result;
      _parsing = false;
      _method  = method;
    });
  }

  // ── QR scan ───────────────────────────────────────────────────────────────

  Future<void> _scanQr() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Camera permission required to scan QR codes'),
      ));
      return;
    }
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (raw != null && mounted) await _setPayload(raw);
  }

  // ── BLE permission ────────────────────────────────────────────────────────

  Future<bool> _requestBlePermissions() async {
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied    = results.values.any((s) => s.isDenied || s.isPermanentlyDenied);
    final permanent = results.values.any((s) => s.isPermanentlyDenied);

    if (denied && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text(permanent
            ? 'Bluetooth permissions permanently denied — open Settings.'
            : 'Bluetooth permissions are required for BLE commissioning.'),
        action: permanent
            ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
            : null,
      ));
      return false;
    }
    return true;
  }

  // ── Commission ────────────────────────────────────────────────────────────

  Future<void> _commission() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rawPayload == null) return;

    if (_method == _CommissionMethod.ble) {
      if (!await _requestBlePermissions()) return;
    }
    if (!mounted) return;

    final provider = context.read<DeviceProvider>();
    final name     = _nameCtrl.text.trim().isEmpty
        ? (_parsed?.suggestedName ?? 'Matter Device')
        : _nameCtrl.text.trim();

    _log.clear();
    setState(() {
      _commissioning    = true;
      _commissionDone   = false;
      _commissionFailed = false;
    });
    _eventSub = MatterChannel().commissionEvents.listen(
      (event) {
        _LogLevel lvl = _LogLevel.info;
        if (event.startsWith('✓') || event.startsWith('🎉')) lvl = _LogLevel.success;
        if (event.startsWith('✗')) lvl = _LogLevel.error;
        if (event.startsWith('🔍') || event.startsWith('▶'))  lvl = _LogLevel.step;
        _appendLog(event, level: lvl);
      },
    );
    _appendLog('Commissioning "$name"…', level: _LogLevel.step);

    MatterDevice? device;

    if (_method == _CommissionMethod.ip) {
      device = await provider.commissionViaIp(
        ipAddress:    _ipCtrl.text.trim(),
        discriminator: int.tryParse(_discCtrl.text) ?? (_parsed?.discriminator ?? 3840),
        setupPinCode: int.tryParse(_pinCtrl.text) ?? 20202021,
        deviceName:   name,
        room:         'Unassigned',
      );
    } else {
      switch (_netType) {
        case 0: // Thread
          device = await provider.commissionDevice(
            _rawPayload!, name, 'Unassigned',
            threadDatasetHex: _threadCtrl.text.replaceAll(RegExp(r'\s'), ''),
          );
        case 1: // Wi-Fi
          device = await provider.commissionDevice(
            _rawPayload!, name, 'Unassigned',
            wifiSsid:     _ssidCtrl.text.trim(),
            wifiPassword: _passCtrl.text,
          );
        default: // None
          device = await provider.commissionDevice(_rawPayload!, name, 'Unassigned');
      }
    }

    await _eventSub?.cancel();
    _eventSub = null;
    if (!mounted) return;

    if (device != null) {
      setState(() => _commissionDone = true);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) context.go('/device/${device.id}');
    } else {
      setState(() => _commissionFailed = true);
      _appendLog(provider.errorMessage ?? 'Commissioning failed',
          level: _LogLevel.error);
    }
  }

  // ── Log helpers ───────────────────────────────────────────────────────────

  void _appendLog(String msg, {_LogLevel level = _LogLevel.info}) {
    if (!mounted) return;
    setState(() => _log.add(_LogEntry(message: msg, level: level,
        time: TimeOfDay.now())));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollCtrl.hasClients) {
        _logScrollCtrl.animateTo(
          _logScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) =>
      _commissioning ? _buildLogScreen(context) : _buildFormScreen(context);

  // ── Log screen ────────────────────────────────────────────────────────────

  Widget _buildLogScreen(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String title) = _commissionDone
        ? (Icons.check_circle_outline, const Color(0xFF34A853), 'Complete')
        : _commissionFailed
            ? (Icons.error_outline, cs.error, 'Failed')
            : (Icons.settings_outlined, cs.primary, 'Commissioning…');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Matter Device'),
        automaticallyImplyLeading: false,
        leading: _commissionFailed
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _commissioning    = false;
                  _commissionFailed = false;
                }),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(children: [
              _commissionDone || _commissionFailed
                  ? Icon(icon, color: color, size: 32)
                  : SizedBox(
                      width: 32, height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3, color: color)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                  if (_log.isNotEmpty)
                    Text(_log.last.message,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              )),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _logScrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _log.length,
              itemBuilder: (_, i) => _LogRow(
                entry: _log[i],
                isActive: i == _log.length - 1 && !_commissionDone && !_commissionFailed,
              ),
            ),
          ),
          if (_commissionFailed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _commissioning = false; _commissionFailed = false;
                    }),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _commission,
                    child: const Text('Retry'),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  // ── Form screen ───────────────────────────────────────────────────────────

  Widget _buildFormScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Matter Device')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Step 1: Scan / Enter code ─────────────────────────────
              _SectionLabel('Pairing code'),
              const SizedBox(height: 10),
              _PayloadEntry(
                onScan:         _scanQr,
                onCodeEntered:  _setPayload,
                parsed:         _parsed,
                parsing:        _parsing,
                parseError:     _parseError,
              ),

              // ── Step 2: Parsed device info + editable name ────────────
              if (_parsed != null) ...[
                const SizedBox(height: 20),
                _SectionLabel('Device'),
                const SizedBox(height: 10),
                _DeviceInfoTile(
                  parsed:    _parsed!,
                  nameCtrl:  _nameCtrl,
                  method:    _method,
                  onMethodChanged: (m) => setState(() => _method = m),
                ),
              ],

              // ── Step 3: Network credentials (BLE only) ────────────────
              if (_parsed != null && _method == _CommissionMethod.ble) ...[
                const SizedBox(height: 20),
                _SectionLabel('Network'),
                const SizedBox(height: 10),
                _NetworkSection(
                  netType:              _netType,
                  threadCtrl:           _threadCtrl,
                  ssidCtrl:             _ssidCtrl,
                  passCtrl:             _passCtrl,
                  showThreadDataset:    _showThreadDataset,
                  showPassword:         _showPassword,
                  onNetTypeChanged:     (v) => setState(() => _netType = v),
                  onShowDatasetChanged: (v) => setState(() => _showThreadDataset = v),
                  onShowPasswordChanged:(v) => setState(() => _showPassword = v),
                ),
              ],

              // ── IP fields (IP method) ─────────────────────────────────
              if (_parsed != null && _method == _CommissionMethod.ip) ...[
                const SizedBox(height: 20),
                _SectionLabel('IP commissioning'),
                const SizedBox(height: 10),
                TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP address',
                    prefixIcon: Icon(Icons.lan_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _discCtrl,
                    decoration: InputDecoration(
                      labelText: 'Discriminator',
                      hintText: '${_parsed?.discriminator ?? 3840}',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    controller: _pinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Setup PIN',
                      hintText: '20202021',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  )),
                ]),
              ],

              // ── Commission button ─────────────────────────────────────
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _rawPayload != null && _parsed != null && !_parsing
                    ? _commission
                    : null,
                icon: const Icon(Icons.add_link),
                label: Text(_method == _CommissionMethod.ble
                    ? 'Commission via BLE'
                    : 'Commission via IP'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payload entry widget  (scan button + manual field + parsed summary)
// ─────────────────────────────────────────────────────────────────────────────

class _PayloadEntry extends StatefulWidget {
  final VoidCallback          onScan;
  final ValueChanged<String>  onCodeEntered;
  final ParsedPayload?        parsed;
  final bool                  parsing;
  final String?               parseError;

  const _PayloadEntry({
    required this.onScan,
    required this.onCodeEntered,
    required this.parsed,
    required this.parsing,
    required this.parseError,
  });

  @override
  State<_PayloadEntry> createState() => _PayloadEntryState();
}

class _PayloadEntryState extends State<_PayloadEntry> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scanned = widget.parsed != null;
    final scanColor = scanned ? const Color(0xFF34A853) : cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scan button
        OutlinedButton.icon(
          onPressed: widget.onScan,
          icon: widget.parsing
              ? SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(scanned ? Icons.check_circle_outline : Icons.qr_code_scanner,
                  color: scanColor),
          label: Text(scanned ? 'QR scanned ✓' : 'Scan QR code',
              style: TextStyle(color: scanColor)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: scanned ? const Color(0xFF34A853) : cs.outline),
          ),
        ),

        // Divider
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('or enter manually', style: TextStyle(fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ]),
        ),

        // Manual code field
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: 'Setup payload / pairing code',
            hintText:  'MT:Y.K9042C00KA0648G00',
            prefixIcon: const Icon(Icons.pin_outlined),
            border: const OutlineInputBorder(),
            errorText: widget.parseError,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () { _ctrl.clear(); setState(() {}); })
                : null,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          onSubmitted: (v) { if (v.trim().isNotEmpty) widget.onCodeEntered(v.trim()); },
          onChanged: (v) => setState(() {}),
        ),
        if (_ctrl.text.trim().isNotEmpty && widget.parsed == null && !widget.parsing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonal(
              onPressed: () => widget.onCodeEntered(_ctrl.text.trim()),
              child: const Text('Parse code'),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device info tile  (shows VID/PID, suggests name, shows method badge)
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceInfoTile extends StatelessWidget {
  final ParsedPayload              parsed;
  final TextEditingController      nameCtrl;
  final _CommissionMethod          method;
  final ValueChanged<_CommissionMethod> onMethodChanged;

  const _DeviceInfoTile({
    required this.parsed,
    required this.nameCtrl,
    required this.method,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canBle      = parsed.hasBle;
    final canOnNetwork = parsed.hasOnNetwork;

    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // VID / PID chips
            Row(children: [
              _Chip('VID 0x${parsed.vendorId.toRadixString(16).padLeft(4,'0').toUpperCase()}'),
              const SizedBox(width: 6),
              _Chip('PID 0x${parsed.productId.toRadixString(16).padLeft(4,'0').toUpperCase()}'),
              const SizedBox(width: 6),
              _Chip('disc ${parsed.discriminator}'),
              const Spacer(),
              // Method badge
              if (canBle && canOnNetwork)
                SegmentedButton<_CommissionMethod>(
                  segments: const [
                    ButtonSegment(value: _CommissionMethod.ble,  label: Text('BLE')),
                    ButtonSegment(value: _CommissionMethod.ip,   label: Text('IP')),
                  ],
                  selected: {method},
                  onSelectionChanged: (s) => onMethodChanged(s.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                _MethodBadge(canBle ? 'BLE' : 'IP'),
            ]),

            const SizedBox(height: 14),

            // Editable device name
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Device name',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(
          fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        )),
  );
}

class _MethodBadge extends StatelessWidget {
  final String label;
  const _MethodBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Network credentials section
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkSection extends StatelessWidget {
  final int netType;
  final TextEditingController threadCtrl;
  final TextEditingController ssidCtrl;
  final TextEditingController passCtrl;
  final bool showThreadDataset;
  final bool showPassword;
  final ValueChanged<int>  onNetTypeChanged;
  final ValueChanged<bool> onShowDatasetChanged;
  final ValueChanged<bool> onShowPasswordChanged;

  const _NetworkSection({
    required this.netType,
    required this.threadCtrl,
    required this.ssidCtrl,
    required this.passCtrl,
    required this.showThreadDataset,
    required this.showPassword,
    required this.onNetTypeChanged,
    required this.onShowDatasetChanged,
    required this.onShowPasswordChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Type selector ──────────────────────────────────────────
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.memory_outlined, size: 16), label: Text('Thread')),
                ButtonSegment(value: 1, icon: Icon(Icons.wifi_outlined, size: 16),   label: Text('Wi-Fi')),
                ButtonSegment(value: 2, icon: Icon(Icons.lan_outlined, size: 16),    label: Text('None')),
              ],
              selected: {netType},
              onSelectionChanged: (s) => onNetTypeChanged(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 14),

            // ── Thread ─────────────────────────────────────────────────
            if (netType == 0) ...[
              // Summary row
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onShowDatasetChanged(!showThreadDataset),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.memory_outlined, size: 16, color: cs.secondary),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NEST-PAN-26BA  •  Ch 15  •  PAN 0x26BA',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600,
                                           color: cs.secondary)),
                        Text('Ext PAN: 12f209ab410ad778',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontFamily: 'monospace',
                                           color: cs.onSurfaceVariant)),
                      ],
                    )),
                    Icon(showThreadDataset
                        ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: cs.onSurfaceVariant),
                  ]),
                ),
              ),
              // Expandable raw dataset
              if (showThreadDataset) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: threadCtrl,
                  decoration: InputDecoration(
                    labelText: 'Active Operational Dataset (hex TLV)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.restart_alt_outlined),
                      tooltip: 'Restore default',
                      onPressed: () async =>
                          threadCtrl.text = await ThreadSettingsService.load(),
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  maxLines: 3, minLines: 2,
                ),
              ],
            ],

            // ── Wi-Fi ──────────────────────────────────────────────────
            if (netType == 1) ...[
              TextField(
                controller: ssidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Wi-Fi SSID',
                  prefixIcon: Icon(Icons.wifi_outlined),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => onShowPasswordChanged(!showPassword),
                  ),
                ),
                obscureText: !showPassword,
                textInputAction: TextInputAction.done,
              ),
            ],

            // ── None ───────────────────────────────────────────────────
            if (netType == 2)
              Text('No network credentials — for Ethernet-only devices.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Log row (reused from previous version)
// ─────────────────────────────────────────────────────────────────────────────

enum _LogLevel { step, info, success, error }

class _LogEntry {
  final String _message;
  final _LogLevel _level;
  final TimeOfDay _time;
  String get message => _message;
  _LogLevel get level => _level;
  TimeOfDay get time => _time;
  _LogEntry({required String message, required _LogLevel level, required TimeOfDay time})
      : _message = message, _level = level, _time = time;
}

class _LogRow extends StatelessWidget {
  final _LogEntry entry;
  final bool      isActive;
  const _LogRow({required this.entry, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color color = switch (entry.level) {
      _LogLevel.success => const Color(0xFF34A853),
      _LogLevel.error   => cs.error,
      _LogLevel.step    => cs.primary,
      _LogLevel.info    => cs.onSurfaceVariant,
    };
    final Widget leadingIcon = isActive
        ? SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
        : Icon(
            switch (entry.level) {
              _LogLevel.success => Icons.check_circle,
              _LogLevel.error   => Icons.cancel,
              _LogLevel.step    => Icons.play_circle_outline,
              _LogLevel.info    => Icons.info_outline,
            },
            size: 14, color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2, right: 8), child: leadingIcon),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace', height: 1.5),
                children: [
                  TextSpan(
                    text: '${entry.time.format(context)}  ',
                    style: TextStyle(color: cs.onSurfaceVariant.withAlpha(120), fontSize: 10)),
                  TextSpan(text: entry.message,
                      style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
