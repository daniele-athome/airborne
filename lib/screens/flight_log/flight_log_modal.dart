
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/digit_display.dart';
import '../../helpers/pilot_select_list.dart';
import '../../helpers/utils.dart';
import '../../models/flight_log_models.dart';
import '../../services/flight_log_services.dart';

final Logger _log = Logger((FlightLogItem).toString());

class FlightLogModal extends StatefulWidget {

  const FlightLogModal(this.item, {
    Key? key
  }) : super(key: key);

  final FlightLogItem item;

  @override
  State<FlightLogModal> createState() => _FlightLogModalState();

}

class _FlightLogModalState extends State<FlightLogModal> {
  static final _fuelPriceFormatter = NumberFormat("#####.00");

  // event data
  late String _pilotName;
  @Deprecated('Use _dateController')
  late DateTime _date;
  late num? _fuelPrice;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DigitDisplayController _startHourController;
  late DigitDisplayController _endHourController;
  late TextEditingController _originController;
  late TextEditingController _destinationController;
  late DateTimePickerController _dateController;
  late TextEditingController _fuelController;
  late TextEditingController _notesController;

  late FlightLogBookService _service;
  late AppConfig _appConfig;

  bool get _isEditing => widget.item.id != null;

  @override
  void initState() {
    _pilotName = widget.item.pilotName;
    _originController = TextEditingController(text: widget.item.origin);
    _destinationController = TextEditingController(text: widget.item.destination);
    _startHourController = DigitDisplayController(widget.item.startHour);
    _endHourController = DigitDisplayController(widget.item.endHour);
    _fuelController = TextEditingController(text: widget.item.fuel != null ? widget.item.fuel.toString() : '');
    _notesController = TextEditingController(text: widget.item.notes);
    _dateController = DateTimePickerController(widget.item.date);
    _date = widget.item.date;
    _fuelPrice = widget.item.fuelPrice;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _service = Provider.of<FlightLogBookService>(context);
    _appConfig = Provider.of<AppConfig>(context);
    _fuelPrice ??= _appConfig.fuelPrices?.keys.first;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _startHourController.dispose();
    _endHourController.dispose();
    _fuelController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onDateChanged(DateTime? date, bool time) {
    if (date != null && date != _date) {
      setState(() {
        _date = date;
      });
    }
  }

  Widget _buildCupertinoForm(BuildContext context, AppConfig appConfig) {
    // FIXME workaround https://github.com/flutter/flutter/issues/48438
    final TextStyle textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return ListView(
      padding: kDefaultCupertinoFormMargin,
      children: [
        CupertinoFormSection(children: <Widget>[
          CupertinoFormButtonRow(
            onPressed: () => _onTapPilot(context),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(
              AppLocalizations.of(context)!.bookFlightModal_label_pilot,
              style: textStyle.copyWith(
                fontSize: 20,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _pilotName,
                  style: textStyle.copyWith(
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 14),
                CircleAvatar(foregroundImage: appConfig.getPilotAvatar(_pilotName)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        CupertinoFormSection(children: <Widget>[
          // start date/time
          CupertinoDateTimeFormFieldRow(
            prefix: Text(AppLocalizations.of(context)!.bookFlightModal_label_start),
            doneButtonText: AppLocalizations.of(context)!.dialog_button_done,
            onChanged: (value) => _onDateChanged(value, true),
            controller: _dateController,
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        CupertinoFormSection(children: <Widget>[
          CupertinoTextFormFieldRow(
            // FIXME doesn't work because TextFormFieldRow can't pass padding to the text field -- padding: kDefaultCupertinoFormRowPadding,
            controller: _notesController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 3,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400
            ),
            placeholder: AppLocalizations.of(context)!.bookFlightModal_hint_notes,
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        CupertinoFormSection(children: <Widget>[
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: () => _onDelete(context),
                  child: Text(AppLocalizations.of(context)!.bookFlightModal_button_delete,
                    style: const TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                ),
              ),
            ],
          )
        ]),
      ],
    );
  }

  Widget _buildMaterialForm(BuildContext context) {
    final List<DropdownMenuItem<num>>? fuelPrices;
    if (_appConfig.fuelPrices != null) {
      fuelPrices = _appConfig.fuelPrices!.keys.map(
            (key) => DropdownMenuItem(
          child: Text('${_appConfig.fuelPrices![key]} (${_appConfig.fuelPriceCurrency} ${_fuelPriceFormatter.format(key)})'),
          value: key,
        ),
      ).toList();
      if (widget.item.fuelPrice != null && !_appConfig.fuelPrices!.containsKey(widget.item.fuelPrice)) {
        fuelPrices.add(DropdownMenuItem(
          child: Text('${_appConfig.fuelPriceCurrency} ${_fuelPriceFormatter.format(widget.item.fuelPrice)}'),
          value: widget.item.fuelPrice,
        ));
      }
    }
    else {
      fuelPrices = null;
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        // flight date
        _DateListTile(
          selectedDate: _date,
          onDateSelected: (date) => _onDateChanged(date, false),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // pilot
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          leading: CircleAvatar(foregroundImage: _appConfig.getPilotAvatar(_pilotName)),
          title: Text(_pilotName),
          onTap: () => _onTapPilot(context),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        _HourListTile(
          controller: _startHourController,
          // TODO i18n
          hintText: 'Inizio',
          showIcon: true,
          onTap: () => true,
        ),
        _HourListTile(
          controller: _endHourController,
          // TODO i18n
          hintText: 'Fine',
          showIcon: false,
          onTap: () => true,
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // take off place
        // TODO identical widget with landing place, just make one with proper parameters
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
          leading: const Icon(Icons.flight_takeoff),
          trailing: IconButton(
            icon: const Icon(Icons.home),
            // TODO i18n
            tooltip: 'Home',
            onPressed: () => _originController.text = _appConfig.locationName,
          ),
          title: TextFormField(
            controller: _originController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: TextInputType.streetAddress,
            textCapitalization: TextCapitalization.words,
            maxLines: 1,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              // TODO i18n
              labelText: 'Partenza',
            ),
            // TODO validator
          ),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // landing place
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
          leading: const Icon(Icons.flight_land),
          trailing: IconButton(
            icon: const Icon(Icons.home),
            // TODO i18n
            tooltip: 'Home',
            onPressed: () => _destinationController.text = _appConfig.locationName,
          ),
          title: TextFormField(
            controller: _destinationController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: TextInputType.streetAddress,
            textCapitalization: TextCapitalization.words,
            maxLines: 1,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              // TODO i18n
              labelText: 'Arrivo',
            ),
            // TODO validator
          ),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // fuel quantity + type/price
        if (_appConfig.fuelPrices != null) ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
          leading: const Icon(Icons.local_gas_station),
          title: TextFormField(
            controller: _fuelController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: TextInputType.number,
            maxLines: 1,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              // TODO i18n
              prefixText: 'litri ',
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => value != null && value.isNotEmpty && int.tryParse(value) == null ?
              // TODO i18n
              'Numero non valido' : null,
          ),
          trailing: SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            child: DropdownButtonFormField<num>(
              value: _fuelPrice,
              onChanged: (value) => _fuelPrice = value,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
              items: fuelPrices,
            ),
          ),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        ListTile(
          // FIXME TextField inside ListTile caused enter key to act as onPressed
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          leading: const Icon(
            Icons.subject,
          ),
          title: TextFormField(
            controller: _notesController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              // TODO i18n
              hintText: AppLocalizations.of(context)!.bookFlightModal_hint_notes,
            ),
          ),
        ),
      ],
    );
  }

  Widget _getItemEditor(BuildContext context) =>
    Form(
      key: _formKey,
      child: isCupertino(context) ?
      _buildCupertinoForm(context, _appConfig) :
      _buildMaterialForm(context)
    );

  @override
  Widget build(BuildContext context) {
    List<Widget> trailingActions;
    Widget? leadingAction;

    if (isCupertino(context)) {
      leadingAction = CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context)!.bookFlightModal_button_close),
      );
      trailingActions = [PlatformTextButton(
        onPressed: () => _onSave(context),
        cupertino: (_, __) => CupertinoTextButtonData(
          // workaround for https://github.com/flutter/flutter/issues/32701
          padding: EdgeInsets.zero,
        ),
        child: Text(AppLocalizations.of(context)!.bookFlightModal_button_save),
      )];
    }
    else {
      leadingAction = null;
      trailingActions = [
        PlatformIconButton(
          onPressed: () => _onSave(context),
          icon: const Icon(Icons.check_sharp),
          material: (_, __) => MaterialIconButtonData(
            tooltip: AppLocalizations.of(context)!.bookFlightModal_button_save,
          ),
        ),
      ];
      if (_isEditing) {
        trailingActions.insert(0, PlatformIconButton(
          onPressed: () => _onDelete(context),
          icon: const Icon(Icons.delete_sharp),
          material: (_, __) => MaterialIconButtonData(
            tooltip: AppLocalizations.of(context)!.bookFlightModal_button_delete,
          ),
        ),
        );
      }
    }

    return PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: Text(_isEditing ?
        AppLocalizations.of(context)!.bookFlightModal_title_edit :
        AppLocalizations.of(context)!.bookFlightModal_title_create
        ),
        leading: leadingAction,
        trailingActions: trailingActions,
      ),
      cupertino: (context, platform) => CupertinoPageScaffoldData(
        backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
      ),
      body: Stack(
        children: <Widget>[
          _getItemEditor(context)
        ],
      ),
    );
  }

  void _onSave(BuildContext context) {
    // TODO no validate necessary here?
  /* TODO
    if (_isEditing) {
      if (!_appConfig.admin) {
        if (_appConfig.pilotName != widget.event.pilotName) {
          showError(context, AppLocalizations.of(context)!.bookFlightModal_error_notOwnBooking_edit);
          return;
        }
      }
      else {
        if (_pilotName != widget.event.pilotName) {
          showConfirm(
              context: context,
              text: AppLocalizations.of(context)!.bookFlightModal_dialog_changePilot_message,
              title: AppLocalizations.of(context)!.bookFlightModal_dialog_changePilot_title,
              okCallback: () => _doSave(context)
          );
          return;
        }
      }
    }
    else {
      if (!_appConfig.admin) {
        if (_appConfig.pilotName != _pilotName) {
          showError(context, AppLocalizations.of(context)!.bookFlightModal_error_bookingForOthers);
          return;
        }
      }
    }

    // no reason to stop
    _doSave(context);
 */
  }

  void _doSave(BuildContext context) {
    // TODO
  }

  void _onDelete(BuildContext context) {
    // TODO i18n and all
    if (!_appConfig.admin) {
      if (_appConfig.pilotName != widget.item.pilotName) {
        showError(context, AppLocalizations.of(context)!.bookFlightModal_error_notOwnBooking_delete);
        return;
      }
    }

    showConfirm(
      context: context,
      text: AppLocalizations.of(context)!.bookFlightModal_dialog_delete_message,
      title: AppLocalizations.of(context)!.bookFlightModal_dialog_delete_title,
      okCallback: () => _doDelete(context),
      destructiveOk: true,
    );
  }

  void _doDelete(BuildContext context) {
    /* TODO
    final Future task = _service.deleteBooking(widget.event)
        .timeout(kNetworkRequestTimeout)
        .catchError((error, StackTrace stacktrace) {
      _log.warning('DELETE ERROR', error, stacktrace);
      final String message;
      // TODO specialize exceptions (e.g. network errors, others...)
      if (error is TimeoutException) {
        message = AppLocalizations.of(context)!.error_generic_network_timeout;
      }
      else {
        message = getExceptionMessage(error);
      }
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
        showError(context, message);
      });
    });

    showPlatformDialog(
      context: context,
      builder: (context) => FutureProgressDialog(task,
        message: isCupertino(context) ? null :
        Text(AppLocalizations.of(context)!.bookFlightModal_dialog_working),
      ),
    ).then((value) {
      if (value != null) {
        Navigator.of(context, rootNavigator: true).pop(value);
      }
    });
     */
  }

  void _onTapPilot(BuildContext context) {
    // TODO add "no pilot" pilot
    final items = _appConfig.pilotNames;
    if (isCupertino(context)) {
      Widget pageRouteBuilder(BuildContext context) => PlatformScaffold(
        iosContentPadding: true,
        appBar: PlatformAppBar(
          title: Text(AppLocalizations.of(context)!.bookFlightModal_dialog_selectPilot),
        ),
        cupertino: (context, platform) => CupertinoPageScaffoldData(
          backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
        ),
        body: PilotSelectList(
            pilotNames: items,
            selectedName: _pilotName,
            avatarProvider: (name) => _appConfig.getPilotAvatar(name),
            onSelection: (selected) {
              setState(() {
                _pilotName = selected;
                Navigator.of(context).pop();
              });
            }),
      );

      Navigator.of(context, rootNavigator: true)
          .push(CupertinoPageRoute(
        builder: pageRouteBuilder,
      ));
    }
    else {
      showPlatformDialog(
        context: context,
        builder: (_context) => PlatformAlertDialog(
          title: Text(AppLocalizations.of(context)!.bookFlightModal_dialog_selectPilot,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.minPositive,
            child: PilotSelectList(
                pilotNames: items,
                selectedName: _pilotName,
                avatarProvider: (name) => _appConfig.getPilotAvatar(name),
                onSelection: (selected) {
                  setState(() {
                    _pilotName = selected;
                  });
                  Navigator.of(_context).pop();
                }
            ),
          ),
          material: (context, platform) => MaterialAlertDialogData(
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      );
    }
  }
}

class _HourListTile extends StatelessWidget {
  const _HourListTile({
    Key? key,
    required this.controller,
    required this.hintText,
    this.showIcon = true,
    this.onTap,
  }) : super(key: key);

  final DigitDisplayController controller;
  final String hintText;
  final bool showIcon;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: showIcon ? const Icon(Icons.timer) : const Text(''),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO try to replicate InputDecoration floating label text style
          Text(hintText, style: Theme.of(context).textTheme.caption!),
          DigitDisplayFormTextField(
            controller: controller,
            // TODO i18n
            validator: (value) => value == null || value == 0 ?
              'Inserire un orametro valido.' : null,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

}

// FIXME refactor into widget + controller (e.g. like a text field)
class _DateListTile extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime? selected) onDateSelected;
  final bool showIcon;

  const _DateListTile({
    Key? key,
    required this.onDateSelected,
    required this.selectedDate,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: showIcon ? const Icon(
        Icons.access_time,
      ) : const Text(''),
      title: Text(
        // TODO locale
        DateFormat('EEE, dd/MM/yyyy').format(selectedDate),
        textAlign: TextAlign.left,
      ),
      onTap: () async {
        final DateTime? date = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          /* TODO builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: ThemeData(
                              brightness:
                              widget.model.themeData.brightness,
                              colorScheme:
                              _getColorScheme(widget.model, true),
                              accentColor: widget.model.backgroundColor,
                              primaryColor:
                              widget.model.backgroundColor,
                            ),
                            child: child!,
                          );
                        }*/
        );
        onDateSelected(date);
      },
    );
  }

}
