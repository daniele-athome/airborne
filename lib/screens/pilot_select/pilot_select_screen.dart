
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/pilot_select_list.dart';
import '../../helpers/utils.dart';

class PilotSelectScreen extends StatelessWidget {
  const PilotSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: Text(AppLocalizations.of(context)!.pilotSelect_title),
        automaticallyImplyLeading: false,
        material: (context, platform) => MaterialAppBarData(
          toolbarHeight: MediaQuery.of(context).orientation == Orientation.portrait ?
            kPortraitToolbarHeight : kLandscapeToolbarHeight,
        ),
      ),
      cupertino: (context, platform) => CupertinoPageScaffoldData(
        backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
      ),
      body: Consumer<AppConfig>(
        builder: (context, appConfig, child) => PilotSelectList(
          pilotNames: appConfig.pilotNames,
          avatarProvider: (name) => appConfig.getPilotAvatar(name),
          onSelection: (selected) => _choosePilot(context, appConfig, selected),
        ),
      ),
    );
  }

  void _confirmPilot(BuildContext context, AppConfig appConfig, String name) {
    appConfig.pilotName = name;
    Navigator.of(context, rootNavigator: true).pushReplacementNamed('/');
  }

  void _choosePilot(BuildContext context, AppConfig appConfig, String name) {
    showPlatformDialog(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: Text(AppLocalizations.of(context)!.pilotSelect_confirm_title),
        // TODO name should be bold
        content: Text(AppLocalizations.of(context)!.pilotSelect_confirm_message(name)),
        actions: <Widget>[
          PlatformDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.dialog_button_cancel),
          ),
          PlatformDialogAction(
            onPressed: () {
              Navigator.pop(dialogContext);
              _confirmPilot(context, appConfig, name);
            },
            child: Text(AppLocalizations.of(context)!.dialog_button_ok),
          ),
        ],
      ),
    );
  }

}
