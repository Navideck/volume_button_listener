part of '../main.dart';

class _VolumeLogTile extends StatelessWidget {
  const _VolumeLogTile({required this.entry});

  final _LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUp = entry.direction == VolumeButtonDirection.up;

    final (color, isBold) = switch (entry.type) {
      _EventType.pressed => (
        isUp ? colorScheme.primary : colorScheme.tertiary,
        true,
      ),
      _EventType.released => (colorScheme.outline, false),
      _EventType.longPressed => (Colors.amber.shade800, true),
      _EventType.longPressReleased => (Colors.amber.shade700, false),
      _EventType.multiPressed => (Colors.deepPurple.shade400, true),
    };

    final icon = switch (entry.type) {
      _EventType.longPressed ||
      _EventType.longPressReleased => Icons.touch_app_rounded,
      _EventType.multiPressed => Icons.repeat_rounded,
      _ => (isUp ? Icons.add_circle : Icons.remove_circle),
    };

    final time = _formatTime(entry.at);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: color.withValues(alpha: isBold ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      time,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUp ? 'UP' : 'DOWN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtherLogTile extends StatelessWidget {
  const _OtherLogTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final time =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${(dt.millisecond ~/ 100).toString().padLeft(1, '0')}';
  if (d == today) return time;
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
  return '${dt.month}/${dt.day} $time';
}
