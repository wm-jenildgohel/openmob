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

  static const _items = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.phone_android_rounded, 'Devices'),
    _NavItem(Icons.terminal_rounded, 'Logs'),
    _NavItem(Icons.bug_report_rounded, 'Testing'),
    _NavItem(Icons.tune_rounded, 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: const BoxDecoration(
        color: ResColors.sidebar,
        border: Border(
          right: BorderSide(color: ResColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ResColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: ResColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'OpenMob',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: ResColors.accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(indent: 16, endIndent: 16),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _SidebarButton(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    onTap: () => onDestinationSelected(index),
                  ),
                );
              },
            ),
          ),
          // Version badge at bottom
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                fontSize: 10,
                color: ResColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _SidebarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<_SidebarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? ResColors.sidebarActive
        : _hovering
            ? ResColors.bgSurface.withValues(alpha: 0.5)
            : Colors.transparent;

    final iconColor = widget.isSelected
        ? ResColors.sidebarIconActive
        : _hovering
            ? ResColors.textSecondary
            : ResColors.sidebarIcon;

    final textColor = widget.isSelected
        ? ResColors.textPrimary
        : ResColors.textMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: widget.isSelected
                ? Border.all(color: ResColors.accent.withValues(alpha: 0.2))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 20, color: iconColor),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
