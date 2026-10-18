import 'package:flutter/material.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/models/alert_message.dart';
import 'package:rescue_app/widgets/event_list.dart';
import 'package:rescue_app/screens/event_detail_screen.dart';

class EventTabScreen extends StatefulWidget {
  const EventTabScreen({super.key});

  @override
  State<EventTabScreen> createState() => _EventTabScreenState();
}

class _EventTabScreenState extends State<EventTabScreen> {
  final openEvents = <AlertMessage>[];
  final closedEvents = <AlertMessage>[];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    getAlerts();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final events = [...openEvents, ...closedEvents];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _loading && events.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && events.isEmpty
              ? _EventsLoadFailure(onRetry: getAlerts)
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: getAlerts,
                      child: EventsList(
                        events: events,
                        onSelected: _openEvent,
                      ),
                    ),
                    if (_loading)
                      const Positioned(
                        top: 0,
                        right: 0,
                        left: 0,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
    );
  }

  Future<void> _openEvent(AlertMessage event) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => EventDetailScreen(event: event)),
    );
    if (changed == true && mounted) await getAlerts();
  }

  Future<void> getAlerts() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final alertsResult = await RestApiService().getAllAlerts();
      if (!mounted) return;
      setState(() {
        openEvents
          ..clear()
          ..addAll(alertsResult.where((alert) =>
              alert.status != 'RESOLVED' && alert.status != 'CANCELLED'));
        closedEvents
          ..clear()
          ..addAll(alertsResult.where((alert) =>
              alert.status == 'RESOLVED' || alert.status == 'CANCELLED'));
        _loadError = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('לא ניתן לטעון את האירועים כרגע. נסו שוב.')),
        );
        setState(() => _loadError = 'לא ניתן לטעון את האירועים כרגע.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EventsLoadFailure extends StatelessWidget {
  const _EventsLoadFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Color(0xFF8A94A6),
            ),
            const SizedBox(height: 12),
            const Text(
              'לא ניתן לטעון את האירועים כרגע',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF16233A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'בדקו את החיבור ונסו שוב.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5A677D)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('נסה שוב'),
            ),
          ],
        ),
      ),
    );
  }
}
