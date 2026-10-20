import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/domain/services/ptt_session.dart';

class PttTabScreen extends StatefulWidget {
  const PttTabScreen({super.key, this.session, this.loadGroups});

  final PttSession? session;
  final Future<List<dynamic>> Function()? loadGroups;

  @override
  State<PttTabScreen> createState() => _PttTabScreenState();
}

class _PttTabScreenState extends State<PttTabScreen> {
  late final PttSession _session;
  List<_PttGroup> _groups = const [];
  _PttGroup? _selectedGroup;
  String? _error;
  bool _loading = true;
  bool _connecting = false;
  bool _transmitting = false;

  bool get _connected => _session.connected;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? PttSession.live();
    _session.addListener(_onRoomChanged);
    _loadGroups();
  }

  @override
  void dispose() {
    _session.removeListener(_onRoomChanged);
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = (await (widget.loadGroups ?? RestApiService().listGroups)())
          .whereType<Map<String, dynamic>>()
          .map(_PttGroup.fromJson)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = groups.isEmpty
            ? null
            : groups.firstWhere(
                (group) => group.id == _selectedGroup?.id,
                orElse: () => groups.first,
              );
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'לא ניתן לטעון את קבוצות הקשר כרגע.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectGroup(_PttGroup group) async {
    await _leaveRoom();
    if (mounted) setState(() => _selectedGroup = group);
  }

  Future<void> _joinRoom() async {
    final group = _selectedGroup;
    if (group == null || _connecting || _connected) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _session.join(group.id);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'לא ניתן להתחבר לקשר כרגע. נסו שוב.');
      }
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _leaveRoom() async {
    await _session.leave();
    if (mounted) {
      setState(() {
        _transmitting = false;
      });
    }
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startTransmission() async {
    if (!_connected) {
      await _joinRoom();
      return;
    }
    try {
      if (!await _session.startTransmission()) {
        if (mounted) {
          setState(() => _error = 'נדרשת הרשאת מיקרופון כדי לשדר.');
        }
        return;
      }
      if (mounted) setState(() => _transmitting = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'לא ניתן להתחיל שידור כרגע. נסו שוב.');
      }
    }
  }

  Future<void> _stopTransmission() async {
    if (!_transmitting) return;
    await _session.stopTransmission();
    if (mounted) setState(() => _transmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final group = _selectedGroup;
    final speakers = _session.activeSpeakerNames.join(', ');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: const Color(0xFF16233A),
        child: RefreshIndicator(
          color: const Color(0xFF128A5E),
          onRefresh: _loadGroups,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              _ConnectionCard(
                memberCount: group?.memberCount ?? 0,
                connected: _connected,
                speakers: speakers,
              ),
              const SizedBox(height: 22),
              const Align(
                  alignment: Alignment.centerRight,
                  child: Text('קבוצות',
                      style: TextStyle(
                          color: Color(0x80FFFFFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w600))),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF128A5E))))
              else if (_error != null && _groups.isEmpty)
                _ErrorCard(message: _error!, onRetry: _loadGroups)
              else if (_groups.isEmpty)
                const _EmptyGroups()
              else
                _GroupGrid(
                    groups: _groups,
                    selectedId: group?.id,
                    onSelected: (value) => _selectGroup(value)),
              if (_error != null && _groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFFFB4AB))),
              ],
              const SizedBox(height: 36),
              if (group != null) ...[
                _GroupPill(name: group.name),
                const SizedBox(height: 20),
                Text(
                    _transmitting
                        ? 'משדר/ת… שחרר/י לסיום'
                        : _connected
                            ? 'לחץ והחזק כדי לדבר'
                            : 'התחבר/י לקשר כדי לדבר',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                if (!_connected)
                  Center(
                      child: FilledButton(
                          onPressed: _connecting ? null : _joinRoom,
                          child:
                              Text(_connecting ? 'מתחבר/ת…' : 'התחבר/י לקשר'))),
                Center(
                  child: GestureDetector(
                    onLongPressStart: (_) => _startTransmission(),
                    onLongPressEnd: (_) => _stopTransmission(),
                    onLongPressCancel: _stopTransmission,
                    child: Semantics(
                      button: true,
                      label: _transmitting
                          ? 'שידור פעיל, שחרר לסיום'
                          : 'לחצן דיבור, לחץ והחזק לשידור',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 208,
                        height: 208,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x1AFFFFFF),
                            border: Border.all(
                                color: _transmitting
                                    ? const Color(0xFF80D5BA)
                                    : Colors.transparent,
                                width: 3)),
                        child: Container(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _transmitting
                                    ? const Color(0xFFD43A2F)
                                    : const Color(0xFF128A5E)),
                            alignment: Alignment.center,
                            child: Icon(
                                _transmitting ? Icons.graphic_eq : Icons.radio,
                                color: Colors.white,
                                size: 64)),
                      ),
                    ),
                  ),
                ),
                if (_connected)
                  Center(
                      child: TextButton(
                          onPressed: _leaveRoom,
                          child: const Text('ניתוק קשר',
                              style: TextStyle(color: Color(0xFF80D5BA))))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PttGroup {
  const _PttGroup(
      {required this.id, required this.name, required this.memberCount});
  factory _PttGroup.fromJson(Map<String, dynamic> json) => _PttGroup(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'קבוצה ללא שם',
      memberCount: (json['members'] as List<dynamic>? ?? const []).length);
  final int id;
  final String name;
  final int memberCount;
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard(
      {required this.memberCount,
      required this.connected,
      required this.speakers});
  final int memberCount;
  final bool connected;
  final String speakers;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1AFFFFFF))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Icon(Icons.groups_outlined, color: Color(0xB3FFFFFF), size: 18),
          const SizedBox(width: 6),
          Text('$memberCount חברים',
              style: const TextStyle(color: Color(0xB3FFFFFF)))
        ]),
        Flexible(
            child: Text(
                connected
                    ? (speakers.isEmpty ? 'מחובר/ת' : 'מדבר/ת: $speakers')
                    : 'לא מחובר/ת',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: connected ? Colors.white : const Color(0xB3FFFFFF),
                    fontWeight: FontWeight.w600)))
      ]));
}

