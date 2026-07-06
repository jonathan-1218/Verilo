import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class CopperButton extends StatelessWidget {
  const CopperButton({super.key, required this.label, required this.onTap, this.fullWidth = true});
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.copperMid,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x4DB87040), blurRadius: 16, offset: Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: Text(label, style: AppText.spaceGrotesk(size: 15, weight: FontWeight.w700, color: Colors.white)),
        ),
      );
}

class VeriloLogo extends StatelessWidget {
  const VeriloLogo({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(children: [
          TextSpan(text: 'veri', style: AppText.spaceGrotesk(size: size, weight: FontWeight.w700, color: AppColors.copperGlow, letterSpacing: -0.5)),
          TextSpan(text: 'lo', style: AppText.spaceGrotesk(size: size, weight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5)),
        ]),
      );
}

class CardSurface extends StatelessWidget {
  const CardSurface({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.elevated = false});
  final Widget child;
  final EdgeInsets padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: elevated ? AppColors.bgCardElevated : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: child,
      );
}

class CopperProgressBar extends StatelessWidget {
  const CopperProgressBar({super.key, required this.value, this.height = 5});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: AppColors.bgPlaceholder,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.copperGradient),
            ),
          ),
        ),
      );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.maxLines = 1,
    this.icon,
    this.keyboardType,
    this.onChanged,
  });
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final int maxLines;
  final IconData? icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.label),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: maxLines,
                    keyboardType: keyboardType,
                    onChanged: onChanged,
                    // ponytail: these are short form fields (names, phone
                    // numbers, codes), not note-taking — stylus-to-text
                    // conversion has no upside here and its first-run OS
                    // prompt is a confusing dead end mid-form
                    stylusHandwritingEnabled: false,
                    style: AppText.spaceGrotesk(size: 14),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: AppText.spaceGrotesk(size: 14, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                if (icon != null) Icon(icon, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ],
      );
}

class HatchedBox extends StatelessWidget {
  const HatchedBox({super.key, required this.height, this.child});
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.bgPlaceholder,
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.color = AppColors.copperMid, this.bg});
  final String label;
  final Color color;
  final Color? bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg ?? color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: AppText.spaceGrotesk(size: 9, weight: FontWeight.w600, color: color)),
      );
}

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.folder_outlined, Icons.folder, 'Projects'),
    (Icons.map_outlined, Icons.map, 'Map'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        color: AppColors.navBar,
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == currentIndex;
            final (outlineIcon, filledIcon, label) = _items[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (active)
                      Container(
                        width: 24, height: 2.5,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: AppColors.copperMid,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    Icon(active ? filledIcon : outlineIcon,
                        size: 20, color: active ? AppColors.copperMid : AppColors.textMuted),
                    const SizedBox(height: 2),
                    Text(label, style: AppText.spaceGrotesk(size: 9, color: active ? AppColors.copperMid : AppColors.textMuted)),
                  ],
                ),
              ),
            );
          }),
        ),
      );
}
