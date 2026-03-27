import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/res_colors.dart';
import '../../main.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compact = false,
  });

  static final _items = [
    _NavItem(Iconsax.category_2, 'Dashboard'),
    _NavItem(Iconsax.mobile, 'Devices'),
    _NavItem(Iconsax.document_text, 'Logs'),
    _NavItem(Iconsax.task_square, 'Testing'),
    _NavItem(Iconsax.setting_2, 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: compact ? 64 : 84,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/openmob.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          if (!compact) ...[
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
          ],
          SizedBox(height: compact ? 16 : 24),
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
                  padding: const EdgeInsets.only(bottom: 8),
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
          // Version badge at bottom — reads from UpdateService
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'v${updateService.currentVersion}',
              style: const TextStyle(
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
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
              Icon(widget.icon, size: 22, color: iconColor),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w400,
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
