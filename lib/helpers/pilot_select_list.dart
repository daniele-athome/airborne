
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'cupertinoplus.dart';

class PilotSelectList extends StatelessWidget {
  final List<String> pilotNames;
  final String? selectedName;
  final ImageProvider Function(String name) avatarProvider;
  final Function(String selected) onSelection;

  const PilotSelectList({
    Key? key,
    required this.pilotNames,
    required this.avatarProvider,
    required this.onSelection,
    this.selectedName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
      return ListView(
        children: [
          const SizedBox(height: kDefaultCupertinoFormTopBottomMargin),
          CupertinoFormSection(
            children: pilotNames.map((e) => CupertinoFormButtonRow(
              onPressed: () {
                onSelection(e);
              },
              child: CupertinoFormRowContainer(
                child: Row(
                  children: [
                    CircleAvatar(backgroundImage: avatarProvider(e)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(e, style: textStyle)),
                  ],
                ),
              ),
            )).toList(growable: false),
          ),
          const SizedBox(height: kDefaultCupertinoFormTopBottomMargin),
        ],
      );
    }
    else {
      return ListView(
        shrinkWrap: true,
        children: pilotNames.map((e) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(backgroundImage: avatarProvider(e)),
          title: Text(e),
          onTap: () {
            onSelection(e);
          },
        )).toList(growable: false),
      );
    }
  }
}
