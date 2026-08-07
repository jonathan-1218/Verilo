import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_scope.dart';
import '../core/colors.dart';
import '../core/database.dart';
import '../core/project_card.dart';
import '../core/text_styles.dart';
import '../core/widgets.dart';

/// The Map tab: every project site on a real OpenStreetMap view, with the
/// located list beneath. Tiles are the free OSM public server (attribution
/// required, no API key).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Project> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await appRepository.allProjects();
    if (!mounted) return;
    setState(() { _projects = projects; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final located = _projects.where((p) => p.lat != null && p.lng != null).toList();
    // center on the sites; fall back to an all-India view when none are set
    final center = located.isEmpty
        ? const LatLng(21.0, 78.5)
        : LatLng(
            located.map((p) => p.lat!).reduce((a, b) => a + b) / located.length,
            located.map((p) => p.lng!).reduce((a, b) => a + b) / located.length,
          );
    return TabBackScope(
        child: Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.copperMid))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),
                          Text('Field map', style: AppText.spaceGrotesk(size: 20, weight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('Every project site at a glance',
                              style: AppText.spaceGrotesk(size: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 320,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: center,
                                  initialZoom: located.length == 1 ? 12 : 4.6,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.verilo.verilo',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      for (final p in located)
                                        Marker(
                                          point: LatLng(p.lat!, p.lng!),
                                          width: 40,
                                          height: 40,
                                          alignment: Alignment.topCenter,
                                          child: GestureDetector(
                                            onTap: () => context.push('/project/${p.id}'),
                                            child: Icon(Icons.location_on,
                                                size: 36,
                                                color: statusColor(p.status),
                                                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SimpleAttributionWidget(
                                    source: Text('OpenStreetMap contributors', style: TextStyle(fontSize: 9)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('${located.length} PROJECTS LOCATED', style: AppText.label),
                          const SizedBox(height: 8),
                          ..._projects.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _LocationRow(
                                  color: statusColor(p.status),
                                  name: p.name,
                                  coords: p.lat != null
                                      ? '${p.lat!.toStringAsFixed(4)}°N ${p.lng!.toStringAsFixed(4)}°E'
                                      : 'No GPS set',
                                  onTap: () => context.push('/project/${p.id}'),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
          ),
          BottomNav(currentIndex: 2, onTap: (i) {
            if (i == 2) return;
            context.go(switch (i) { 0 => '/dashboard', 1 => '/projects', _ => '/profile' });
          }),
        ],
      ),
    ));
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.color, required this.name, required this.coords, required this.onTap});
  final Color color;
  final String name, coords;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.spaceGrotesk(size: 13, weight: FontWeight.w600)),
                  Text(coords, style: AppText.jetBrainsMono(size: 11, color: AppColors.textSecondary)),
                ],
              )),
              Text('›', style: AppText.spaceGrotesk(size: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}
