import 'package:flutter/material.dart';

/// 勾选为严格解析，未勾选为宽容（允许尾逗号）。
class JsonStrictCheckbox extends StatelessWidget {
  const JsonStrictCheckbox({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            onChanged: onChanged == null ? null : (next) => onChanged!(next ?? false),
          ),
          const Text('严格'),
        ],
      ),
    );
  }
}