class _GroupGrid extends StatelessWidget {
  const _GroupGrid(
      {required this.groups,
      required this.selectedId,
      required this.onSelected});
  final List<_PttGroup> groups;
  final int? selectedId;
  final ValueChanged<_PttGroup> onSelected;
  @override
  Widget build(BuildContext context) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: .88),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final selected = group.id == selectedId;
        return InkWell(
            onTap: () => onSelected(group),
            borderRadius: BorderRadius.circular(48),
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? const Color(0xFF128A5E)
                            : const Color(0x1AFFFFFF)),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                        'assets/images/figma/figma_icon_2.svg',
                        width: 30,
                        height: 30)),
                if (selected)
                  const Positioned(
                      left: -2,
                      bottom: -2,
                      child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(0xFF0E6F4C),
                          child:
                              Icon(Icons.check, color: Colors.white, size: 15)))
              ]),
              const SizedBox(height: 8),
              Text(group.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: selected ? Colors.white : const Color(0xB3FFFFFF),
                      fontWeight: FontWeight.w600,
                      fontSize: 12))
            ]));
      });
}

class _GroupPill extends StatelessWidget {
  const _GroupPill({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(30)),
              child: Text('קבוצת $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontWeight: FontWeight.w600)))));
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
          child: Text('אין קבוצות קשר זמינות עבורך.',
              style: TextStyle(color: Color(0xB3FFFFFF)))));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFB4AB)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'נסה שוב',
              style: TextStyle(color: Color(0xFF80D5BA)),
            ),
          ),
        ],
      );
}
