import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../../helpers/config.dart';
import '../../helpers/cupertinoplus.dart';
import '../../helpers/digit_display.dart';
import '../../helpers/future_progress_dialog.dart';
import '../../helpers/list_tiles.dart';
import '../../helpers/pilot_select_list.dart';
import '../../helpers/utils.dart';
import '../../models/flight_log_models.dart';
import '../../services/flight_log_services.dart';
import 'hour_widget.dart';

final Logger _log = Logger((FlightLogItem).toString());

// TODO move all this fuel stuff somewhere else

const _kFuelDecimals = 1;
const _kFuelPriceDecimals = 2;

final _fuelPriceFormatter = NumberFormat("####0.00")..turnOffGrouping();

/// Parser can't truncate or round the parsed number, so we'll round it before save
final _fuelFormatter = NumberFormat("####0.#")..turnOffGrouping();

bool _validateFuel(String? fuelValue) =>
    fuelValue == null ||
    fuelValue.isEmpty ||
    _fuelFormatter.tryParse(fuelValue) != null;

bool _validateFuelPrice(String? fuelPriceValue) =>
    fuelPriceValue == null ||
    fuelPriceValue.isEmpty ||
    _fuelPriceFormatter.tryParse(fuelPriceValue) != null;

num _parseFuel(String text) =>
    roundDouble(_fuelFormatter.parse(text), _kFuelDecimals);

num _parseFuelPrice(String text) =>
    roundDouble(_fuelPriceFormatter.parse(text), _kFuelPriceDecimals);

class FlightLogModal extends StatefulWidget {
  const FlightLogModal(this.item, {Key? key}) : super(key: key);

  final FlightLogItem item;

  @override
  State<FlightLogModal> createState() => _FlightLogModalState();
}

class _FlightLogModalState extends State<FlightLogModal> {
  // event data
  late String _pilotName;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late DigitDisplayController _startHourController;
  late DigitDisplayController _endHourController;
  late TextEditingController _originController;
  late TextEditingController _destinationController;
  late DateTimePickerController _dateController;
  late TextEditingController _fuelController;
  late TextEditingController _fuelPriceController;
  late TextEditingController _notesController;

  late FlightLogBookService _service;
  late AppConfig _appConfig;

  bool get _isEditing => widget.item.id != null;

