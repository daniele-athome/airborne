import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:intl/intl.dart';

import '../../helpers/cupertinoplus.dart';
import '../../helpers/digit_display.dart';

class HourListTile extends StatefulWidget {
  const HourListTile({
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
  State<HourListTile> createState() => _HourListTileState();
}

class _HourListTileState extends State<HourListTile> {

  late DigitDisplayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DigitDisplayController(widget.controller.number);
  }

  _onTap(BuildContext context) {
    Widget pageRouteBuilder(BuildContext _context) => PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.hintText),
        trailingActions: [PlatformIconButton(
          onPressed: () {
            Navigator.pop(_context, _controller.number);
          },
          icon: const Icon(Icons.check),
          material: (_, __) => MaterialIconButtonData(
            // FIXME maybe another tooltip?
            tooltip: AppLocalizations.of(context)!.dialog_button_done,
          ),
        )],
      ),
      body: HourMeterDialog(
        initialValue: widget.controller.number,
        onChanged: (value) => _controller.number = value,
      ),
    );

    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(
      builder: pageRouteBuilder,
    )).then((value) {
      if (value != null) {
        setState(() {
          widget.controller.number = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: widget.showIcon ? const SizedBox(height: double.infinity, child: Icon(Icons.timer)) : const Text(''),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO try to replicate InputDecoration floating label text style
          Text(widget.hintText, style: Theme.of(context).textTheme.caption!),
          DigitDisplayFormTextField(
            controller: widget.controller,
            // TODO i18n
            validator: (value) => value == null || value == 0 ?
            'Inserire un orametro valido.' : null,
          ),
        ],
      ),
      onTap: widget.onTap ?? () => _onTap(context),
    );
  }
}

class CupertinoHourFormRow extends StatefulWidget {
  const CupertinoHourFormRow({
    Key? key,
    required this.controller,
    required this.hintText,
    this.onTap,
  }) : super(key: key);

  final DigitDisplayController controller;
  final String hintText;
  final GestureTapCallback? onTap;

  @override
  State<CupertinoHourFormRow> createState() => _CupertinoHourFormRowState();
}

class _CupertinoHourFormRowState extends State<CupertinoHourFormRow> {

