import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const dartSource = readFileSync(
  new URL(
    '../lib/features/timetable/import/adapters/chengfang_adapter.dart',
    import.meta.url,
  ),
  'utf8',
);
const start = dartSource.indexOf("r'''") + 4;
const end = dartSource.lastIndexOf("'''");
const script = dartSource.slice(start, end);

globalThis.window = {
  location: {
    origin: 'https://jw.example.edu.cn',
    href: 'https://jw.example.edu.cn/student/courseSelect',
  },
  shiguangBridgePromise: {},
  shiguangBridge: {},
};
globalThis.document = {
  documentElement: { innerHTML: '' },
  querySelector() {
    return null;
  },
};

globalThis.__CHENGFANG_TEST__ = {};
// eslint-disable-next-line no-eval
eval(script);
const adapter = globalThis.__CHENGFANG_TEST__;

test('parses week ranges and parity', () => {
  assert.deepEqual(adapter.parseWeeks('1-16'), [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
  ]);
  assert.deepEqual(adapter.parseWeeks('1-16周(单)'), [
    1, 3, 5, 7, 9, 11, 13, 15,
  ]);
  assert.deepEqual(adapter.parseWeeks('1,3,5,7'), [1, 3, 5, 7]);
});

test('parses comma separated sections', () => {
  assert.deepEqual(adapter.parseSections('05,06'), [5, 6]);
  assert.deepEqual(adapter.parseSections('10'), [10]);
});

test('extracts kbxx from a page', () => {
  const html =
    '<script>var kbxx = [' +
    '{"kcmc":"高等数学","teaxms":"张三","jxcdmcs":"教一101",' +
    '"xq":"1","zcs":"1-16","jcdm2":"01,02"}];</script>';
  const kbxx = adapter.extractKbxx(html);
  assert.equal(kbxx.length, 1);
  assert.equal(kbxx[0].kcmc, '高等数学');
});

test('maps kbxx fields to import courses', () => {
  const courses = adapter.toCourses([
    {
      kcmc: '高等数学',
      teaxms: '张三',
      jxcdmcs: '教一101',
      xq: '1',
      zcs: '1-16',
      jcdm2: '01,02',
    },
    {
      kcmc: '大学英语',
      teaxms: '李四',
      jxcdmcs: '教二202',
      xq: '2',
      zcs: '1-16周(单)',
      jcdm2: '03,04',
    },
  ]);

  assert.equal(courses.length, 2);
  assert.deepEqual(courses[0], {
    name: '高等数学',
    teacher: '张三',
    position: '教一101',
    day: 1,
    weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    startSection: 1,
    endSection: 2,
  });
  assert.deepEqual(courses[1].weeks, [1, 3, 5, 7, 9, 11, 13, 15]);
  assert.equal(courses[1].day, 2);
});
