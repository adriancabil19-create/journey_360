import 'package:flutter_map/flutter_map.dart';

/// The shared OpenStreetMap tile layer (MD section 55). Kept in one place so the
/// provider can be swapped later without touching every map.
TileLayer journeyTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.journey360.app',
      maxZoom: 19,
      retinaMode: false,
    );

const journeyMapAttribution = 'OpenStreetMap contributors';
