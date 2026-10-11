import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:router_observer/router_observer.dart';

Object? _redact(Object? value, {Set<String>? maskKeys, int maxChars = 200}) =>
    defaultRedactor(
      value,
      maskKeys: maskKeys ?? defaultMaskKeys,
      maxChars: maxChars,
    );

class _Explosive {
  @override
  String toString() => throw StateError('boom');
}

void main() {
  group('defaultRedactor', () {
    test('passes through null and primitives', () {
      expect(_redact(null), isNull);
      expect(_redact(42), 42);
      expect(_redact(true), true);
      expect(_redact('hello'), 'hello');
    });

    test('masks sensitive keys case-insensitively by containment', () {
      final out =
          _redact({
                'accessToken': 'abc',
                'PASSWORD': 'hunter2',
                'api_key': 'k',
                'safe': 'visible',
              })!
              as Map<String, Object?>;
      expect(out['accessToken'], maskedValue);
      expect(out['PASSWORD'], maskedValue);
      expect(out['api_key'], maskedValue);
      expect(out['safe'], 'visible');
    });

    test('recurses through nested maps and lists', () {
      final out =
          _redact({
                'user': {
                  'email': 'a@b.com',
                  'tags': ['one', 'two'],
                },
              })!
              as Map<String, Object?>;
      final user = out['user']! as Map<String, Object?>;
      expect(user['email'], maskedValue);
      expect(user['tags'], ['one', 'two']);
    });

    test('caps iterables at 50 items', () {
      final out = _redact(List<int>.generate(100, (i) => i))! as List<Object?>;
      expect(out, hasLength(50));
    });

    test('truncates long strings with a suffix', () {
      final out = _redact('a' * 250, maxChars: 200)! as String;
      expect(out, endsWith('...(50 more)'));
      expect(out.length, lessThan(250));
    });

    test('stringifies arbitrary objects', () {
      expect(_redact(const Duration(seconds: 1)), '0:00:01.000000');
    });

    test('never throws, even for explosive toString', () {
      expect(_redact(_Explosive()), '<unserializable:_Explosive>');
    });

    test('does not expose secrets in containers at the nesting limit', () {
      Object? value = {'token': 'deep-secret', 'password': 'hidden-password'};
      for (var i = 0; i < 6; i++) {
        value = {
          'nested': [value],
        };
      }
      final encoded = jsonEncode(_redact(value));
      expect(encoded, contains('<max-depth>'));
      expect(encoded, isNot(contains('deep-secret')));
      expect(encoded, isNot(contains('hidden-password')));
    });

    test('cyclic containers terminate without stringifying their contents', () {
      final value = <String, Object?>{'token': 'cycle-secret'};
      value['self'] = value;
      final encoded = jsonEncode(_redact(value));
      expect(encoded, contains('<max-depth>'));
      expect(encoded, isNot(contains('cycle-secret')));
    });

    test('respects custom mask keys', () {
      final out =
          _redact({'ssn': '123', 'token': 'abc'}, maskKeys: {'ssn'})!
              as Map<String, Object?>;
      expect(out['ssn'], maskedValue);
      expect(out['token'], 'abc');
    });
  });
}
