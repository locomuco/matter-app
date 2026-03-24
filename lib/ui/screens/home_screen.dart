import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/device_provider.dart';
import '../widgets/device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flux',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/commission'),
        backgroundColor: const Color(0xFFB85450), // washed-out red
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          if (provider.state == DeviceProviderState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.devices.isEmpty) {
            return _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: provider.refreshAll,
            child: CustomScrollView(
              slivers: [
                // Rooms grouping
                ..._buildRoomSections(context, provider),
                // FAB spacer
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildRoomSections(BuildContext context, DeviceProvider provider) {
    final rooms = provider.rooms;
    if (rooms.isEmpty) return [];

    return rooms.expand((room) {
      final roomDevices =
          provider.devices.where((d) => d.room == room).toList();
      return [
        if (room != 'Unassigned')
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
            sliver: SliverToBoxAdapter(
              child: Text(
                room,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final device = roomDevices[i];
                return DeviceCard(
                  device: device,
                  onTap: () => context.push('/device/${device.id}'),
                );
              },
              childCount: roomDevices.length,
            ),
          ),
        ),
      ];
    }).toList();
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hub_outlined,
                  size: 56, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text(
              'No devices yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add device" to commission your first Matter device into this fabric.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
