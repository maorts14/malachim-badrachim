import 'package:flutter/material.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  Map<String, dynamic>? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await RestApiService().getCurrentUserProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('פרטי משתמש')),
      body: profile == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : const Text('לא ניתן לטעון את הפרופיל כרגע.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('פרופיל מתנדב',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                _ProfileTile(
                    icon: Icons.person_outline,
                    label: 'שם',
                    value: profile['display_name'] as String? ?? ''),
                _ProfileTile(
                    icon: Icons.email_outlined,
                    label: 'אימייל',
                    value: profile['email'] as String? ?? ''),
                _ProfileTile(
                    icon: Icons.phone_outlined,
                    label: 'טלפון',
                    value: profile['phone'] as String? ?? ''),
                _ProfileTile(
                    icon: Icons.badge_outlined,
                    label: 'תפקיד',
                    value: profile['role'] as String? ?? ''),
              ],
            ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            subtitle: Text(value.isEmpty ? 'לא הוגדר' : value)),
      );
}
