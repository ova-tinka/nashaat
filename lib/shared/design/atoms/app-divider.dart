import 'package:flutter/material.dart';

class AppDivider extends StatelessWidget {
  final double indent;
  const AppDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor,
      indent: indent,
    );
  }
}

class AppVerticalDivider extends StatelessWidget {
  const AppVerticalDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: double.infinity,
      child: ColoredBox(color: Theme.of(context).dividerColor),
    );
  }
}
