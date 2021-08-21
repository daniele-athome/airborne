
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';

class PilotSelectScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
        appBar: PlatformAppBar(
          // TODO i18n
          title: const Text('Chi sei?'),
          automaticallyImplyLeading: false,
        ),
        body: Container(
          child: Consumer<AppConfig>(
              builder: (context, appConfig, child) => ListView(
                    children: appConfig
                        .pilotNames
                        .map((name) => Material(child: ListTile(
                          leading: CircleAvatar(backgroundImage: appConfig.getPilotAvatar(name)),
                          title: Text(name),
                          onTap: () {
                            _choosePilot(context, appConfig, name);
                          },
                        ))).toList(growable: false),
                  )),
        ));
  }

  void _confirmPilot(BuildContext context, AppConfig appConfig, String name) {
    appConfig.pilotName = name;
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/');
  }

  void _choosePilot(BuildContext context, AppConfig appConfig, String name) {
    showPlatformDialog(
      context: context,
      builder: (_context) => PlatformAlertDialog(
        // TODO i18n
        title: Text('Confermi?'),
        // TODO i18n
        // TODO name should be bold
        content: Text('Dici di essere ' + name + '.'),
        actions: <Widget>[
          PlatformDialogAction(
            onPressed: () => Navigator.pop(_context),
            child: Text(AppLocalizations.of(context)!.dialog_button_cancel),
          ),
          PlatformDialogAction(
            onPressed: () {
              Navigator.pop(_context);
              _confirmPilot(context, appConfig, name);
            },
            child: Text(AppLocalizations.of(context)!.dialog_button_ok),
          ),
        ],
      ),
    );
  }

}