  late DigitDisplayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DigitDisplayController(widget.controller.number);
  }

  _onPressed(BuildContext context) {
    Widget pageRouteBuilder(BuildContext _context) => PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: Text(widget.hintText),
        trailingActions: [PlatformTextButton(
          onPressed: () {
            Navigator.pop(_context, _controller.number);
          },
          cupertino: (_, __) => CupertinoTextButtonData(
            // workaround for https://github.com/flutter/flutter/issues/32701
            padding: EdgeInsets.zero,
          ),
          child: Text(AppLocalizations.of(context)!.dialog_button_done),
        )],
      ),
      cupertino: (context, platform) => CupertinoPageScaffoldData(
        backgroundColor: kCupertinoDialogScaffoldBackgroundColor(context),
      ),
      body: HourMeterDialog(
        initialValue: widget.controller.number,
        onChanged: (value) => _controller.number = value,
      ),
    );

    Navigator.of(context, rootNavigator: true)
        .push(CupertinoPageRoute(
      builder: pageRouteBuilder,
    )).then((value) {
      if (value != null) {
        setState(() {
          widget.controller.number = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIXME workaround https://github.com/flutter/flutter/issues/48438
    final TextStyle textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return CupertinoFormButtonRow(
      onPressed: widget.onTap ?? () => _onPressed(context),
      padding: kDefaultCupertinoFormRowPadding,
      prefix: Text(
        widget.hintText,
        style: textStyle,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DigitDisplayFormTextField(
            controller: widget.controller,
            // TODO i18n
            validator: (value) => value == null || value == 0 ?
            'Inserire un orametro valido.' : null,
          ),
        ],
      ),
    );
  }
}

class HourMeterDialog extends StatefulWidget {
  const HourMeterDialog({
    Key? key,
    required this.initialValue,
    this.onChanged,
    this.onConfirm,
    this.onCancel,
  }) : super(key: key);

  final num initialValue;
  final Function(num value)? onChanged;
  final Function(num value)? onConfirm;
  final Function()? onCancel;

  @override
  State<HourMeterDialog> createState() => _HourMeterDialogState();
}

class _HourMeterDigitState {
  const _HourMeterDigitState({
    required this.mode,
  });

  final int mode;

  static const _HourMeterDigitState willReset = _HourMeterDigitState(mode: -1);
  static const _HourMeterDigitState integralPart = _HourMeterDigitState(mode: 0);
  static const _HourMeterDigitState fractionalDigit1 = _HourMeterDigitState(mode: 1);
  static const _HourMeterDigitState fractionalDigit2 = _HourMeterDigitState(mode: 2);
  static const _HourMeterDigitState ended = _HourMeterDigitState(mode: 9);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HourMeterDigitState &&
          runtimeType == other.runtimeType &&
          mode == other.mode;

  @override
  int get hashCode => mode.hashCode;
}

class _HourMeterDialogState extends State<HourMeterDialog> {

  _HourMeterDigitState _mode = _HourMeterDigitState.willReset;
  late DigitDisplayController _controller;

  late Color _disabledButtonBackgroundColor;
  late TextStyle _textStyle;

  @override
  void initState() {
    _controller = DigitDisplayController(widget.initialValue, 4);
    super.initState();
  }

  /// Insipired by https://github.com/eopeter/flutter_dialpad
  _buildNumberButton(BuildContext context, String value, {
    String? text,
    bool enabled = true,
  }) {
    // TODO fix this number
    final sizeFactor = MediaQuery.of(context).size.height * 0.12;
    final darkMode = (isCupertino(context) ? CupertinoTheme.brightnessOf(context)
        : Theme.of(context).brightness) == Brightness.dark;

    return isCupertino(context) ?
    ClipOval(
      child: CupertinoInkWell(
        backgroundColor: enabled ? (darkMode ? Colors.white24 : Colors.black38) : _disabledButtonBackgroundColor,
        onPressed: enabled ? () => _onPressed(value) : null,
        child: SizedBox(
          height: sizeFactor,
          width: sizeFactor,
          child: Center(
            child: Text(text ?? value,
              style: _textStyle.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ) :
    InkResponse(
      onTap: enabled ? () => _onPressed(value) : null,
      radius: math.max(
        Material.defaultSplashRadius,
        sizeFactor * 0.7,
        // x 0.5 for diameter -> radius and + 40% overflow derived from other Material apps.
      ),
      child: SizedBox(
        height: sizeFactor,
        width: sizeFactor,
        child: Align(
          alignment: Alignment.center,
          child: Text(
            text ?? value,
            style: _textStyle,
          ),
        ),
      ),
    );
  }

  _onPressed(String value) {
    setState(() {
      String number;
      if (_mode == _HourMeterDigitState.willReset) {
        if (value == '.') {
          _controller.number = 0;
          _mode = _HourMeterDigitState.fractionalDigit1;
          _controller.activeDigit = 5;
          return;
        }
        else {
          number = '';
          _mode = _HourMeterDigitState.integralPart;
          _controller.activeDigit = 4;
        }
      }
      else {
        number = _controller.number.toString();
      }
      if (_mode == _HourMeterDigitState.integralPart) {
        if (value == '.') {
          _mode = _HourMeterDigitState.fractionalDigit1;
          _controller.activeDigit = 5;
        }
        else if (number.length < kMaxDisplayIntegerDigits) {
          number += value;
          _controller.number = int.parse(number);
        }
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit1) {
        _controller.number = double.parse(number) + (int.parse(value) * 0.1);
        _mode = _HourMeterDigitState.fractionalDigit2;
        _controller.activeDigit = 6;
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit2) {
        _controller.number = double.parse(number) + (int.parse(value) * 0.01);
        _mode = _HourMeterDigitState.ended;
      }
    });
    if (mounted && widget.onChanged != null) {
      widget.onChanged!(_controller.number);
    }
  }

  _onBackspace() {
    setState(() {
      if (_mode == _HourMeterDigitState.willReset) {
        _controller.number = 0;
        _mode = _HourMeterDigitState.integralPart;
        _controller.activeDigit = 4;
      }
      else if (_mode == _HourMeterDigitState.integralPart) {
        final number = _controller.number.toString();
        _controller.number = number.length > 1 ? int.parse(number.substring(0, number.length - 1)) : 0;
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit1) {
        _mode = _HourMeterDigitState.integralPart;
        _controller.activeDigit = 4;
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit2) {
        _controller.number = _controller.number.toInt();
        _mode = _HourMeterDigitState.fractionalDigit1;
        _controller.activeDigit = 5;
      }
      else if (_mode == _HourMeterDigitState.ended) {
        _controller.number = (_controller.number * 10).toInt() / 10;
        _mode = _HourMeterDigitState.fractionalDigit2;
        _controller.activeDigit = 6;
      }
    });
    if (mounted && widget.onChanged != null) {
      widget.onChanged!(_controller.number);
    }
  }

  Widget _buildNumberPad(BuildContext context) {
    final padding = EdgeInsets.symmetric(vertical: isCupertino(context) ? 12 : 4);
    return Center(
      child: Column(
        children: [
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton(context, '1'),
                _buildNumberButton(context, '2'),
                _buildNumberButton(context, '3'),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton(context, '4'),
                _buildNumberButton(context, '5'),
                _buildNumberButton(context, '6'),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton(context, '7'),
                _buildNumberButton(context, '8'),
                _buildNumberButton(context, '9'),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNumberButton(context, '0'),
                _buildNumberButton(context, '.',
                    text: NumberFormat.decimalPattern().symbols.DECIMAL_SEP,
                    enabled: _mode == _HourMeterDigitState.willReset || _mode == _HourMeterDigitState.integralPart
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FIXME not nice on landscape orientation
  Widget _buildMaterialNumberPad(BuildContext context) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DigitDisplayTextField(
              controller: _controller,
              fontSize: 26,
            ),
            IconButton(
              // TODO onLongPress should reset the value
              onPressed: _onBackspace,
              icon: const Icon(Icons.backspace),
            ),
          ],
        ),
        Flexible(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildNumberPad(context),
            )
        ),
      ],
    );

  // FIXME not nice on landscape orientation
  Widget _buildCupertinoNumberPad(BuildContext context) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DigitDisplayTextField(
              controller: _controller,
              fontSize: 32,
            ),
            CupertinoButton(
              // TODO onLongPress should reset the value
              onPressed: _onBackspace,
              child: const Icon(Icons.backspace, size: 32),
            ),
          ],
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildNumberPad(context),
          )
        ),
      ],
    );

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      _disabledButtonBackgroundColor = CupertinoColors.secondarySystemFill.resolveFrom(context);
      _textStyle = CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle;
    }
    else {
      _disabledButtonBackgroundColor = Theme.of(context).colorScheme.primary;
      _textStyle = Theme.of(context).textTheme.button!.copyWith(
        fontSize: Theme.of(context).textTheme.headline4!.fontSize,
      );
    }

    return isCupertino(context) ?
      _buildCupertinoNumberPad(context) :
      _buildMaterialNumberPad(context);
  }

}
