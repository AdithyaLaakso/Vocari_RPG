import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'game_models.dart';

class LocationCard extends StatelessWidget {
  final Location location;

  const LocationCard({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getLocationColor().withValues(alpha: 0.3),
            _getLocationColor().withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(
          color: _getLocationColor().withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getLocationColor().withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getLocationColor().withValues(alpha: 0.2),
                  border: Border.all(
                    color: _getLocationColor().withValues(alpha: 0.5),
                  ),
                ),
                child: Center(
                  child: Text(
                    location.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                    duration: 2.seconds,
                  ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _getLocationColor(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: _getLocationColor().withValues(alpha: 0.2),
                          ),
                          child: Text(
                            location.type.name.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _getLocationColor(),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            location.displayDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLocationColor() {
    switch (location.type) {
      case LocationType.outdoor:
        return Colors.green;
      case LocationType.building:
        return const Color(0xFFD4AF37);
      case LocationType.dungeon:
        return Colors.purple;
    }
  }
}
