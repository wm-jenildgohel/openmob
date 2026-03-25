import 'package:flutter/material.dart';
import '../../core/res_colors.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      backgroundColor: ResColors.sidebar,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: IconThemeData(color: ResColors.accent),
      indicatorColor: ResColors.sidebarActive,
      leading: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'OpenMob',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ResColors.accent,
          ),
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.devices),
          label: Text('Devices'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.article),
          label: Text('Logs'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.science),
          label: Text('Testing'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text('System'),
        ),
      ],
    );
  }
}