  @override
  void initState() {
    _pilotName = widget.item.pilotName;
    _originController = TextEditingController(text: widget.item.origin);
    _destinationController =
        TextEditingController(text: widget.item.destination);
    _startHourController = DigitDisplayController(widget.item.startHour);
    _endHourController = DigitDisplayController(widget.item.endHour);
    // TODO this controller should handle numeric values natively (i.e. it should parse/format text)
    _fuelController = TextEditingController(
        text: widget.item.fuel != null
            ? _fuelFormatter.format(widget.item.fuel)
            : '');
    // TODO this controller should handle numeric values natively (i.e. it should parse/format text)
    _fuelPriceController = TextEditingController(text: _fuelTotalCostToText());
    _notesController = TextEditingController(text: widget.item.notes);
    _dateController = DateTimePickerController(widget.item.date);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _service = Provider.of<FlightLogBookService>(context);
    _appConfig = Provider.of<AppConfig>(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _startHourController.dispose();
    _endHourController.dispose();
    _fuelController.dispose();
    _fuelPriceController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _fuelTotalCostToText() {
    return widget.item.fuel != null && widget.item.fuelPrice != null
        ? _fuelPriceFormatter.format(widget.item.fuel! * widget.item.fuelPrice!)
        : '';
  }

  Widget _buildCupertinoForm(BuildContext context, AppConfig appConfig) {
    // FIXME workaround https://github.com/flutter/flutter/issues/48438
    final TextStyle textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    // FIXME something wrong with some left/right paddings here
    return ListView(
      padding: kDefaultCupertinoFormMargin,
      children: [
        // flight date
        CupertinoFormSection(children: <Widget>[
          CupertinoDateTimeFormFieldRow(
            prefix:
                Text(AppLocalizations.of(context)!.flightLogModal_label_date),
            showTime: false,
            doneButtonText: AppLocalizations.of(context)!.dialog_button_done,
            controller: _dateController,
          ),
          CupertinoFormButtonRow(
            onPressed: () => _onTapPilot(context),
            padding: kDefaultCupertinoFormRowPadding,
            prefix: Text(
              AppLocalizations.of(context)!.flightLogModal_label_pilot,
              style: textStyle,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _pilotName,
                  style: textStyle,
                ),
                const SizedBox(width: 14),
                CircleAvatar(
                    foregroundImage: appConfig.getPilotAvatar(_pilotName)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        // start/end hour
        CupertinoFormSection(children: <Widget>[
          CupertinoHourFormRow(
            controller: _startHourController,
            hintText:
                AppLocalizations.of(context)!.flightLogModal_label_startHour,
          ),
          CupertinoHourFormRow(
            controller: _endHourController,
            hintText:
                AppLocalizations.of(context)!.flightLogModal_label_endHour,
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        // departure/arrival place
        CupertinoFormSection(children: <Widget>[
          // TODO home location button
          CupertinoTextFormFieldRow(
            controller: _originController,
            prefix:
                Text(AppLocalizations.of(context)!.flightLogModal_label_origin),
            textAlign: TextAlign.end,
          ),
          // TODO home location button
          CupertinoTextFormFieldRow(
            controller: _destinationController,
            prefix: Text(
                AppLocalizations.of(context)!.flightLogModal_label_destination),
            textAlign: TextAlign.end,
          ),
        ]),
        const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        // fuel + fuel price
        CupertinoFormSection(children: <Widget>[
          CupertinoTextFormFieldRow(
            controller: _fuelController,
            prefix: Text(AppLocalizations.of(context)!
                .flightLogModal_label_fuel_cupertino),
            textAlign: TextAlign.end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) => !_validateFuel(value)
                ? AppLocalizations.of(context)!
                    .flightLogModal_error_fuel_invalid_number
                : null,
          ),
          // TODO convert to standalone form row widget (using a controller? Though material widget doesn't support it...)
          CupertinoTextFormFieldRow(
            controller: _fuelPriceController,
            prefix: Text(AppLocalizations.of(context)!
                .flightLogModal_label_fuel_cost_cupertino(
                    _appConfig.fuelPriceCurrency)),
            textAlign: TextAlign.end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) => !_validateFuelPrice(value)
                ? AppLocalizations.of(context)!
                    .flightLogModal_error_fuelCost_invalid_number
                : null,
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            placeholder:
                AppLocalizations.of(context)!.flightLogModal_hint_notes,
          ),
        ]),
        if (_isEditing)
          const SizedBox(height: kDefaultCupertinoFormSectionMargin),
        if (_isEditing)
          CupertinoFormSection(children: <Widget>[
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: () => _onDelete(context),
                    child: Text(
                      AppLocalizations.of(context)!
                          .bookFlightModal_button_delete,
                      style: const TextStyle(
                          color: CupertinoColors.destructiveRed),
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
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        // flight date
        DateListTile(
          controller: _dateController,
          onDateSelected: (_) => setState(() {}),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // pilot
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          leading: CircleAvatar(
              foregroundImage: _appConfig.getPilotAvatar(_pilotName)),
          title: Text(
            _pilotName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
          ),
          onTap: () => _onTapPilot(context),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        HourListTile(
          controller: _startHourController,
          hintText:
              AppLocalizations.of(context)!.flightLogModal_label_startHour,
          showIcon: true,
        ),
        HourListTile(
          controller: _endHourController,
          hintText: AppLocalizations.of(context)!.flightLogModal_label_endHour,
          showIcon: false,
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // take off place
        // TODO identical widget with landing place, just make one with proper parameters
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
          leading: const SizedBox(
              height: double.infinity, child: Icon(Icons.flight_takeoff)),
          trailing: IconButton(
            icon: const Icon(Icons.home),
            tooltip: AppLocalizations.of(context)!.flightLogModal_label_home,
            onPressed: () => _originController.text = _appConfig.locationName,
          ),
          title: TextFormField(
            controller: _originController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: TextInputType.streetAddress,
            textCapitalization: TextCapitalization.words,
            maxLines: 1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText:
                  AppLocalizations.of(context)!.flightLogModal_label_origin,
            ),
          ),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // landing place
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
          leading: const SizedBox(
              height: double.infinity, child: Icon(Icons.flight_land)),
          trailing: IconButton(
            icon: const Icon(Icons.home),
            tooltip: AppLocalizations.of(context)!.flightLogModal_label_home,
            onPressed: () =>
                _destinationController.text = _appConfig.locationName,
          ),
          title: TextFormField(
            controller: _destinationController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: TextInputType.streetAddress,
            textCapitalization: TextCapitalization.words,
            maxLines: 1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: AppLocalizations.of(context)!
                  .flightLogModal_label_destination,
            ),
          ),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        // fuel quantity + type/price
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
          leading: const Icon(Icons.local_gas_station),
          title: TextFormField(
            controller: _fuelController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            maxLines: 1,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              border: InputBorder.none,
              // beware the trailing space, must be added post-i18n
              prefixText:
                  '${AppLocalizations.of(context)!.flightLogModal_hint_fuel_material} ',
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => !_validateFuel(value)
                ? AppLocalizations.of(context)!
                    .flightLogModal_error_fuel_invalid_number
                : null,
          ),
          trailing: SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            child: _MaterialFuelPriceSelector.totalCost(
              textController: _fuelPriceController,
              currencySymbol: _appConfig.fuelPriceCurrency,
            ),
          ),
        ),
        const Divider(
          height: 1.0,
          thickness: 1,
        ),
        ListTile(
          // FIXME TextField inside ListTile caused enter key to act as onPressed
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          leading: const Icon(
            Icons.subject,
          ),
          title: TextFormField(
            controller: _notesController,
            // TODO cursorColor: widget.model.backgroundColor,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: AppLocalizations.of(context)!.flightLogModal_hint_notes,
            ),
          ),
        ),
      ],
    );
  }

  Widget _getItemEditor(BuildContext context) => Form(
      key: _formKey,
      child: isCupertino(context)
          ? _buildCupertinoForm(context, _appConfig)
          : _buildMaterialForm(context));

  @override
  Widget build(BuildContext context) {
    List<Widget> trailingActions;
    Widget? leadingAction;

    if (isCupertino(context)) {
      leadingAction = CupertinoButton(
        key: const Key('button_flightLogModal_close'),
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context)!.flightLogModal_button_close),
      );
      trailingActions = [
        PlatformTextButton(
          onPressed: () => _onSave(context),
          cupertino: (_, __) => CupertinoTextButtonData(
            // workaround for https://github.com/flutter/flutter/issues/32701
            padding: EdgeInsets.zero,
          ),
          child: Text(AppLocalizations.of(context)!.flightLogModal_button_save),
        )
      ];
    } else {
      leadingAction = null;
      trailingActions = [
        PlatformIconButton(
          onPressed: () => _onSave(context),
          icon: const Icon(Icons.check_sharp),
          material: (_, __) => MaterialIconButtonData(
            tooltip: AppLocalizations.of(context)!.flightLogModal_button_save,
          ),
        ),
      ];
      if (_isEditing) {
        trailingActions.insert(
          0,
          PlatformIconButton(
            onPressed: () => _onDelete(context),
            icon: const Icon(Icons.delete_sharp),
            material: (_, __) => MaterialIconButtonData(
              tooltip:
                  AppLocalizations.of(context)!.flightLogModal_button_delete,
            ),
          ),
        );
      }
    }

    return PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: Text(_isEditing
            ? AppLocalizations.of(context)!.flightLogModal_title_edit
            : AppLocalizations.of(context)!.flightLogModal_title_create),
        leading: leadingAction,
        trailingActions: trailingActions,
      ),
      cupertino: (context, platform) => CupertinoPageScaffoldData(
        backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
      ),
      body: Stack(
        children: <Widget>[_getItemEditor(context)],
      ),
    );
  }

  void _onSave(BuildContext context) {
    if (_startHourController.value.number > _endHourController.value.number) {
      showError(context,
          AppLocalizations.of(context)!.flightLogModal_error_invalid_hourmeter);
      return;
    }

    if (_originController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty) {
      showError(context,
          AppLocalizations.of(context)!.flightLogModal_error_invalid_locations);
      return;
    }

    String fuelValue = _fuelController.text;
    if (!_validateFuel(fuelValue)) {
      showError(context,
          AppLocalizations.of(context)!.flightLogModal_error_invalid_fuel);
      return;
    }

    // validate fuel price if manual input for total cost
    if (fuelValue.isNotEmpty) {
      num fuelAmount = _parseFuel(_fuelController.text);
      if (fuelAmount > 0) {
        String fuelCostValue = _fuelPriceController.text;
        if (fuelCostValue.isEmpty) {
          showError(
              context,
              AppLocalizations.of(context)!
                  .flightLogModal_error_invalid_fuelCost_empty);
          return;
        } else if (!_validateFuelPrice(fuelCostValue)) {
          showError(
              context,
              AppLocalizations.of(context)!
                  .flightLogModal_error_invalid_fuelCost);
          return;
        }
      }
    }

    if (_isEditing) {
      // allow editing "no pilot" flights to non-admins
      if (!_appConfig.admin &&
          widget.item.pilotName != _appConfig.noPilotName) {
        if (_appConfig.pilotName != widget.item.pilotName) {
          showError(
              context,
              AppLocalizations.of(context)!
                  .flightLogModal_error_notOwnFlight_edit);
          return;
        }
      } else {
        if (_pilotName != widget.item.pilotName) {
          // non-admin can't change pilot of "no pilot" flights
          if (!_appConfig.admin &&
              widget.item.pilotName == _appConfig.noPilotName) {
            showError(
                context,
                AppLocalizations.of(context)!
                    .flightLogModal_error_alteringTestFlight);
            return;
          }

          final String message;
          if (_pilotName == _appConfig.noPilotName) {
            message = AppLocalizations.of(context)!
                .flightLogModal_dialog_changePilotNoPilot_message;
          } else {
            message = AppLocalizations.of(context)!
                .flightLogModal_dialog_changePilot_message;
          }

          showConfirm(
              context: context,
              text: message,
              title: AppLocalizations.of(context)!
                  .flightLogModal_dialog_changePilot_title,
              okCallback: () => _doSave(context));
          return;
        }
      }
    } else {
      if (!_appConfig.admin && _pilotName != _appConfig.noPilotName) {
        if (_appConfig.pilotName != _pilotName) {
          showError(
              context,
              AppLocalizations.of(context)!
                  .flightLogModal_error_loggingForOthers);
          return;
        }
      }
    }

    // no reason to stop
    _doSave(context);
  }

  void _doSave(BuildContext context) {
    final num? fuelAmount;
    final num? fuelPrice;
    if (_fuelController.text.isNotEmpty) {
      fuelAmount = _parseFuel(_fuelController.text);
      final fuelCost = _parseFuelPrice(_fuelPriceController.text);
      fuelPrice = roundDouble(fuelCost / fuelAmount, _kFuelPriceDecimals);
    }
    else {
      fuelAmount = null;
      fuelPrice = null;
    }

    final item = FlightLogItem(
      widget.item.id,
      _dateController.value!,
      _pilotName,
      _originController.text,
      _destinationController.text,
      _startHourController.number,
      _endHourController.number,
      fuelAmount,
      fuelPrice,
      _notesController.text,
    );
    final Future task =
        (_isEditing ? _service.updateItem(item) : _service.appendItem(item))
            .timeout(kNetworkRequestTimeout)
            // safe typing it for catchError
            .then((value) => Future<FlightLogItem?>.value(value))
            .catchError((error, StackTrace stacktrace) {
      _log.warning('SAVE ERROR', error, stacktrace);
      final String message;
      // TODO specialize exceptions (e.g. network errors, others...)
      if (error is TimeoutException) {
        message = AppLocalizations.of(context)!.error_generic_network_timeout;
      } else {
        message = getExceptionMessage(error);
      }
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        showError(context, message);
      });
      return null;
    });

    showPlatformDialog(
      context: context,
      builder: (context) => FutureProgressDialog(
        task,
        message: isCupertino(context)
            ? null
            : Text(AppLocalizations.of(context)!.flightLogModal_dialog_working),
      ),
    ).then((value) {
      if (value != null) {
        Navigator.of(context).pop(value);
      }
    });
  }

  void _onDelete(BuildContext context) {
    // allow deleting "no pilot" flights to non-admins
    if (!_appConfig.admin && widget.item.pilotName != _appConfig.noPilotName) {
      if (_appConfig.pilotName != widget.item.pilotName) {
        showError(
            context,
            AppLocalizations.of(context)!
                .flightLogModal_error_notOwnFlight_delete);
        return;
      }
    }

    showConfirm(
      context: context,
      text: AppLocalizations.of(context)!.flightLogModal_dialog_delete_message,
      title: AppLocalizations.of(context)!.flightLogModal_dialog_delete_title,
      okCallback: () => _doDelete(context),
      destructiveOk: true,
    );
  }

  void _doDelete(BuildContext context) {
    final Future task = _service
        .deleteItem(widget.item)
        .timeout(kNetworkRequestTimeout)
        // safe typing it for catchError
        .then((value) => Future<FlightLogItem?>.value(value))
        .catchError((error, StackTrace stacktrace) {
      _log.warning('DELETE ERROR', error, stacktrace);
      final String message;
      // TODO specialize exceptions (e.g. network errors, others...)
      if (error is TimeoutException) {
        message = AppLocalizations.of(context)!.error_generic_network_timeout;
      } else {
        message = getExceptionMessage(error);
      }
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        showError(context, message);
      });
      return null;
    });

