import 'package:flutter/material.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _editingDetails = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await RestApiService().getCurrentUserProfile();
      if (!mounted) return;
      setState(() {
        _nameController.text = profile['display_name'] as String? ?? '';
        _phoneController.text = profile['phone'] as String? ?? '';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('לא ניתן לטעון את ההגדרות כרגע. נסו שוב.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await RestApiService().updateCurrentUserProfile({
        'display_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      if (!mounted) return;
      setState(() => _editingDetails = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הפרטים נשמרו.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('לא ניתן לשמור את הפרטים כרגע. נסו שוב.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _displayName {
    final name = _nameController.text.trim();
    // Firebase UIDs are implementation identifiers, not responder-facing names.
    return name.isEmpty ? 'מתנדב/ת' : name;
  }

  String get _initials {
    final words = _displayName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final initials = words.map((word) => word.characters.first).join();
    return initials.isEmpty ? 'מ' : initials;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()))
            else ...[
              _ProfileCard(
                  name: _displayName,
                  phone: _phoneController.text.trim(),
                  initials: _initials),
              const SizedBox(height: 24),
              const _SectionTitle('פרטים אישיים'),
              const SizedBox(height: 10),
              _SettingsSurface(
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.person_outline,
                      title: 'פרטים אישיים',
                      subtitle: _editingDetails
                          ? 'עריכת שם וטלפון'
                          : 'עדכון שם ופרטי התקשרות',
                      trailing: Icon(
                          _editingDetails
                              ? Icons.expand_less
                              : Icons.chevron_left,
                          color: const Color(0xFF8A94A6)),
                      onTap: () =>
                          setState(() => _editingDetails = !_editingDetails),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 180),
                      crossFadeState: _editingDetails
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              textAlign: TextAlign.right,
                              onChanged: (_) => setState(() {}),
                              decoration: _inputDecoration(
                                  'שם מלא', Icons.person_outline),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneController,
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDecoration(
                                  'טלפון', Icons.phone_outlined),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _saving ? null : _save,
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF128A5E),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13)),
                                child: Text(_saving ? 'שומר…' : 'שמירת פרטים'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('התראות'),
              const SizedBox(height: 10),
              const _SettingsSurface(
                child: Column(
                  children: [
                    _SettingsRow(
                        icon: Icons.notifications_none,
                        title: 'התראות דחיפה',
                        subtitle: 'מנוהלות לפי הרשאות המכשיר',
                        trailing: _StatusChip('פעיל')),
                    Divider(height: 1, color: Color(0xFFE7E8E2)),
                    _SettingsRow(
                        icon: Icons.volume_up_outlined,
                        title: 'צליל התראה',
                        subtitle: 'צליל המכשיר מוגדר בהגדרות המערכת',
                        trailing: Icon(Icons.open_in_new,
                            color: Color(0xFF8A94A6), size: 19)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('מידע'),
              const SizedBox(height: 10),
              const _SettingsSurface(
                child: Column(
                  children: [
                    _SettingsRow(
                        icon: Icons.location_on_outlined,
                        title: 'שיתוף מיקום',
                        subtitle: 'פעיל רק כאשר האפליקציה פתוחה',
                        trailing:
                            Icon(Icons.info_outline, color: Color(0xFF8A94A6))),
                    Divider(height: 1, color: Color(0xFFE7E8E2)),
                    _SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'פרטיות והרשאות',
                        subtitle: 'מיקום והתראות ניתנים לשליטה במכשיר',
                        trailing:
                            Icon(Icons.chevron_left, color: Color(0xFF8A94A6))),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                  child: Text('מלאכים בדרכים · גרסה 4.2.0',
                      style:
                          TextStyle(color: Color(0xFF8A94A6), fontSize: 12))),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF5A677D)),
        filled: true,
        fillColor: const Color(0xFFF6F7F4),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE7E8E2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE7E8E2))),
      );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard(
      {required this.name, required this.phone, required this.initials});
  final String name;
  final String phone;
  final String initials;

  @override
  Widget build(BuildContext context) => _SettingsSurface(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE6F4EE),
                  child: Text(initials,
                      style: const TextStyle(
                          color: Color(0xFF0E6F4C),
                          fontWeight: FontWeight.bold,
                          fontSize: 18))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF16233A),
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(phone.isEmpty ? 'השלם/י פרטי התקשרות' : phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF5A677D), fontSize: 13))
                  ])),
              const _StatusChip('זמין'),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF16233A),
              fontWeight: FontWeight.bold,
              fontSize: 15)));
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: const Color(0x3316233A),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child));
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.trailing,
      this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EE),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: const Color(0xFF128A5E))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF16233A),
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF5A677D), fontSize: 12))
                ])),
            const SizedBox(width: 8),
            trailing,
          ]),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: const Color(0xFFE6F4EE),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF128A5E))),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                color: Color(0xFF0E6F4C),
                fontSize: 12,
                fontWeight: FontWeight.bold))
      ]));
}
