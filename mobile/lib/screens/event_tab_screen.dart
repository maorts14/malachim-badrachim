import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rescue_app/domain/routing/app_route_paths.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/models/alert_message.dart';
import 'package:rescue_app/widgets/event_list.dart';

typedef AlertsLoader = Future<List<AlertMessage>> Function();

class EventTabScreen extends StatefulWidget {
  const EventTabScreen({this.loadAlerts, super.key});

  final AlertsLoader? loadAlerts;

  @override
  State<EventTabScreen> createState() => _EventTabScreenState();
}

class _EventTabScreenState extends State<EventTabScreen> {
  final openEvents = <AlertMessage>[];
  final closedEvents = <AlertMessage>[];
  bool _loading = true;
  bool _refreshInFlight = false;
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
          ? const _EventsLoadingState()
          : _loadError != null && events.isEmpty
              ? _EventsLoadFailure(onRetry: getAlerts)
              : Stack(
                  children: [
                    RefreshIndicator(
                      edgeOffset: 18,
                      displacement: 56,
                      triggerMode: RefreshIndicatorTriggerMode.onEdge,
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
    final changed =
        await context.push<bool>(AppRoutePaths.eventDetails(event.id));
    if (changed == true && mounted) await getAlerts();
  }

  Future<void> getAlerts() async {
    // A gentle overscroll can emit more than one refresh notification. Keep
    // the list responsive and make each pull map to a single network request.
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final alertsResult =
          await (widget.loadAlerts?.call() ?? RestApiService().getAllAlerts())
              .timeout(const Duration(seconds: 25));
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
      _refreshInFlight = false;
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
              color: Color(0xFFD43A2F),
            ),
            const SizedBox(height: 12),
            const Text(
              'לא ניתן להתחבר לשרת',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF16233A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'בדקו את חיבור האינטרנט ואת זמינות השרת, ואז נסו שוב.',
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

class _EventsLoadingState extends StatefulWidget {
  const _EventsLoadingState();

  @override
  State<_EventsLoadingState> createState() => _EventsLoadingStateState();
}

class _EventsLoadingStateState extends State<_EventsLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController = AnimationController(
    vsync: this,
    value: 0.06,
    duration: const Duration(seconds: 14),
  )..animateTo(0.92, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: AnimatedBuilder(
          animation: _progressController,
          builder: (context, _) {
            final percent = (_progressController.value * 100).round();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: CircularProgressIndicator(
                          value: _progressController.value,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFFE3E8E2),
                          color: const Color(0xFF128A5E),
                        ),
                      ),
                      Text(
                        '$percent%',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Color(0xFF16233A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'טוענים אירועים',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF16233A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'בודקים חיבור לשרת ומביאים את הנתונים העדכניים.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5A677D), height: 1.4),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
