import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:validators/validators.dart';

import '../../helpers/aircraft_data.dart';
import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/future_progress_dialog.dart';
import '../../helpers/utils.dart';

final Logger _log = Logger((AircraftData).toString());

class SetAircraftDataScreen extends StatefulWidget {
  const SetAircraftDataScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SetAircraftDataScreenState();

}

class _SetAircraftDataScreenState extends State<SetAircraftDataScreen> {

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _aircraftUrl;
  String? _aircraftPassword;

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      // because we have a listview adding its own padding...
      iosContentPadding: false,
      appBar: PlatformAppBar(
        title: Text(AppLocalizations.of(context)!.addAircraft_title),
        trailingActions: isCupertino(context)? <Widget>[
          Consumer2<AppConfig, DownloadProvider>(
            builder: (context, appConfig, downloadProvider, child) => PlatformTextButton(
              widgetKey: const Key('aircraft_data_button_install'),
              onPressed: () => _downloadData(context, appConfig, downloadProvider),
              cupertino: (_, __) => CupertinoTextButtonData(
                // workaround for https://github.com/flutter/flutter/issues/32701
                padding: EdgeInsets.zero,
              ),
              child: Text(AppLocalizations.of(context)!.addAircraft_button_install),
            ),
          )
        ]: [],
        material: (context, platform) => MaterialAppBarData(
          toolbarHeight: MediaQuery.of(context).orientation == Orientation.portrait ?
            kPortraitToolbarHeight : kLandscapeToolbarHeight,
        ),
      ),
      cupertino: (context, platform) => CupertinoPageScaffoldData(
        backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
      ),
      body: Consumer<AppConfig>(
        builder: (context, appConfig, child) => _buildForm(context, appConfig),
      ),
    );
  }

  // FIXME this code is similar to the one in about_screen.dart
  void _downloadData(BuildContext context, AppConfig appConfig, DownloadProvider downloadProvider) {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final userpass = _aircraftPassword;
      String? username;
      String? password;
      if (userpass != null) {
        final separator = userpass.indexOf(':');
        if (separator >= 0) {
          username = userpass.substring(0, separator);
          password = userpass.substring(separator + 1);
        }
      }
      final downloadTask = downloadProvider.downloadToFile(_aircraftUrl!, 'aircraft.zip', username, password, true)
        .timeout(kNetworkRequestTimeout)
        .then((tempfile) async {
          _log.finest(tempfile);
          final stored = await _validateAndStoreAircraft(tempfile, _aircraftUrl!, appConfig);
          tempfile.deleteSync();
          return stored;
        }).then((AircraftData? aircraftData) {
          if (aircraftData != null) {
            appConfig.currentAircraft = aircraftData;
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
          // FIXME this should be handled with a simple rebuild by MyApp but it doesn't work
          // probably FutureProgressDialog popping the navigator has something to do with it
          WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
            Navigator.of(context, rootNavigator: true)
                .pushReplacementNamed(appConfig.pilotName != null ? '/' : 'pilot-select');
          });
        }
      });
    }
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

  List<Widget> _buildFormSections(BuildContext context, AppConfig appConfig) =>
      <Widget>[
        if (!isCupertino(context)) Text(AppLocalizations.of(context)!.addAircraft_text1,
            style: const TextStyle(fontSize: 16)),
        if (!isCupertino(context)) const SizedBox(
          height: 5,
        ),
        PlatformTextFormField(
          keyboardType: TextInputType.url,
          material: (context, platform) => MaterialTextFormFieldData(
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.addAircraft_hint_address,
            ),
          ),
          cupertino: (context, platform) => CupertinoTextFormFieldData(
            prefix: Text(AppLocalizations.of(context)!.addAircraft_label_address),
            placeholder: AppLocalizations.of(context)!.addAircraft_hint_address,
            padding: const EdgeInsetsDirectional.fromSTEB(20.0, 6.0, 6.0, 6.0),
          ),
          onSaved: (newValue) => _aircraftUrl = newValue,
          validator: (String? value) {
            if (value == null || value.isEmpty || !isURL(value, protocols: ['http', 'https'], requireProtocol: true)) {
              return AppLocalizations.of(context)!.addAircraft_error_invalid_address;
            }
            return null;
          },
        ),
        PlatformTextFormField(
          obscureText: true,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          onSaved: (newValue) => _aircraftPassword = newValue,
          material: (context, platform) => MaterialTextFormFieldData(
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.addAircraft_hint_password,
            ),
          ),
          cupertino: (context, platform) => CupertinoTextFormFieldData(
            prefix: Text(AppLocalizations.of(context)!.addAircraft_hint_password),
            placeholder: AppLocalizations.of(context)!.addAircraft_hint_password,
            padding: const EdgeInsetsDirectional.fromSTEB(20.0, 6.0, 6.0, 6.0),
          ),
        ),
        if (!isCupertino(context)) const SizedBox(
          height: 10,
        ),
        if (!isCupertino(context)) Consumer<DownloadProvider>(
          builder: (context, downloadProvider, child) => PlatformElevatedButton(
            widgetKey: const Key('aircraft_data_button_install'),
            onPressed: () => _downloadData(context, appConfig, downloadProvider),
            child: Text(AppLocalizations.of(context)!.addAircraft_button_install),
          ),
        ),
      ];

  Widget _buildMaterialForm(BuildContext context, AppConfig appConfig) =>
    ListView(
      padding: const EdgeInsets.all(20),
      children: _buildFormSections(context, appConfig)
    );

  Widget _buildCupertinoForm(BuildContext context, AppConfig appConfig) =>
    ListView(
      children: [
        CupertinoFormSection(
          header: Text(AppLocalizations.of(context)!.addAircraft_text1,
            // FIXME workaround for https://github.com/flutter/flutter/issues/48438
            // FIXME background color is not consistent with scaffold background color (of course)
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 18)
          ),
          children: _buildFormSections(context, appConfig),
        ),
      ],
    );

  Widget _buildForm(BuildContext context, AppConfig appConfig) =>
    Form(
      key: _formKey,
      child: isCupertino(context) ?
        _buildCupertinoForm(context, appConfig) :
        _buildMaterialForm(context, appConfig)
    );

}
