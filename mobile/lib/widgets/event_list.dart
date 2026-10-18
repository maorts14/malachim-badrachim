import 'package:flutter/material.dart';
import 'package:rescue_app/models/alert_message.dart';

class EventsList extends StatefulWidget {
  const EventsList({required this.events, required this.onSelected, super.key});

  final List<AlertMessage> events;
  final ValueChanged<AlertMessage> onSelected;

  @override
  State<EventsList> createState() => _EventsListState();
}

class _EventsListState extends State<EventsList> {
  _EventFilter _filter = _EventFilter.all;

  List<AlertMessage> get _visibleEvents => widget.events.where((event) {
        switch (_filter) {
          case _EventFilter.urgent:
            return event.priority == 'CRITICAL' || event.priority == 'HIGH';
          case _EventFilter.unassigned:
            return event.status == 'OPEN';
          case _EventFilter.inProgress:
            return event.status == 'DISPATCHED' ||
                event.status == 'ACCEPTED' ||
                event.status == 'IN_PROGRESS';
          case _EventFilter.resolved:
            return event.status == 'RESOLVED' || event.status == 'CANCELLED';
          case _EventFilter.all:
            return true;
        }
      }).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final urgent = widget.events
        .where(
            (event) => event.priority == 'CRITICAL' && event.status == 'OPEN')
        .firstOrNull;
    final events = _visibleEvents;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (urgent != null) ...[
          _UrgentBanner(event: urgent, onTap: () => widget.onSelected(urgent)),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 40,
          child: Row(
            children: [
              for (var index = 0;
                  index < _EventFilter.values.length;
                  index++) ...[
                if (index > 0) const SizedBox(width: 6),
                Expanded(
                  child: _FilterButton(
                    filter: _EventFilter.values[index],
                    selected: _filter == _EventFilter.values[index],
                    onTap: () =>
                        setState(() => _filter = _EventFilter.values[index]),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('${events.length} אירועים',
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: Color(0xFF16233A),
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        const SizedBox(height: 10),
        if (events.isEmpty)
          const _EmptyEvents()
        else
          for (final event in events) ...[
            _EventRow(event: event, onTap: () => widget.onSelected(event)),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

enum _EventFilter {
  all('הכל'),
  urgent('דחוף'),
  unassigned('לא שובץ'),
  inProgress('בטיפול'),
  resolved('טופל');

  const _EventFilter(this.label);
  final String label;
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final _EventFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFF5A677D);
    return Semantics(
      button: true,
      selected: selected,
      label: 'סינון: ${filter.label}',
      child: Material(
        color: selected ? const Color(0xFF16233A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF16233A)
                    : const Color(0xFFE7E8E2),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  filter.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({required this.event, required this.onTap});
  final AlertMessage event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFD43A2F),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0x26FFFFFF),
                  child:
                      Icon(Icons.warning_amber_rounded, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('אירוע דחוף ממתין לשיבוץ',
                        style: TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15))
                  ])),
              const Icon(Icons.chevron_left, color: Colors.white),
            ]),
          ),
        ),
      );
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});
  final AlertMessage event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(event);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: const Color(0x2916233A),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 5,
                height: 54,
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(5))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    _Chip(text: _priorityLabel(event.priority), color: accent),
                    const SizedBox(width: 6),
                    _Chip(
                        text: _statusLabel(event.status),
                        color: _statusColor(event.status)),
                    const Spacer(),
                    Text('#${event.id}',
                        style: const TextStyle(
                            color: Color(0xFF8A94A6), fontSize: 12)),
                  ]),
                  const SizedBox(height: 7),
                  Text(event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF16233A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 7),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 15, color: Color(0xFF8A94A6)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF5A677D), fontSize: 13)))
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.schedule_outlined,
                        size: 15, color: Color(0xFF8A94A6)),
                    const SizedBox(width: 4),
                    Text(_displayTime(event.createdAt),
                        style: const TextStyle(
                            color: Color(0xFF5A677D), fontSize: 13)),
                    const Spacer(),
                    Text(_assignmentLabel(event.status),
                        style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600))
                  ]),
                ])),
            const SizedBox(width: 4),
            const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Icon(Icons.chevron_left, color: Color(0xFF8A94A6))),
          ]),
        ),
      ),
    );
  }

  static Color _accentColor(AlertMessage event) => event.priority == 'CRITICAL'
      ? const Color(0xFFD43A2F)
      : event.status == 'RESOLVED'
          ? const Color(0xFF128A5E)
          : const Color(0xFFE07A1F);
  static Color _statusColor(String status) => status == 'RESOLVED'
      ? const Color(0xFF128A5E)
      : status == 'OPEN'
          ? const Color(0xFFD43A2F)
          : const Color(0xFFE07A1F);
  static String _priorityLabel(String priority) => switch (priority) {
        'CRITICAL' => 'דחוף',
        'HIGH' => 'גבוה',
        'MEDIUM' => 'רגיל',
        _ => 'נמוך'
      };
  static String _statusLabel(String status) => switch (status) {
        'OPEN' => 'פתוח',
        'DISPATCHED' => 'שובץ',
        'ACCEPTED' => 'התקבל',
        'IN_PROGRESS' => 'בטיפול',
        'RESOLVED' => 'טופל',
        'CANCELLED' => 'בוטל',
        _ => status
      };
  static String _assignmentLabel(String status) => switch (status) {
        'OPEN' => 'לא שובץ',
        'DISPATCHED' => 'ממתין למענה',
        'ACCEPTED' || 'IN_PROGRESS' => 'שובץ',
        'RESOLVED' => 'הושלם',
        _ => ''
      };
  static String _displayTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)));
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Icon(Icons.event_busy_outlined, size: 56, color: Color(0xFF9AAEB9)),
        SizedBox(height: 12),
        Text('אין אירועים להצגה כרגע',
            style: TextStyle(color: Color(0xFF5A677D), fontSize: 16))
      ]));
}
