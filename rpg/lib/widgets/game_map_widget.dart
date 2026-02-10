import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game_models.dart';
import '../providers/game_provider.dart';

/// A pannable, zoomable game map that shows locations as nodes
/// and connections as edges. Players can click connected locations to move.
class GameMapWidget extends ConsumerStatefulWidget {
  const GameMapWidget({super.key});

  @override
  ConsumerState<GameMapWidget> createState() => _GameMapWidgetState();
}

class _GameMapWidgetState extends ConsumerState<GameMapWidget> {
  final TransformationController _transformationController =
      TransformationController();

  // Node rendering constants
  static const double nodeRadius = 40.0;
  static const double nodePadding = 80.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gp = ref.watch(gameProvider);
    final world = gp.world;
    final currentLocation = gp.currentLocation;

    if (world == null || currentLocation == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final graph = world.locationGraph;
    final connectedIds = graph.getConnectedLocations(currentLocation.id);

    // Calculate the canvas size based on graph bounds
    final graphWidth = (graph.maxX - graph.minX + 2) * nodePadding;
    final graphHeight = (graph.maxY - graph.minY + 2) * nodePadding;

    return Column(
      children: [
        // Map header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.map, color: Color(0xFFD4AF37)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  world.mapMetadata?.name.native ?? 'World Map',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFD4AF37),
                      ),
                ),
              ),
              // Reset view button
              IconButton(
                icon: const Icon(Icons.center_focus_strong,
                    color: Colors.white54),
                tooltip: 'Center on current location',
                onPressed: () => _centerOnLocation(
                  currentLocation,
                  graph,
                  context,
                ),
              ),
            ],
          ),
        ),
        // Map legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              _buildLegendItem(
                color: const Color(0xFFD4AF37),
                label: 'Current',
              ),
              const SizedBox(width: 16),
              _buildLegendItem(
                color: Colors.green,
                label: 'Connected',
              ),
              const SizedBox(width: 16),
              _buildLegendItem(
                color: Colors.white30,
                label: 'Other',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Interactive map
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(100),
            minScale: 0.3,
            maxScale: 2.0,
            child: SizedBox(
              width: graphWidth,
              height: graphHeight,
              child: CustomPaint(
                painter: _MapEdgePainter(
                  graph: graph,
                  currentLocationId: currentLocation.id,
                  connectedIds: connectedIds,
                  nodePadding: nodePadding,
                ),
                child: Stack(
                  children: [
                    // Render all location nodes
                    for (final node in graph.nodes.values)
                      _buildLocationNode(
                        node: node,
                        location: world.locations[node.id]!,
                        isCurrent: node.id == currentLocation.id,
                        isConnected: connectedIds.contains(node.id),
                        graph: graph,
                        gameState: gp,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLocationNode({
    required LocationNode node,
    required Location location,
    required bool isCurrent,
    required bool isConnected,
    required LocationGraph graph,
    required GameState gameState,
  }) {
    // Calculate position based on coordinates
    final x = (node.x - graph.minX + 0.5) * nodePadding;
    final y = (node.y - graph.minY + 0.5) * nodePadding;

    // Determine node color based on state
    Color nodeColor;
    Color borderColor;
    double borderWidth;

    if (isCurrent) {
      nodeColor = const Color(0xFFD4AF37).withValues(alpha: 0.3);
      borderColor = const Color(0xFFD4AF37);
      borderWidth = 3;
    } else if (isConnected) {
      nodeColor = Colors.green.withValues(alpha: 0.2);
      borderColor = Colors.green;
      borderWidth = 2;
    } else {
      nodeColor = Colors.white.withValues(alpha: 0.05);
      borderColor = Colors.white30;
      borderWidth = 1;
    }

    return Positioned(
      left: x - nodeRadius,
      top: y - nodeRadius,
      child: GestureDetector(
        onTap: isConnected && !isCurrent
            ? () => ref.read(gameProvider.notifier).moveToLocation(node.id)
            : null,
        child: Container(
          width: nodeRadius * 2,
          height: nodeRadius * 2,
          decoration: BoxDecoration(
            color: nodeColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : isConnected
                    ? [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                location.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _truncateName(location.displayName),
                  style: TextStyle(
                    color: isCurrent
                        ? const Color(0xFFD4AF37)
                        : isConnected
                            ? Colors.green
                            : Colors.white54,
                    fontSize: 8,
                    fontWeight:
                        isCurrent || isConnected ? FontWeight.bold : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _truncateName(String name) {
    if (name.length <= 12) return name;
    // Try to split by space and take first word(s)
    final words = name.split(' ');
    if (words.length > 1) {
      return words.take(2).join(' ');
    }
    return '${name.substring(0, 10)}...';
  }

  void _centerOnLocation(
    Location location,
    LocationGraph graph,
    BuildContext context,
  ) {
    final node = graph.nodes[location.id];
    if (node == null) return;

    final x = (node.x - graph.minX + 0.5) * nodePadding;
    final y = (node.y - graph.minY + 0.5) * nodePadding;

    // Get the viewport size
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportWidth = renderBox.size.width;
    final viewportHeight = renderBox.size.height;

    // Calculate translation to center the node
    final translateX = viewportWidth / 2 - x;
    final translateY = viewportHeight / 2 - y;

    _transformationController.value =
        Matrix4.translationValues(translateX, translateY, 0);
  }
}

/// Custom painter for drawing edges between location nodes
class _MapEdgePainter extends CustomPainter {
  final LocationGraph graph;
  final String currentLocationId;
  final List<String> connectedIds;
  final double nodePadding;

  _MapEdgePainter({
    required this.graph,
    required this.currentLocationId,
    required this.connectedIds,
    required this.nodePadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Set<String> drawnEdges = {};

    for (final edge in graph.edges) {
      // Create a unique key for this edge (order-independent)
      final edgeKey = [edge.fromId, edge.toId]..sort();
      final edgeKeyStr = edgeKey.join('-');

      // Skip if already drawn
      if (drawnEdges.contains(edgeKeyStr)) continue;
      drawnEdges.add(edgeKeyStr);

      final fromNode = graph.nodes[edge.fromId];
      final toNode = graph.nodes[edge.toId];

      if (fromNode == null || toNode == null) continue;

      // Calculate positions
      final fromX = (fromNode.x - graph.minX + 0.5) * nodePadding;
      final fromY = (fromNode.y - graph.minY + 0.5) * nodePadding;
      final toX = (toNode.x - graph.minX + 0.5) * nodePadding;
      final toY = (toNode.y - graph.minY + 0.5) * nodePadding;

      // Determine edge color based on whether it connects to current location
      final isCurrentEdge = edge.fromId == currentLocationId ||
          edge.toId == currentLocationId;

      final paint = Paint()
        ..color = isCurrentEdge
            ? Colors.green.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = isCurrentEdge ? 3.0 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw line
      canvas.drawLine(
        Offset(fromX, fromY),
        Offset(toX, toY),
        paint,
      );

      // Draw a small dot at midpoint for visual interest
      if (isCurrentEdge) {
        final midX = (fromX + toX) / 2;
        final midY = (fromY + toY) / 2;
        final dotPaint = Paint()
          ..color = Colors.green.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(midX, midY), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapEdgePainter oldDelegate) {
    return oldDelegate.currentLocationId != currentLocationId ||
        oldDelegate.connectedIds != connectedIds;
  }
}
