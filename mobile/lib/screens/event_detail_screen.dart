import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/services/api/rest_api_service.dart';
import '../models/alert_message.dart';

typedef EventLoader = Future<AlertMessage> Function(int eventId);

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final AlertMessage event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class EventDetailLoaderScreen extends StatefulWidget {
  const EventDetailLoaderScreen({
    super.key,
    required this.eventId,
    this.loadEvent,
  });

  final int eventId;
  final EventLoader? loadEvent;

  @override
  State<EventDetailLoaderScreen> createState() =>
      _EventDetailLoaderScreenState();
}

class _EventDetailLoaderScreenState extends State<EventDetailLoaderScreen> {
  late Future<AlertMessage> _event;

  @override
  void initState() {
    super.initState();
    _event = _loadEvent();
  }

  Future<AlertMessage> _loadEvent() async {
    if (widget.loadEvent != null) return widget.loadEvent!(widget.eventId);
    final data = await RestApiService().getAlert(widget.eventId);
    return AlertMessage.fromJson(data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AlertMessage>(
      future: _event,
      builder: (context, snapshot) {
        if (snapshot.hasData) return EventDetailScreen(event: snapshot.data!);
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xfff6f7f4),
            body: Center(
              child: TextButton(
                onPressed: () => setState(() => _event = _loadEvent()),
                child: const Text('לא ניתן לטעון את האירוע. נסו שוב'),
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: Color(0xfff6f7f4),
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late AlertMessage _event;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  Future<void> _respond(String response) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final updated = await RestApiService().respondToAlert(
        id: _event.id,
        response: response,
      );
      if (!mounted) return;
      setState(() => _event = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response == 'accept' ? 'התגובה נשלחה' : 'האירוע נדחה'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לעדכן את האירוע כרגע. נסו שוב.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _event.status.toLowerCase();
    final canRespond = status == 'open' || status == 'dispatched';
    final isAccepted = status == 'accepted' || status == 'in_progress';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff6f7f4),
        body: Column(
          children: [
            _DetailHeader(event: _event),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  if (_isUrgent(_event) && canRespond) ...[
                    const _UrgentNotice(),
                    const SizedBox(height: 22),
                  ],
                  const _SectionLabel('מיקום'),
                  const SizedBox(height: 9),
                  _LocationCard(event: _event),
                  const SizedBox(height: 22),
                  const _SectionLabel('פרטי האירוע'),
                  const SizedBox(height: 9),
                  _DetailCard(event: _event),
                  if (_event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const _SectionLabel('הערות מהמוקד'),
                    const SizedBox(height: 9),
                    _NotesCard(notes: _event.description),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              height: 48,
              child: isAccepted
                  ? FilledButton.icon(
                      onPressed: _sending ? null : () => _respond('arrive'),
                      icon: const Icon(Icons.directions_run_rounded),
                      label: const Text('דיווח הגעה'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff078658),
                        foregroundColor: Colors.white,
                      ),
                    )
                  : canRespond
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _sending ? null : () => _respond('decline'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xffb32d3d),
                                  side: const BorderSide(
                                      color: Color(0xffe2b9be)),
                                ),
                                child: const Text('לא יכול/ה'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    _sending ? null : () => _respond('accept'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff078658),
                                  foregroundColor: Colors.white,
                                ),
                                child:
                                    Text(_sending ? 'שולח/ת...' : 'אני מגיע/ה'),
                              ),
                            ),
                          ],
                        )
                      : FilledButton(
                          onPressed: null,
                          child: Text(_statusLabel(_event.status)),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.event});

  final AlertMessage event;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xff16233a),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white),
                    tooltip: 'חזרה',
                  ),
                  const Text('חזרה',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  const Spacer(),
                  Image.asset('assets/images/figma/raw_image_2.png',
                      height: 31),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'אירוע #${event.id}',
                style: const TextStyle(color: Color(0xffbdc8da), fontSize: 13),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _HeaderChip(
                      label: _priorityLabel(event.priority),
                      color: _priorityColor(event.priority)),
                  _HeaderChip(
                      label: _statusLabel(event.status),
                      color: const Color(0xff4e7dca)),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _dateTime(event.createdAt),
                style: const TextStyle(color: Color(0xffbdc8da), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _UrgentNotice extends StatelessWidget {
  const _UrgentNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xffffe9e8),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            SvgPicture.asset('assets/images/figma/figma_icon_1.svg',
                width: 20, height: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'אירוע דחוף — נדרשת תגובה מיידית',
                style: TextStyle(
                    color: Color(0xffa72b38),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
            color: Color(0xff17233a),
            fontSize: 17,
            fontWeight: FontWeight.w800),
      );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.event});
  final AlertMessage event;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: _cardDecoration,
        child: Column(
          children: [
            Container(
              height: 126,
              color: const Color(0xffdcefdc),
              alignment: Alignment.center,
              child: const Icon(Icons.location_on_rounded,
                  color: Color(0xffdc4451), size: 42),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  _locationRow(
                      Icons.location_on_outlined,
                      event.location.trim().isEmpty
                          ? 'מיקום לא צוין'
                          : event.location),
                  const SizedBox(height: 10),
                  _locationRow(
                    Icons.my_location_rounded,
                    '${event.latitude.toStringAsFixed(5)}, ${event.longitude.toStringAsFixed(5)}',
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _locationRow(
    IconData icon,
    String value, {
    TextDirection? textDirection,
  }) =>
      Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xff64748b)),
          const SizedBox(width: 9),
          Expanded(
              child: Text(value,
                  textDirection: textDirection,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xff344258), fontSize: 14))),
        ],
      );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.event});
  final AlertMessage event;

  @override
  Widget build(BuildContext context) => Container(
        decoration: _cardDecoration,
        child: Column(
          children: [
            _DetailRow(
                icon: Icons.priority_high_rounded,
                label: 'עדיפות',
                value: _priorityLabel(event.priority)),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _DetailRow(
                icon: Icons.info_outline_rounded,
                label: 'סטטוס',
                value: _statusLabel(event.status)),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'עודכן לאחרונה',
                value: _dateTime(event.updatedAt)),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xff63738a)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Color(0xff64748b), fontSize: 14))),
            const SizedBox(width: 10),
            Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xff1d2a40),
                        fontSize: 14,
                        fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: _cardDecoration,
        child: Text(notes,
            style: const TextStyle(
                color: Color(0xff344258), fontSize: 14, height: 1.5)),
      );
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: const [
    BoxShadow(color: Color(0x140f172a), blurRadius: 11, offset: Offset(0, 3))
  ],
);

bool _isUrgent(AlertMessage event) {
  final priority = event.priority.toLowerCase();
  return priority == 'critical' || priority == 'high' || priority == 'urgent';
}

String _priorityLabel(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return 'קריטי';
    case 'high':
      return 'דחוף';
    case 'medium':
      return 'בינוני';
    case 'low':
      return 'נמוך';
    default:
      return priority.isEmpty ? 'לא צוין' : priority;
  }
}

Color _priorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return const Color(0xffff9098);
    case 'high':
      return const Color(0xffffb05e);
    case 'medium':
      return const Color(0xffffd166);
    default:
      return const Color(0xff9bb6e7);
  }
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'open':
      return 'פתוח';
    case 'dispatched':
      return 'נשלח למתנדבים';
    case 'accepted':
      return 'בטיפול';
    case 'in_progress':
      return 'בביצוע';
    case 'resolved':
      return 'טופל';
    case 'closed':
      return 'סגור';
    default:
      return status.isEmpty ? 'לא צוין' : status;
  }
}

String _dateTime(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
