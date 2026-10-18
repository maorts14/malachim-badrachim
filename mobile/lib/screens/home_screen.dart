import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rescue_app/managers/storage_manager.dart';
import 'package:rescue_app/repositories/location_repository.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'event_tab_screen.dart';
import 'about_screen.dart';
import 'map_tab_screen.dart';
import 'ptt_tab_screen.dart';
import 'settings_screen.dart';
import 'user_details_screen.dart';
import 'users_tab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    LocationRepository().startTracking();
  }

  @override
  void dispose() {
    LocationRepository().stopTracking();
    super.dispose();
  }

  static const List<String> _titles = <String>[
    'אירועים פעילים',
    'מפה',
    'קשר',
    'אנשי קשר',
    'הגדרות',
  ];

  static const List<Widget> _screens = <Widget>[
    EventTabScreen(),
    MapTabScreen(),
    PttTabScreen(),
    UsersTabScreen(),
    SettingsScreen(),
  ];

  // @override
  // void initState() {
  //   super.initState();
  //   testApi();
  // }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F4),
        body: Column(
          children: [
            _FigmaHeader(
              title: _titles[_selectedIndex],
              onProfilePressed: () => _showQuickActions(context),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _FigmaBottomNavigation(
          selectedIndex: _selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('פרטי משתמש'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UserDetailsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('אודות'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFD43A2F)),
                title: const Text('התנתקות', style: TextStyle(color: Color(0xFFD43A2F))),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutAlert(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutAlert(BuildContext context) {
    Alert(
      context: context,
      title: 'logout',
      desc: 'are you sure you wish to logout',
      buttons: [
        DialogButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            await StorageManager.instance.logout();
            // if (context.mounted) {
            //   Navigator.pop(context);
            // }
          },
          child: const Text(
            'OK',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
        DialogButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          color: Colors.grey,
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ],
    ).show();
  }

}

class _FigmaHeader extends StatelessWidget {
  const _FigmaHeader({required this.title, required this.onProfilePressed});

  final String title;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16233A),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 116,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              children: [
                SizedBox(
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: onProfilePressed,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: SvgPicture.asset('assets/images/figma/figma_icon_10.svg', width: 20, height: 20),
                        ),
                      ),
                      Image.asset('assets/images/figma/raw_image_2.png', width: 81, height: 60, fit: BoxFit.contain),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 23, height: 1.35)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaBottomNavigation extends StatelessWidget {
  const _FigmaBottomNavigation({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({String label, String asset})>[
    (label: 'אירועים', asset: 'assets/images/figma/figma_icon_12.svg'),
    (label: 'מפה', asset: 'assets/images/figma/figma_icon_9.svg'),
    (label: 'קשר', asset: 'assets/images/figma/figma_icon_11.svg'),
    (label: 'אנשי קשר', asset: 'assets/images/figma/figma_icon_2.svg'),
    (label: 'הגדרות', asset: 'assets/images/figma/figma_icon_7.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFF16233A),
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _items.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                child: _NavItem(item: _items[index], selected: index == selectedIndex),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item, required this.selected});

  final ({String label, String asset}) item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (selected) Container(width: 36, height: 3, decoration: BoxDecoration(color: const Color(0xFF128A5E), borderRadius: BorderRadius.circular(8))),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(item.asset, width: 23, height: 23),
                const SizedBox(height: 4),
                Text(item.label, style: TextStyle(color: selected ? Colors.white : const Color(0x8CFFFFFF), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
