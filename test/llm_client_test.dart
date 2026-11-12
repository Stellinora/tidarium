import 'package:flutter_test/flutter_test.dart';
import 'package:tidarium/core/ai/llm_client.dart';

void main() {
  group('extractAssistantText', () {
    test('普通字符串 content', () {
      expect(
        extractAssistantText({
          'choices': [
            {
              'message': {'content': '识别结果'},
            },
          ],
        }),
        '识别结果',
      );
    });

    test('content 为分段数组', () {
      expect(
        extractAssistantText({
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'text', 'text': '第一段'},
                  {'type': 'text', 'text': '第二段'},
                ],
              },
            },
          ],
        }),
        '第一段第二段',
      );
    });

    test('content 为空时回落到 reasoning_content', () {
      expect(
        extractAssistantText({
          'choices': [
            {
              'message': {'content': '', 'reasoning_content': '思考后输出'},
            },
          ],
        }),
        '思考后输出',
      );
    });

    test('旧式 choices.text 也能取到', () {
      expect(
        extractAssistantText({
          'choices': [
            {'text': '旧接口文本'},
          ],
        }),
        '旧接口文本',
      );
    });

    test('全部为空时返回 null', () {
      expect(
        extractAssistantText({
          'choices': [
            {
              'message': {'content': null},
            },
          ],
        }),
        isNull,
      );
      expect(extractAssistantText('not a map'), isNull);
      expect(extractAssistantText({'choices': []}), isNull);
    });
  });
}
