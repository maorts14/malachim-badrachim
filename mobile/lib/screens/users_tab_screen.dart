import 'package:flutter/material.dart';
import 'package:rescue_app/constants/app_colors.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/models/user_details.dart';

class UsersTabScreen extends StatefulWidget {
  const UsersTabScreen({super.key});

  @override
  State<UsersTabScreen> createState() => _UsersTabScreenState();
}

class _UsersTabScreenState extends State<UsersTabScreen> {
  final _searchController = TextEditingController();
  List<UserDetails> _contacts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contacts = await RestApiService().getAllUsers();
      final currentUser = await RestApiService().whoAmI();
      final currentUsername = currentUser['username'] as String;
      if (mounted) {
        setState(() {
          _contacts = contacts
              .where((contact) => contact.username != currentUsername)
              .toList(growable: false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'לא ניתן לטעון אנשי קשר כרגע.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final contacts = _contacts
        .where((contact) =>
            query.isEmpty ||
            contact.username.toLowerCase().contains(query) ||
            contact.role.toLowerCase().contains(query))
        .toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.screenBackground,
        body: RefreshIndicator(
          onRefresh: _loadContacts,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 104),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'חיפוש לפי שם, תפקיד או אזור',
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF5A677D)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE7E8E2))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE7E8E2))),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('${contacts.length} אנשי קשר',
                        style: const TextStyle(
                            color: Color(0xFF16233A),
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 10),
                    if (_loading)
                      const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()))
                    else if (_error != null)
                      _ErrorState(message: _error!, onRetry: _loadContacts)
                    else if (contacts.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                              child: Text('לא נמצאו אנשי קשר',
                                  style: TextStyle(color: Color(0xFF5A677D)))))
                    else
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 5,
                        shadowColor: const Color(0x4016233A),
                        child: Column(children: [
                          for (var i = 0; i < contacts.length; i++)
                            _ContactRow(
                                contact: contacts[i],
                                isLast: i == contacts.length - 1)
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.isLast});
  final UserDetails contact;
  final bool isLast;
  @override
  Widget build(BuildContext context) {
    final active = contact.latitude != null && contact.longitude != null;
    final statusColor =
        active ? const Color(0xFF128A5E) : const Color(0xFF8A94A6);
    final isFirebaseUid =
        RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(contact.username);
    final name = contact.username.isEmpty || isFirebaseUid
        ? 'מתנדב/ת #${contact.id}'
        : contact.username;
    final initials = name.characters.first.toUpperCase();
    return Container(
      decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFE7E8E2)))),
      child: ListTile(
        minVerticalPadding: 4,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        leading: CircleAvatar(
            backgroundColor: const Color(0xFFE6F4EE),
            child: Icon(Icons.radio_outlined, color: statusColor)),
        title: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: Color(0xFF16233A), fontWeight: FontWeight.w700)),
        subtitle: Text(
            contact.role == 'emergency_dispatcher'
                ? 'מוקד כוננים'
                : contact.role == 'manager'
                    ? 'ניהול מבצעי'
                    : 'מתנדב/ת',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xFF5A677D))),
        trailing: SizedBox(
          height: 50,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFE6F4EE),
                child: Text(initials,
                    style: const TextStyle(
                        color: Color(0xFF0E6F4C),
                        fontWeight: FontWeight.bold))),
            const SizedBox(height: 1),
            Text(active ? 'זמין' : 'לא מחובר',
                style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    color: statusColor,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: () => onRetry(), child: const Text('ניסיון חוזר'))
      ]));
}
