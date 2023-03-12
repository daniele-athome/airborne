
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';

// TODO import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/utils.dart';
import '../../services/activities_services.dart';
import 'activities_list.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({Key? key}) : super(key: key);

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {

  late ActivitiesListController _activitiesController;
  // TODO late AppConfig _appConfig;
  late ActivitiesService _activitiesService;

  @override
  void initState() {
    super.initState();
    _activitiesController = ActivitiesListController();
  }

  @override
  void didChangeDependencies() {
    // TODO _appConfig = Provider.of<AppConfig>(context, listen: false);
    _activitiesService = Provider.of<ActivitiesService>(context, listen: false);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      iosContentPadding: true,
      // TODO add button on iOS, FAB on Android
      appBar: PlatformAppBar(
        title: Text(AppLocalizations.of(context)!.activities_title),
        automaticallyImplyLeading: false,
        material: (context, platform) => MaterialAppBarData(
          toolbarHeight: MediaQuery.of(context).orientation == Orientation.portrait ?
          kPortraitToolbarHeight : kLandscapeToolbarHeight,
        ),
      ),
      cupertino: (context, platform) => CupertinoPageScaffoldData(
        backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ActivitiesList(
          controller: _activitiesController,
          activitiesService: _activitiesService,
        ),
      ),
    );
  }

}
