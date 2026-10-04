import 'package:flutter/material.dart';
import '../atoms/app-divider.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(top: 24, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          const AppDivider(),
        ],
      ),
    );
  }
}
