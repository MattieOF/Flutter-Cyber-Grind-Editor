import 'dart:math';

class Stack<E> {
  final _list = <E>[];
  int _index = 0;

  int maximum = -1;

  void push(E value) {
    if (_index != _list.length - 1) {
      _list.removeRange(_index + 1, _list.length);
    }

    _list.add(value);
    _index = _list.length - 1;

    if (maximum > 0 && _list.length > maximum) popFront();
  }

  E pop() {
    _index = min(_index, _list.length - 2);
    return _list.removeLast();
  }

  E back() {
    _index--;
    return _list[_index + 1];
  }

  E forward() {
    _index++;
    return _list[_index - 1];
  }

  void clear(E newRoot) {
    _list.clear();
    _list.add(newRoot);
    _index = 0;
  }

  E popFront() {
    _index--;
    return _list.removeAt(0);
  }

  E get peek => _list[_index];
  E get peekBehind => _list[_index - 1];
  E get peekInFront => _list[_index + 1];
  E get peekLast => _list.last;

  bool get isEmpty => _list.isEmpty;
  bool get hasOnlyOne => _list.length == 1;
  bool get hasOneBehind => _index > 0;
  bool get hasOneInFront => _index < (_list.length - 1);
  bool get isNotEmpty => _list.isNotEmpty;

  @override
  String toString() => _list.toString();
}
