import 'dart:async';
import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../helpers/aircraft_data.dart';
import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/future_progress_dialog.dart';
import '../../helpers/utils.dart';
import '../../pubspec.yaml.g.dart' as pubspec;

final Logger _log = Logger((AboutScreen).toString());

// TODO convert to stateless widget if using only AppConfig
class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late AppConfig _appConfig;
  late DownloadProvider _downloadProvider;

  @override
  void didChangeDependencies() {
    _appConfig = Provider.of<AppConfig>(context, listen: false);
    _downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
    super.didChangeDependencies();
  }

  // FIXME this code is similar to the one in aircraft_data_screen.dart
  void _onRefresh(BuildContext context) {
    showTextInputDialog(
      context: context,
      textFields: [
        DialogTextField(
          hintText: AppLocalizations.of(context)!.addAircraft_hint_password,
          keyboardType: TextInputType.visiblePassword,
          obscureText: true,
        ),
      ],
      title: AppLocalizations.of(context)!.about_update_password_title,
      message: AppLocalizations.of(context)!.about_update_password_message,
    ).then((value) {
      if (value != null) {
        final userpass = value[0];
        String? username;
        String? password;
        if (userpass.isNotEmpty) {
          final separator = userpass.indexOf(':');
          if (separator >= 0) {
            username = userpass.substring(0, separator);
            password = userpass.substring(separator + 1);
          }
        }
        final downloadTask = _downloadProvider.downloadToFile(_appConfig.currentAircraft!.url!, 'aircraft.zip', username, password, true)
            .timeout(kNetworkRequestTimeout)
            .then((tempfile) async {
          _log.finest(tempfile);
          final stored = await _validateAndStoreAircraft(tempfile, _appConfig.currentAircraft!.url!, _appConfig);
          tempfile.deleteSync();
          return stored;
        }).then((AircraftData? aircraftData) {
          if (aircraftData != null) {
            _appConfig.currentAircraft = aircraftData;
          }
          return aircraftData;
        }).catchError((error, StackTrace? stacktrace) {
          _log.info('DOWNLOAD ERROR', error, stacktrace);
          // TODO specialize exceptions (e.g. network errors, others...)
          final String message;
          if (error is TimeoutException) {
            message = AppLocalizations.of(context)!.error_generic_network_timeout;
          }
          else {
            message = getExceptionMessage(error);
          }

          Future.delayed(Duration.zero, () => showError(context, message));
          return null;
        });

        showPlatformDialog(
          context: context,
          builder: (context) {
            return FutureProgressDialog(downloadTask,
              message: isCupertino(context) ? null :
              Text(AppLocalizations.of(context)!.addAircraft_dialog_downloading),
            );
          },
        ).then((value) async {
          if (value != null) {
            // TODO maybe notify the user (e.g. toast)?
          }
        });
      }
    });
  }

  Future<AircraftData?> _validateAndStoreAircraft(File file, String url, AppConfig appConfig) async {
    final reader = AircraftDataReader(dataFile: file, urlFile: null);
    final validation = await reader.validate();
    _log.finest('VALIDATION: $validation');
    if (validation) {
      try {
        final dataFile = await addAircraftDataFile(reader, url);
        _log.finest(dataFile);
        await deleteAircraftCache();
        await reader.open();
        final aircraftData = reader.toAircraftData();
        appConfig.addAircraft(aircraftData);
        return aircraftData;
      }
      catch (e, stacktrace) {
        _log.warning('Error storing aircraft data file', e, stacktrace);
        if (mounted) {
          return Future.error(Exception(AppLocalizations.of(context)!.addAircraft_error_storing), stacktrace);
        }
      }
    }
    else {
      if (mounted) {
        return Future.error(Exception(AppLocalizations.of(context)!.addAircraft_error_invalid_datafile));
      }
    }
    return null;
  }

  void _onLogout(BuildContext context) {
    showConfirm(
      context: context,
      title: AppLocalizations.of(context)!.about_disconnect_confirm_title,
      text: AppLocalizations.of(context)!.about_disconnect_confirm_message,
      destructiveOk: true,
      okCallback: () {
        _appConfig.pilotName = null;
        _appConfig.currentAircraft = null;
        Navigator.of(context, rootNavigator: true).popAndPushNamed('aircraft-data');
      },
    );
  }

  List<Widget> _buildCupertinoItems(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return [
      CupertinoFormSection(
        header: Text(AppLocalizations.of(context)!.about_aircraft_info.toUpperCase()),
        children: [
          CupertinoFormRowContainer(
            child: CupertinoFormRow(
              padding: kDefaultCupertinoFormRowPadding,
              prefix: Text(AppLocalizations.of(context)!.about_aircraft_callsign),
              child: Text(_appConfig.currentAircraft!.callSign,
                style: textStyle.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          CupertinoFormButtonRow(
            onPressed: () => openUrl(context, _appConfig.locationUrl),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.about_aircraft_hangar),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(_appConfig.locationName, style: textStyle),
                const SizedBox(width: 2),
                Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
              ],
            ),
          ),
        ],
      ),
      CupertinoFormSection(
        header: Text(AppLocalizations.of(context)!.about_aircraft_pilots.toUpperCase()),
        children: [
          ..._appConfig.pilotNames.map((e) => CupertinoFormRowContainer(
            child: Padding(
              padding: kDefaultCupertinoFormRowPadding,
              child: Row(
                children: [
                  CircleAvatar(foregroundImage: _appConfig.getPilotAvatar(e)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(e, style: textStyle)),
                ],
              ),
            ),
          )),
        ],
      ),
      CupertinoFormSection(
        header: Text(AppLocalizations.of(context)!.appName.toUpperCase()),
        children: [
          CupertinoFormRowContainer(
            child: CupertinoFormRow(
              padding: kDefaultCupertinoFormRowPadding,
              prefix: Text(AppLocalizations.of(context)!.about_app_version),
              child: FutureBuilder(
                future: PackageInfo.fromPlatform(),
                initialData: null,
                builder: (context, AsyncSnapshot<PackageInfo?> snapshot) => Text(
                  snapshot.connectionState == ConnectionState.done ?
                  '${AppLocalizations.of(context)!.appName} ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                      : '',
                  style: textStyle
                ),
              ),
            ),
          ),
          CupertinoFormButtonRow(
            onPressed: () => openUrl(context, pubspec.homepage),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.about_app_homepage),
            child: Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ),
          CupertinoFormButtonRow(
            onPressed: () => openUrl(context, pubspec.issueTracker),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(AppLocalizations.of(context)!.about_app_issues),
            child: Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ),
        ],
      ),
      const SizedBox(height: kDefaultCupertinoFormSectionMargin),
      CupertinoFormSection(children: <Widget>[
        if (_appConfig.currentAircraft!.url != null) Row(
          children: [
            Expanded(
              child: CupertinoButton(
                onPressed: () => _onRefresh(context),
                child: Text(AppLocalizations.of(context)!.about_app_update_aircraft,
                  style: const TextStyle(color: CupertinoColors.activeBlue),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                key: const Key('about_button_disconnect_aircraft'),
                onPressed: () => _onLogout(context),
                child: Text(AppLocalizations.of(context)!.about_app_disconnect_aircraft,
                  style: const TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            ),
          ],
        )
      ]),
    ];
  }

  List<Widget> _buildMaterialItems(BuildContext context) => [
    HeaderListTile(AppLocalizations.of(context)!.about_aircraft_info, first: true),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      subtitle: Text(AppLocalizations.of(context)!.about_aircraft_callsign),
      title: Text(_appConfig.currentAircraft!.callSign,
        style: Theme.of(context).textTheme.headline6!.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      subtitle: Text(AppLocalizations.of(context)!.about_aircraft_hangar),
      title: Text(_appConfig.locationName,
        style: Theme.of(context).textTheme.headline6,
      ),
      trailing: IconButton(
        onPressed: () => openUrl(context, _appConfig.locationUrl),
        tooltip: AppLocalizations.of(context)!.about_aircraft_hangar_open_maps,
        icon: const Icon(Icons.open_in_new),
      ),
    ),
    HeaderListTile(AppLocalizations.of(context)!.about_aircraft_pilots),
    ..._appConfig.pilotNames.map((e) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: CircleAvatar(foregroundImage: _appConfig.getPilotAvatar(e)),
      title: Text(e),
    )).toList(growable: false),
    HeaderListTile(AppLocalizations.of(context)!.appName),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: const SizedBox(
        height: double.infinity,
        child: Icon(Icons.info),
      ),
      subtitle: Text(AppLocalizations.of(context)!.about_app_version),
      title: FutureBuilder(
        future: PackageInfo.fromPlatform(),
        initialData: null,
        builder: (context, AsyncSnapshot<PackageInfo?> snapshot) => Text(
          snapshot.connectionState == ConnectionState.done ?
          '${AppLocalizations.of(context)!.appName} ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
              : '',
        ),
      ),
    ),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: const SizedBox(
        height: double.infinity,
        child: Icon(Icons.all_inclusive),
      ),
      title: Text(AppLocalizations.of(context)!.about_app_homepage),
      subtitle: Text(AppLocalizations.of(context)!.about_app_homepage_subtitle),
      onTap: () => openUrl(context, pubspec.homepage),
    ),
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: const SizedBox(
        height: double.infinity,
        child: Icon(Icons.bug_report, color: Colors.red),
      ),
      title: Text(AppLocalizations.of(context)!.about_app_issues),
      subtitle: Text(AppLocalizations.of(context)!.about_app_issues_subtitle),
      onTap: () => openUrl(context, pubspec.issueTracker),
    ),
    if (_appConfig.currentAircraft!.url != null) ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: SizedBox(
        height: double.infinity,
        child: Icon(Icons.update, color: Colors.blue.shade600),
      ),
      title: Text(AppLocalizations.of(context)!.about_app_update_aircraft),
      subtitle: Text(AppLocalizations.of(context)!.about_app_update_aircraft_subtitle),
      onTap: () => _onRefresh(context),
    ),
    ListTile(
      key: const Key('about_button_disconnect_aircraft'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: SizedBox(
        height: double.infinity,
        child: Icon(Icons.logout, color: Colors.blue.shade600),
      ),
      title: Text(AppLocalizations.of(context)!.about_app_disconnect_aircraft),
      subtitle: Text(AppLocalizations.of(context)!.about_app_disconnect_aircraft_subtitle),
      onTap: () => _onLogout(context),
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    final list = ListView(
      children: [
        Stack(
          children: [
            Positioned(
              // TODO not very good sizing and loading indicator
              child: Image(
                image: _appConfig.aircraftPicture,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) {
                    return child;
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 250),
                      child: AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        child: child,
                      ),
                    ),
                  );
                },
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                  return loadingProgress != null ?
                  Container(
                    height: 250,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator.adaptive(),
                  ) :
                  child;
                },
              ),
            ),
            Positioned.fill(
              bottom: -10,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 30.0,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
                    // TODO is this the right color? I'm getting confused...
                    color: isCupertino(context) ? CupertinoColors.systemGroupedBackground.resolveFrom(context) :
                    Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        offset: Offset(0.0, -1.0),
                        blurRadius: 5.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ...isCupertino(context) ?
        _buildCupertinoItems(context) :
        _buildMaterialItems(context),
      ],
    );
    return isCupertino(context) ?
      Container(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: list,
      ) :
      Ink(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: list,
      );
  }
}

class HeaderListTile extends StatelessWidget {

  const HeaderListTile(this.text, {
    Key? key,
    this.first = false,
  }) : super(key: key);

  /// The text to be displayed.
  final String text;
  /// True if this is the first header of the list.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: first ? const EdgeInsets.fromLTRB(20, 0, 20, 10) : const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(text, style: Theme.of(context).textTheme.headline5),
    );
  }

}
