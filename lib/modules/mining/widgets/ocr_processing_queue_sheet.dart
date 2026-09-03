import 'package:flutter/material.dart';
import 'package:mangayomi/services/mining/ocr_processing_queue.dart';

Future<void> showOcrProcessingQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const OcrProcessingQueueSheet(),
  );
}

class OcrProcessingQueueSheet extends StatelessWidget {
  const OcrProcessingQueueSheet({super.key, this.controller});

  final OcrProcessingQueueController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller ?? OcrProcessingQueueController.instance;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: ValueListenableBuilder<List<OcrQueueEntry>>(
          valueListenable: controller.entries,
          builder: (context, entries, _) {
            final errorCount = entries
                .where((entry) => entry.status == OcrQueueStatus.error)
                .length;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'OCR processing queue (${entries.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (errorCount > 0)
                        TextButton.icon(
                          onPressed: controller.retryAllErrors,
                          icon: const Icon(Icons.refresh),
                          label: Text('Retry failed ($errorCount)'),
                        ),
                      IconButton(
                        tooltip: 'Clear finished items',
                        onPressed: entries.isEmpty
                            ? null
                            : controller.clearFinished,
                        icon: const Icon(Icons.clear_all),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('The OCR queue is empty'))
                      : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) => _QueueRow(
                            entry: entries[index],
                            onRetry: () => controller.retry(entries[index].id),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.entry, required this.onRetry});

  final OcrQueueEntry entry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = entry.status == OcrQueueStatus.error;
    return ListTile(
      onTap: failed ? onRetry : null,
      leading: _statusIcon(context),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            _statusText,
            maxLines: failed ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: failed ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ],
      ),
      trailing: failed
          ? IconButton(
              tooltip: 'Retry OCR',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            )
          : null,
    );
  }

  Widget _statusIcon(BuildContext context) => switch (entry.status) {
    OcrQueueStatus.pending => const Icon(Icons.schedule),
    OcrQueueStatus.processing => SizedBox.square(
      dimension: 28,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        value: entry.total > 0 ? entry.completed / entry.total : null,
      ),
    ),
    OcrQueueStatus.completed => Icon(
      Icons.check_circle,
      color: Theme.of(context).colorScheme.primary,
    ),
    OcrQueueStatus.error => Icon(
      Icons.error_outline,
      color: Theme.of(context).colorScheme.error,
    ),
  };

  String get _statusText => switch (entry.status) {
    OcrQueueStatus.pending => 'Waiting',
    OcrQueueStatus.processing =>
      entry.total > 0
          ? 'Page ${entry.completed}/${entry.total} · attempt ${entry.attempt}/3'
          : 'Preparing · attempt ${entry.attempt}/3',
    OcrQueueStatus.completed => 'OCR ready',
    OcrQueueStatus.error => '${entry.error ?? 'OCR failed'} · tap to retry',
  };
}
