import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/device_provider.dart';
import '../../services/matter_channel.dart';
import '../../services/thread_settings_service.dart';
// ---------------------------------------------------------------------------
// Main settings screen
// ---------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Submenus ───────────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.hub_outlined, color: cs.primary),
                  title: const Text('Matter'),
                  subtitle: const Text('Fabric & device management'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MatterSettingsScreen()),
                  ),
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outlineVariant),
                ListTile(
                  leading: Icon(Icons.router_outlined, color: cs.primary),
                  title: const Text('Thread'),
                  subtitle: const Text('Operational dataset'),
                  trailing: const Icon(Icons.chevron_right),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ThreadSettingsScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────────────────────
          _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Flux'),
            subtitle: Text('Flutter + CHIP SDK (connectedhomeip)'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Matter sub-screen
// ---------------------------------------------------------------------------

class MatterSettingsScreen extends StatefulWidget {
  const MatterSettingsScreen({super.key});

  @override
  State<MatterSettingsScreen> createState() => _MatterSettingsScreenState();
}

class _MatterSettingsScreenState extends State<MatterSettingsScreen> {
  String? _fabricId;

  @override
  void initState() {
    super.initState();
    MatterChannel().getFabricId().then((id) {
      if (mounted) setState(() => _fabricId = id ?? 'N/A');
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all devices?'),
        content: const Text(
          'All devices will be removed from local storage. '
          'The physical devices are NOT factory-reset and must be '
          'unpaired manually before they can be re-commissioned.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<DeviceProvider>().clearAllDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All devices cleared')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Matter')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionHeader(title: 'Fabric'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: Icon(Icons.vpn_key_outlined, color: cs.primary),
              title: const Text('Fabric ID'),
              subtitle: Text(
                _fabricId ?? '…',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
              trailing: _fabricId != null && _fabricId != 'N/A'
                  ? IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _fabricId!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fabric ID copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 24),
          _SectionHeader(title: 'Device management'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: Icon(Icons.delete_sweep_outlined, color: cs.error),
              title: Text('Clear all devices',
                  style: TextStyle(color: cs.error)),
              subtitle: const Text('Remove from local storage only'),
              onTap: _clearAll,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread sub-screen — auto-scans, shows PAN names only
// ---------------------------------------------------------------------------

/// Merged view of a Thread network: mDNS-discovered border routers + optional
/// locally-configured dataset that matches this PAN.
class _ThreadNetwork {
  final String networkName;
  final String extPanId;         // from mDNS or decoded from dataset
  final List<ThreadBorderRouter> borderRouters;
  final bool   isConfigured;     // true if this matches the saved hex dataset
  final String? configuredHex;   // raw hex if isConfigured

  const _ThreadNetwork({
    required this.networkName,
    required this.extPanId,
    required this.borderRouters,
    required this.isConfigured,
    this.configuredHex,
  });
}

class ThreadSettingsScreen extends StatefulWidget {
  const ThreadSettingsScreen({super.key});

  @override
  State<ThreadSettingsScreen> createState() => _ThreadSettingsScreenState();
}

class _ThreadSettingsScreenState extends State<ThreadSettingsScreen> {
  bool _scanning = false;
  List<_ThreadNetwork> _networks = [];
  bool _hasCachedData = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  /// On open: restore cached routers immediately, then let the user rescan.
  Future<void> _loadCached() async {
    final results = await Future.wait([
      ThreadSettingsService.load(),
      ThreadSettingsService.loadRouters(),
    ]);
    final savedHex = results[0] as String;
    final cached   = results[1] as List<ThreadBorderRouter>;
    final networks = _buildNetworks(savedHex, cached);
    if (mounted) {
      setState(() {
        _networks     = networks;
        _hasCachedData = cached.isNotEmpty;
      });
    }
  }

  /// Scan the network, persist results, refresh UI.
  Future<void> _scan() async {
    setState(() { _scanning = true; _error = null; });
    try {
      final results = await Future.wait([
        ThreadSettingsService.load(),
        context.read<MatterChannel>().discoverThreadNetworks(),
      ]);
      final savedHex = results[0] as String;
      final routers  = results[1] as List<ThreadBorderRouter>;

      await ThreadSettingsService.saveRouters(routers);

      final networks = _buildNetworks(savedHex, routers);
      if (mounted) {
        setState(() {
          _networks      = networks;
          _hasCachedData = true;
          _scanning      = false;
        });
      }
    } catch (e) {
      if (mounted) { setState(() { _error = e.toString(); _scanning = false; }); }
    }
  }

  List<_ThreadNetwork> _buildNetworks(
      String savedHex, List<ThreadBorderRouter> routers) {
    final savedClean  = savedHex.replaceAll(RegExp(r'\s'), '');
    final savedFields = _ThreadDecoder.decode(savedClean);
    String? savedName, savedXp;
    for (final f in savedFields) {
      if (f.label == 'Network Name') savedName = f.value;
      if (f.label == 'Ext PAN ID')   savedXp   = f.value;
    }

    final Map<String, List<ThreadBorderRouter>> byName = {};
    for (final r in routers) {
      byName.putIfAbsent(r.networkName, () => []).add(r);
    }

    final networks = <_ThreadNetwork>[];

    if (savedName != null) {
      final matchingRouters = byName.remove(savedName) ?? [];
      networks.add(_ThreadNetwork(
        networkName:   savedName,
        extPanId:      savedXp ?? '',
        borderRouters: matchingRouters,
        isConfigured:  true,
        configuredHex: savedHex,
      ));
    }

    for (final entry in byName.entries) {
      networks.add(_ThreadNetwork(
        networkName:   entry.key,
        extPanId:      entry.value.first.extPanId,
        borderRouters: entry.value,
        isConfigured:  false,
      ));
    }

    return networks;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: Column(
        children: [
          // ── Thread credentials button ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.key_outlined),
                label: const Text('Thread credentials'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _ThreadCredentialsScreen(),
                  ),
                ).then((_) => _loadCached()),
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 13)),
            ),

          // ── Network list ────────────────────────────────────────────
          Expanded(
            child: _networks.isEmpty && !_scanning
                ? Center(
                    child: Text(
                      _hasCachedData
                          ? 'No Thread networks found'
                          : 'Tap "Scan for networks" to discover Thread networks',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _networks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final net = _networks[i];
                      final cs2 = Theme.of(ctx).colorScheme;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.router_outlined,
                            color: net.isConfigured
                                ? cs2.primary
                                : cs2.onSurfaceVariant,
                          ),
                          title: Text(net.networkName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                      subtitle: net.borderRouters.isNotEmpty
                              ? Text(
                                  '${net.borderRouters.length} border router'
                                  '${net.borderRouters.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs2.onSurfaceVariant),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (net.isConfigured)
                                Chip(
                                  label: const Text('Configured',
                                      style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: cs2.primaryContainer,
                                  labelStyle: TextStyle(
                                      color: cs2.onPrimaryContainer),
                                  side: BorderSide.none,
                                  padding: EdgeInsets.zero,
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _ThreadNetworkScreen(network: net),
                            ),
                          ).then((_) => _loadCached()),
                        ),
                      );
                    },
                  ),
          ),

          // ── Scan button (bottom) ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _scanning ? null : _scan,
                child: _scanning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Scanning…'),
                        ],
                      )
                    : const Text('Scan for networks'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread credentials screen — configured dataset + Android credential store
// ---------------------------------------------------------------------------

class _ThreadCredentialsScreen extends StatefulWidget {
  const _ThreadCredentialsScreen();

  @override
  State<_ThreadCredentialsScreen> createState() =>
      _ThreadCredentialsScreenState();
}

class _ThreadCredentialsScreenState extends State<_ThreadCredentialsScreen> {
  String? _savedHex;
  String? _savedNetworkName;

  bool  _reading  = false;
  bool  _hasRead  = false;
  List<({String networkName, String hex})> _androidCreds = [];
  String? _readError;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final hex    = await ThreadSettingsService.load();
    final clean  = hex.replaceAll(RegExp(r'\s'), '');
    final fields = _ThreadDecoder.decode(clean);
    final name   = fields
        .where((f) => f.label == 'Network Name')
        .map((f) => f.value)
        .firstOrNull;
    if (mounted) setState(() { _savedHex = hex; _savedNetworkName = name; });
  }

  Future<void> _readFromAndroid() async {
    setState(() { _reading = true; _readError = null; _androidCreds = []; _hasRead = false; });
    try {
      final hex = await context
          .read<MatterChannel>()
          .readAndroidThreadCredentials();

      if (hex == null) {
        if (mounted) { setState(() { _readError = 'Failed to contact credential store'; _reading = false; _hasRead = true; }); }
        return;
      }
      if (hex.isEmpty) {
        // user cancelled the picker
        if (mounted) { setState(() { _reading = false; _hasRead = true; }); }
        return;
      }

      final fields = _ThreadDecoder.decode(hex);
      final name = fields
          .where((f) => f.label == 'Network Name')
          .map((f) => f.value)
          .firstOrNull ?? hex.substring(0, 8.clamp(0, hex.length));

      if (mounted) setState(() {
        _androidCreds = [(networkName: name, hex: hex)];
        _reading = false;
        _hasRead = true;
      });
    } catch (e) {
      if (mounted) setState(() { _readError = e.toString(); _reading = false; _hasRead = true; });
    }
  }

  Future<void> _apply(String hex) async {
    await ThreadSettingsService.save(hex);
    await _loadSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dataset updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Thread credentials')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Configured dataset ───────────────────────────────────────
          _SectionHeader(title: 'Configured dataset'),
          Card(
            child: ListTile(
              leading: Icon(Icons.router_outlined, color: cs.primary),
              title: Text(
                _savedNetworkName ?? '…',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Tap to view or edit'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _savedHex == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ThreadDatasetDetailScreen(
                              initialHex: _savedHex!),
                        ),
                      ).then((_) => _loadSaved()),
            ),
          ),

          const SizedBox(height: 24),

          // ── Android credential store ─────────────────────────────────
          _SectionHeader(title: 'Android credential store'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.android, color: cs.primary),
                  title: const Text('Read from Android'),
                  subtitle: const Text(
                      'Load Thread credentials stored by other apps'),
                  trailing: _reading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined),
                  onTap: _reading ? null : _readFromAndroid,
                ),

                if (_readError != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(_readError!,
                        style: TextStyle(color: cs.error, fontSize: 12)),
                  ),
                ],

                if (_androidCreds.isNotEmpty) ...[
                  Divider(height: 1, color: cs.outlineVariant),
                  ..._androidCreds.map((c) {
                    final isActive = c.hex.replaceAll(RegExp(r'\s'), '') ==
                        (_savedHex ?? '').replaceAll(RegExp(r'\s'), '');
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isActive
                            ? Icons.check_circle_outline
                            : Icons.circle_outlined,
                        color: isActive ? cs.primary : cs.onSurfaceVariant,
                        size: 20,
                      ),
                      title: Text(c.networkName,
                          style: const TextStyle(fontSize: 13)),
                      trailing: isActive
                          ? Chip(
                              label: const Text('Active',
                                  style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: cs.primaryContainer,
                              labelStyle:
                                  TextStyle(color: cs.onPrimaryContainer),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                            )
                          : TextButton(
                              onPressed: () => _apply(c.hex),
                              child: const Text('Apply'),
                            ),
                    );
                  }),
                ],

                if (!_reading && _androidCreds.isEmpty && _readError == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      _hasRead
                          ? 'Picker was cancelled or no credential was selected.'
                          : 'Tap "Read from Android" — a system picker will let you choose which Thread network to share.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread network detail — border routers + dataset
// ---------------------------------------------------------------------------

class _ThreadNetworkScreen extends StatelessWidget {
  final _ThreadNetwork network;
  const _ThreadNetworkScreen({required this.network});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final fields = network.isConfigured && network.configuredHex != null
        ? _ThreadDecoder.decode(
            network.configuredHex!.replaceAll(RegExp(r'\s'), ''))
        : <({String label, String value})>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(network.networkName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Border routers ─────────────────────────────────────────────
          _SectionHeader(title: 'Border routers'),
          if (network.borderRouters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('No border routers discovered on this network',
                  style: TextStyle(fontSize: 13)),
            )
          else
            Card(
              child: Column(
                children: network.borderRouters
                    .asMap()
                    .entries
                    .map((e) {
                  final r     = e.value;
                  final last  = e.key == network.borderRouters.length - 1;
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.device_hub,
                            color: cs.primary),
                        title: Text(
                          r.vendorName.isNotEmpty && r.modelName.isNotEmpty
                              ? '${r.vendorName} ${r.modelName}'
                              : r.serviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500),
                        ),
                        subtitle: r.host.isNotEmpty || r.txt['tv'] != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (r.host.isNotEmpty)
                                    Text('${r.host}:${r.port}',
                                        style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12)),
                                  if (r.txt['tv'] != null)
                                    Text('Thread ${r.txt['tv']}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                                ],
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                _BorderRouterDetailScreen(router: r),
                          ),
                        ),
                      ),
                      if (!last)
                        Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: cs.outlineVariant),
                    ],
                  );
                }).toList(),
              ),
            ),

          // ── Dataset details (configured network only) ─────────────────
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader(title: 'Dataset'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Column(
                  children: fields
                      .map((f) =>
                          _FieldRow(label: f.label, value: f.value))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _ThreadDatasetDetailScreen(
                      initialHex: network.configuredHex!),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit dataset hex'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Border router detail — all TXT record fields with descriptions
// ---------------------------------------------------------------------------

const _kTxtFieldInfo = <String, ({String name, String description})>{
  'rv': (name: 'Revision',          description: 'The Thread version. Usually 1 or higher.'),
  'nn': (name: 'Network Name',      description: 'Human-readable name of the Thread mesh.'),
  'xp': (name: 'Extended PAN ID',   description: '64-bit hex ID that uniquely identifies this mesh.'),
  'tv': (name: 'Thread Version',    description: 'Specific stack version (e.g. 1.3.0).'),
  'vn': (name: 'Vendor Name',       description: 'Manufacturer of the border router device.'),
  'mn': (name: 'Model Name',        description: 'Model of the border router device.'),
  'at': (name: 'Active Timestamp',  description: '64-bit value ensuring all devices have the latest settings.'),
  'sq': (name: 'Sequence Number',   description: 'Increments every time the network configuration changes.'),
  'sb': (name: 'State Bitmap',      description: 'Connectivity and service flags for this border router.'),
  'bb': (name: 'BBR Sequence',      description: 'Backbone Border Router sequence number.'),
  'dn': (name: 'Domain Name',       description: 'Thread domain name (Thread 1.2+).'),
  'id': (name: 'Border Agent ID',   description: '128-bit unique identifier for this border agent.'),
};

class _BorderRouterDetailScreen extends StatelessWidget {
  final ThreadBorderRouter router;
  const _BorderRouterDetailScreen({required this.router});

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final title = router.vendorName.isNotEmpty && router.modelName.isNotEmpty
        ? '${router.vendorName} ${router.modelName}'
        : router.serviceName;

    // Build ordered field list: known fields first (in _kTxtFieldInfo order),
    // then any unknown keys alphabetically.
    final knownKeys   = _kTxtFieldInfo.keys.toList();
    final unknownKeys = router.txt.keys
        .where((k) => !knownKeys.contains(k))
        .toList()
      ..sort();
    final orderedKeys = [
      ...knownKeys.where(router.txt.containsKey),
      ...unknownKeys,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                router.host.isNotEmpty
                    ? '${router.host}:${router.port}'
                    : router.serviceName,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
      body: orderedKeys.isEmpty
          ? const Center(child: Text('No TXT record data available'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orderedKeys.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final key  = orderedKeys[i];
                final val  = router.txt[key] ?? '';
                final info = _kTxtFieldInfo[key];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Key badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            key,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (info != null) ...[
                                Text(info.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(info.description,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                                const SizedBox(height: 6),
                              ],
                              SelectableText(
                                val.isNotEmpty ? val : '(empty)',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: val.isNotEmpty
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread dataset detail — all fields + hex editor
// ---------------------------------------------------------------------------

class _ThreadDatasetDetailScreen extends StatefulWidget {
  final String initialHex;
  const _ThreadDatasetDetailScreen({required this.initialHex});

  @override
  State<_ThreadDatasetDetailScreen> createState() =>
      _ThreadDatasetDetailScreenState();
}

class _ThreadDatasetDetailScreenState
    extends State<_ThreadDatasetDetailScreen> {
  late TextEditingController _ctrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialHex);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ThreadSettingsService.save(_ctrl.text);
    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Thread dataset saved'),
            duration: Duration(seconds: 2)),
      );
      Future.delayed(const Duration(seconds: 2),
          () { if (mounted) setState(() => _saved = false); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final cleanHex = _ctrl.text.replaceAll(RegExp(r'\s'), '');
    final fields   = _ThreadDecoder.decode(cleanHex);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dataset'),
        actions: [
          IconButton(
            icon: Icon(_saved ? Icons.check : Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Decoded fields ─────────────────────────────────────────────
          if (fields.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: fields
                      .map((f) => _FieldRow(label: f.label, value: f.value))
                      .toList(),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── Hex input ──────────────────────────────────────────────────
          _SectionHeader(title: 'Hex (TLV)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Operational dataset',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        tooltip: 'Copy hex',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: cleanHex));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Dataset copied'),
                                duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctrl,
                    maxLines: null,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      hintText: 'Paste hex dataset…',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                    ),
                    keyboardType: TextInputType.multiline,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9a-fA-F\s]')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: () async {
              _ctrl.text = ThreadSettingsService.defaultDataset;
              await _save();
            },
            icon: const Icon(Icons.restore),
            label: const Text('Reset to default (NEST-PAN-26BA)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread TLV decoder
// ---------------------------------------------------------------------------

class _ThreadDecoder {
  static List<({String label, String value})> decode(String hex) {
    if (hex.length < 4 || hex.length.isOdd) return [];

    final bytes = <int>[];
    for (int i = 0; i + 1 < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }

    // Parse all TLVs into a map keyed by type.
    final Map<int, List<int>> tlvs = {};
    int i = 0;
    while (i + 1 < bytes.length) {
      final type = bytes[i];
      final len  = bytes[i + 1];
      if (i + 2 + len > bytes.length) break;
      tlvs[type] = bytes.sublist(i + 2, i + 2 + len);
      i += 2 + len;
    }

    // Build output in user-requested order.
    final out = <({String label, String value})>[];

    void add(String label, String value) => out.add((label: label, value: value));

    // 1. Network Name (0x03)
    if (tlvs.containsKey(0x03)) {
      add('Network Name', String.fromCharCodes(tlvs[0x03]!));
    }

    // 2. Network Key (0x05)
    if (tlvs.containsKey(0x05)) {
      add('Network Key', _hex(tlvs[0x05]!));
    }

    // 3. Channel (0x00)  4. Channel Page
    if (tlvs.containsKey(0x00)) {
      final v = tlvs[0x00]!;
      if (v.length >= 3) {
        add('Channel', '${(v[1] << 8) | v[2]}');
        add('Channel Page', '${v[0]}');
      }
    }

    // 5. Channel Mask (0x35)
    if (tlvs.containsKey(0x35)) {
      final v = tlvs[0x35]!;
      if (v.length >= 2) {
        final page = v[0];
        final maskLen = v[1];
        if (v.length >= 2 + maskLen) {
          final mask = _hex(v.sublist(2, 2 + maskLen)).toUpperCase();
          add('Channel Masks', '{Page: $page, Mask: $mask}');
        }
      }
    }

    // 6. PAN ID (0x01) — decimal
    if (tlvs.containsKey(0x01)) {
      final v = tlvs[0x01]!;
      if (v.length >= 2) {
        add('PAN ID', '${(v[0] << 8) | v[1]}');
      }
    }

    // 7. Extended PAN ID (0x02)
    if (tlvs.containsKey(0x02)) {
      add('Ext PAN ID', _hex(tlvs[0x02]!));
    }

    // 8. Mesh-Local Prefix (0x07)
    if (tlvs.containsKey(0x07)) {
      add('Mesh Local Prefix', _hex(tlvs[0x07]!));
    }

    // 9. PSKc (0x04)
    if (tlvs.containsKey(0x04)) {
      add('PSKc', _hex(tlvs[0x04]!));
    }

    // 10. Security Policy (0x0C)
    if (tlvs.containsKey(0x0C)) {
      final v = tlvs[0x0C]!;
      if (v.length >= 4) {
        final rot   = (v[0] << 8) | v[1];
        final flags = _hexUpper(v.sublist(2, 4));
        add('Security Policy', '{Rotation: ${rot}h, Flags: $flags}');
      }
    }

    // 11. Active Timestamp (0x0E)
    if (tlvs.containsKey(0x0E)) {
      final v = tlvs[0x0E]!;
      if (v.length >= 8) {
        int secs = 0;
        for (int j = 0; j < 6; j++) { secs = (secs << 8) | v[j]; }
        final last2 = (v[6] << 8) | v[7];
        final ticks = last2 >> 1;
        final auth  = (last2 & 1) == 1;
        add('Active Timestamp',
            '{Seconds: $secs, Ticks: $ticks, IsAuthoritativeSource: $auth}');
      }
    }

    // 12. Pending Timestamp (0x0F) if present
    if (tlvs.containsKey(0x0F)) {
      final v = tlvs[0x0F]!;
      if (v.length >= 8) {
        int secs = 0;
        for (int j = 0; j < 6; j++) { secs = (secs << 8) | v[j]; }
        add('Pending Timestamp', 'Seconds: $secs');
      }
    }

    return out;
  }

  static String _hex(List<int> b) =>
      b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  static String _hexUpper(List<int> b) => _hex(b).toUpperCase();
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  const _FieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
