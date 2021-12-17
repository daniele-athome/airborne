
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
        padding: kDefaultCupertinoFormMargin,
        children: [
          CupertinoFormSection(
            children: pilotNames.map((e) => CupertinoFormButtonRow(
              key: Key('pilot_select_list:' + e),
              onPressed: () {
                onSelection(e);
              },
              child: Row(
                children: [
                  CircleAvatar(foregroundImage: avatarProvider(e)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(e, style: textStyle)),
                ],
              ),
            )).toList(growable: false),
          ),
        ],
      );
    }
    else {
      return ListView(
        shrinkWrap: true,
        children: pilotNames.map((e) => ListTile(
          key: Key('pilot_select_list:' + e),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(foregroundImage: avatarProvider(e)),
          title: Text(e),
          onTap: () {
            onSelection(e);
          },
        )).toList(growable: false),
      );
    }
  }
}
