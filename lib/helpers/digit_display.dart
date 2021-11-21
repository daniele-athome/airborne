
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class DigitDisplayTextField extends StatefulWidget {

  const DigitDisplayTextField({
    Key? key,
    this.controller,
  }) : super(key: key);

  final DigitDisplayController? controller;

  @override
  State<DigitDisplayTextField> createState() => _DigitDisplayTextFieldState();
}

class _DigitDisplayTextFieldState extends State<DigitDisplayTextField> {

  static final _hoursFormatter = NumberFormat("00000.00");

  @override
  Widget build(BuildContext context) {
    if (widget.controller != null && widget.controller!.number > 99999) {
      throw UnsupportedError('Numbers with more than 5 integer digits are not supported.');
    }

    final num number = widget.controller != null ? widget.controller!.number : 0;
    final numDigits = _hoursFormatter.format(number).split('');
    
    final children = <Widget>[];
    bool decimal = false;
    for (var e in numDigits) {
      final digit = int.tryParse(e);
      if (digit == null) {
        decimal = true;
        continue;
      }
      children.add(SingleDigitText(digit: digit, decimal: decimal));
    }

    return Row(
      children: children,
    );
  }

}

class DigitDisplayController extends ValueNotifier<DigitDisplay> {
  DigitDisplayController(num number) : super(DigitDisplay(number: number));

  num get number => value.number;

  set number(num newNumber) {
    value = DigitDisplay(number: newNumber);
  }

}

@immutable
class DigitDisplay {

  const DigitDisplay({
    this.number = 0,
  });

  final num number;

}

class SingleDigitText extends StatelessWidget {

  const SingleDigitText({
    Key? key,
    required this.digit,
    this.decimal = false,
  }) : assert(digit >= 0 && digit <= 9),
        super(key: key);

  final int digit;
  final bool decimal;

  @override
  Widget build(BuildContext context) =>
      _DigitText(
          text: digit.toString(),
          alternate: decimal,
      );

}

class _DigitText extends StatelessWidget {

  const _DigitText({
    Key? key,
    required this.text,
    this.alternate = false,
  }) : super(key: key);

  final String text;
  final bool alternate;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
    alignment: Alignment.center,
    color: alternate ? Colors.white : Colors.black,
    // TODO test on different screens
    width: 30,
    height: 40,
    child: Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'MajorMonoDisplay',
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: alternate ? Colors.black : Colors.white,
        ),
    ),
  );

}