    showPlatformDialog(
      context: context,
      builder: (context) => FutureProgressDialog(
        task,
        message: isCupertino(context)
            ? null
            : Text(AppLocalizations.of(context)!.flightLogModal_dialog_working),
      ),
    ).then((value) {
      if (value != null) {
        Navigator.of(context, rootNavigator: true).pop(value);
      }
    });
  }

  void _onTapPilot(BuildContext context) {
    final dialog = createPilotSelectDialog(
        context: context,
        pilotNames: _appConfig.pilotNamesWithNoPilot,
        title: AppLocalizations.of(context)!.flightLogModal_dialog_selectPilot,
        avatarProvider: (name) => _appConfig.getPilotAvatar(name),
        selectedPilot: _pilotName);

    dialog.then((value) {
      if (value != null) {
        setState(() {
          _pilotName = value;
        });
      }
    });
  }
}

// FIXME this widget should be stateful and handle the whole input part
class _MaterialFuelPriceSelector extends StatelessWidget {
  /// Builds a fuel price text input field.
  /// onChanged will give the total cost.
  const _MaterialFuelPriceSelector.totalCost({
    Key? key,
    // ignore: unused_element
    this.onChanged,
    required this.currencySymbol,
    required this.textController,
  }) : super(key: key);

  final TextEditingController? textController;
  final void Function(num? value)? onChanged;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: textController,
      // TODO cursorColor: widget.model.backgroundColor,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      maxLines: 1,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
      onChanged: (value) => onChanged != null
          ? onChanged!(
              _validateFuelPrice(value) ? _parseFuelPrice(value) : null)
          : {},
      decoration: InputDecoration(
        border: InputBorder.none,
        // FIXME not using given currency symbol
        icon: const Icon(Icons.euro),
        hintText: AppLocalizations.of(context)!.flightLogModal_hint_fuel_cost,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => !_validateFuelPrice(value)
          ? AppLocalizations.of(context)!
              .flightLogModal_error_fuelCost_invalid_number
          : null,
    );
  }
}

// TODO _CupertinoFuelPriceSelector
