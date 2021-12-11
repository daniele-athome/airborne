import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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

  _onTap(BuildContext context) {
    showPlatformDialog(
      context: context,
      builder: (_context) => HourMeterDialog(
        initialValue: widget.controller.number,
        onCancel: () => Navigator.pop(_context),
        onConfirm: (value) => Navigator.pop(_context, value),
      ),
    ).then((value) {
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
        onConfirm: (value) => _controller.number = value,
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
    this.onConfirm,
    this.onCancel,
  }) : super(key: key);

  final num initialValue;
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

  late BorderSide _borderSide;
  late Color _disabledButtonBackgroundColor;
  late TextStyle _textStyle;

  @override
  void initState() {
    _controller = DigitDisplayController(widget.initialValue);
    super.initState();
  }

  // TODO Cupertino buttons
  _buildNumberButton(String value, {
    String? text,
    bool enabled = true,
  }) =>
    Expanded(
      flex: 1,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: TextButton(
          onPressed: enabled ? () => _onPressed(value) : null,
          style: TextButton.styleFrom(
            backgroundColor: enabled ? null : _disabledButtonBackgroundColor,
            shape: RoundedRectangleBorder(
              side: _borderSide,
              borderRadius: const BorderRadius.all(Radius.circular(20)),
            )
          ),
          child: Text(text ?? value,
            style: _textStyle,
          )
        ),
      ),
    );

  _onPressed(String value) {
    setState(() {
      String number;
      if (_mode == _HourMeterDigitState.willReset) {
        if (value == '.') {
          _controller.number = 0;
          _mode = _HourMeterDigitState.fractionalDigit1;
          return;
        }
        else {
          number = '';
          _mode = _HourMeterDigitState.integralPart;
        }
      }
      else {
        number = _controller.number.toString();
      }
      if (_mode == _HourMeterDigitState.integralPart) {
        if (value == '.') {
          _mode = _HourMeterDigitState.fractionalDigit1;
        }
        else if (number.length < kMaxDisplayIntegerDigits) {
          number += value;
          _controller.number = int.parse(number);
        }
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit1) {
        _controller.number = double.parse(number) + (int.parse(value) * 0.1);
        _mode = _HourMeterDigitState.fractionalDigit2;
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit2) {
        _controller.number = double.parse(number) + (int.parse(value) * 0.01);
        _mode = _HourMeterDigitState.ended;
      }
    });
    if (mounted && isCupertino(context) && widget.onConfirm != null) {
      widget.onConfirm!(_controller.number);
    }
  }

  _onBackspace() {
    setState(() {
      if (_mode == _HourMeterDigitState.willReset) {
        _controller.number = 0;
        _mode = _HourMeterDigitState.integralPart;
      }
      else if (_mode == _HourMeterDigitState.integralPart) {
        final number = _controller.number.toString();
        _controller.number = number.length > 1 ? int.parse(number.substring(0, number.length - 1)) : 0;
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit1) {
        _mode = _HourMeterDigitState.integralPart;
      }
      else if (_mode == _HourMeterDigitState.fractionalDigit2) {
        _controller.number = _controller.number.toInt();
        _mode = _HourMeterDigitState.fractionalDigit1;
      }
      else if (_mode == _HourMeterDigitState.ended) {
        _controller.number = (_controller.number * 10).toInt() / 10;
        _mode = _HourMeterDigitState.fractionalDigit2;
      }
    });
    if (mounted && isCupertino(context) && widget.onConfirm != null) {
      widget.onConfirm!(_controller.number);
    }
  }

  Widget _buildNumberPad(BuildContext context) =>
    Column(
      // FIXME can't seem to find a way to stretch the rows
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNumberButton('1'),
              _buildNumberButton('2'),
              _buildNumberButton('3'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNumberButton('4'),
              _buildNumberButton('5'),
              _buildNumberButton('6'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNumberButton('7'),
              _buildNumberButton('8'),
              _buildNumberButton('9'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNumberButton('0'),
              _buildNumberButton('.',
                  text: NumberFormat.decimalPattern().symbols.DECIMAL_SEP,
                  enabled: _mode == _HourMeterDigitState.willReset || _mode == _HourMeterDigitState.integralPart
              ),
            ],
          ),
        ),
      ],
    );

  Widget _buildMaterialNumberPad(BuildContext context) {
    // some weird way to determine widget size
    final double width;
    final double height;
    final size = MediaQuery.of(context).size;
    if (size.height > size.width) {
      height = size.height * 0.4;
      width = 0;
    }
    else {
      height = double.infinity;
      width = size.width * 0.4;
    }

    return PlatformAlertDialog(
      title: Row(
        children: [
          DigitDisplayTextField(
            controller: _controller,
            fontSize: 26,
          ),
          IconButton(
            onPressed: _onBackspace,
            icon: const Icon(Icons.backspace),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        height: height,
        child: _buildNumberPad(context),
      ),
      actions: <Widget>[
        PlatformDialogAction(
          onPressed: () {
            if (widget.onCancel != null) {
              widget.onCancel!();
            }
          },
          child: Text(AppLocalizations.of(context)!.dialog_button_cancel),
        ),
        PlatformDialogAction(
          onPressed: () {
            if (widget.onConfirm != null) {
              widget.onConfirm!(_controller.number);
            }
          },
          child: Text(AppLocalizations.of(context)!.dialog_button_ok),
        ),
      ],
    );
  }

  Widget _buildCupertinoNumberPad(BuildContext context) {
    return Flex(
      direction: Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.start,
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
              onPressed: _onBackspace,
              child: const Icon(Icons.backspace, size: 32),
            ),
          ],
        ),
        // FIXME can't seem to find a way to stretch the rows
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: _buildNumberPad(context),
          )
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _borderSide = Divider.createBorderSide(context, width: 3);
    // TODO Cupertino colors
    _disabledButtonBackgroundColor = Theme.of(context).colorScheme.primary;
    _textStyle = Theme.of(context).textTheme.button!.copyWith(
      fontSize: Theme.of(context).textTheme.headline5!.fontSize,
    );

    return isCupertino(context) ?
      _buildCupertinoNumberPad(context) :
      _buildMaterialNumberPad(context);
  }

}
