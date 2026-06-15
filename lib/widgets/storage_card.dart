import 'package:flutter/material.dart';
import 'package:iris/models/storages/storage.dart';

class StorageCard extends StatelessWidget {
  const StorageCard({
    super.key,
    required this.storage,
    this.onTap,
  });

  final Storage storage;
  final VoidCallback? onTap;

  static IconData iconForType(StorageType type) {
    switch (type) {
      case StorageType.internal:
      case StorageType.network:
      case StorageType.usb:
      case StorageType.sdcard:
        return Icons.folder_rounded;
      case StorageType.webdav:
        return Icons.cloud_rounded;
      case StorageType.ftp:
        return Icons.dns_rounded;
      case StorageType.none:
        return Icons.storage_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      iconForType(storage.type),
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              storage.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
