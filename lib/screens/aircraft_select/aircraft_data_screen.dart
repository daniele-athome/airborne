import 'package:airborne/helpers/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:future_progress_dialog/future_progress_dialog.dart';
import 'package:provider/provider.dart';
import 'package:validators/validators.dart';

import '../../helpers/config.dart';

class SetAircraftDataScreen extends StatefulWidget {

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
      iosContentPadding: true,
      appBar: PlatformAppBar(
        // TODO i18n
        title: Text('Setup aircraft'),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Consumer<AppConfig>(
          builder: (context, appConfig, child) => _buildForm(context, appConfig),
        ),
      ),
    );
  }

  _showError(text) {
    showPlatformDialog(
      context: context,
      builder: (_context) => PlatformAlertDialog(
        // TODO i18n
        title: Text('Errore'),
        // TODO i18n
        content: Text(text),
        actions: <Widget>[
          PlatformDialogAction(
            // TODO i18n
            child: Text('OK'),
            onPressed: () {
              Navigator.pop(_context);
            },
          ),
        ],
      ),
    );
  }

  _downloadData() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      showPlatformDialog(
        context: context,
        builder: (context) => FutureProgressDialog(
          // TODO filename
          // TODO password
          downloadToFile(_aircraftUrl!, 'temp.zip').catchError((error, stacktrace) {
            print('DOWNLOAD ERROR');
            print(error);
            // TODO analyze exception somehow (e.g. TimeoutException)
            WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
              _showError(getExceptionMessage(error));
            });
          }),
          // TODO i18n
          message: const Text('Downloading...'),
        ),
      ).then((value) {
        if (value != null) {
          // TODO what now?
        }
      });
    }
  }

  _buildForm(BuildContext context, AppConfig appConfig) =>
    Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // TODO i18n
          Text('Please type in the address to the aircraft data and its password.',
            style: TextStyle(fontSize: 16)),
          SizedBox(
            height: 5,
          ),
          PlatformTextFormField(
            material: (context, platform) => MaterialTextFormFieldData(
              decoration: const InputDecoration(
                hintText: 'Aircraft data address',
              ),
            ),
            cupertino: (context, platform) => CupertinoTextFormFieldData(
            ),
            onSaved: (newValue) => _aircraftUrl = newValue,
            validator: (String? value) {
              if (value == null || value.isEmpty || !isURL(value, protocols: ['http', 'https'], requireProtocol: true)) {
                // TODO i18n
                return 'Please insert a valid address';
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
              decoration: const InputDecoration(
                hintText: 'Password',
              ),
            ),
            cupertino: (context, platform) => CupertinoTextFormFieldData(
            ),
          ),
          SizedBox(
            height: 10,
          ),
          PlatformButton(
            // TODO i18n
            child: Text('Install'),
            onPressed: _downloadData,
            //cupertinoFilled: (_, __) => CupertinoFilledButtonData(),
          ),
        ],
      )
    );


}
