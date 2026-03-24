import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/matter_device.dart';
import '../../providers/device_provider.dart';
import 'cluster_inspector_screen.dart';

class DeviceSettingsScreen extends StatelessWidget {
  final MatterDevice device;
  const DeviceSettingsScreen({super.key, required this.device});

  Future<void> _remove(BuildContext context, MatterDevice d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove device?'),
        content: Text(
          '"${d.name}" will be removed from this fabric. '
          'The device will need to be factory-reset before it can be re-commissioned.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<DeviceProvider>().removeDevice(d.id);
      if (context.mounted) context.go('/');
    }
  }

  Future<void> _rename(BuildContext context) async {
    final ctrl = TextEditingController(text: device.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Device name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && context.mounted) {
      await context.read<DeviceProvider>().renameDevice(device.id, newName);
      // Refresh the title after rename
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        // Use fresh copy in case name was just updated
        final d = provider.findById(device.id) ?? device;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Device settings',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Rename ──────────────────────────────────────────────────
              _SectionLabel('Name'),
              Card(
                color: cs.surface,
                child: ListTile(
                  leading: Icon(Icons.label_outline, color: cs.primary),
                  title: Text(d.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tap to rename'),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _rename(context),
                ),
              ),

              const SizedBox(height: 20),

              // ── Device info ──────────────────────────────────────────────
              _SectionLabel('Device info'),
              Card(
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      _InfoRow(label: 'Type',
                          value: d.deviceType.displayName),
                      _InfoRow(
                        label: 'Node ID',
                        value: '0x${d.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}',
                        mono: true,
                      ),
                      _InfoRow(
                        label: 'Commissioned',
                        value: _formatDate(d.commissionedAt),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Tools ────────────────────────────────────────────────────
              _SectionLabel('Tools'),
              Card(
                color: cs.surface,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.refresh, color: cs.primary),
                      title: const Text('Refresh state'),
                      trailing: const Icon(Icons.chevron_right),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      onTap: () {
                        provider.refreshDevice(d.id);
                        Navigator.pop(context);
                      },
                    ),
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant),
                    ListTile(
                      leading: Icon(Icons.manage_search, color: cs.primary),
                      title: const Text('Inspect clusters'),
                      subtitle:
                          const Text('View all Matter clusters and attributes'),
                      trailing: const Icon(Icons.chevron_right),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClusterInspectorScreen(device: d),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Remove device ─────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () => _remove(context, d),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove device'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withAlpha(120)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _InfoRow(
      {required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: mono ? 'monospace' : null,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }
}
