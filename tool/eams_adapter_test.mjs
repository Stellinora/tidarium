import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const dartSource = readFileSync(
  new URL(
    '../lib/features/timetable/import/adapters/eams_adapter.dart',
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
    href: 'https://jw.example.edu.cn/eams/courseTableForStd.action',
  },
  shiguangBridgePromise: {},
  shiguangBridge: {},
};
globalThis.document = {
  documentElement: { innerHTML: '' },
};

globalThis.__EAMS_TEST__ = {};
// eslint-disable-next-line no-eval
eval(script);
const adapter = globalThis.__EAMS_TEST__;

test('splits TaskActivity arguments with quotes and nesting', () => {
  assert.deepEqual(adapter.powerSplit('"a,b",1,(2,3),"x"'), [
    '"a,b"',
    '1',
    '(2,3)',
    '"x"',
  ]);
});

test('parses EAMS week bitmaps', () => {
  assert.deepEqual(adapter.parseWeeksBitmap('0111'), [1, 2, 3]);
  assert.deepEqual(adapter.parseWeeksBitmap('0101'), [1, 3]);
});

test('parses ids and semester parameters', () => {
  const html =
    '<script>bg.form.addInput(form,"ids","12345");</script>' +
    '<div id="semesterBar1Semester" value="7"></div>';
  const params = adapter.parseParameters(html);
  assert.deepEqual(params, {
    ids: '12345',
    tagId: 'semesterBar1Semester',
    currentSemesterId: '7',
  });
});

test('parses the semester calendar response', () => {
  const raw =
    '{"semesters":{"1":[' +
    '{"id":7,"schoolYear":"2025-2026","name":"第一学期"}]}}';
  const semesters = adapter.parseSemesterResponse(raw);
  assert.deepEqual(semesters, [{ id: '7', name: '2025-2026 第一学期' }]);
});

test('parses TaskActivity rows and merges continuous sections', () => {
  const html = [
    'var unitCount = 12;',
    'var teachers = [];',
    'actTeachers = [{"name":"张三"}];',
    'var activity = new TaskActivity(' +
      '"t","x","张三","高等数学","x","教一101","0111111111111111");',
    'index = 0 * unitCount + 2;',
    'index = 0 * unitCount + 3;',
  ].join('\n');

  const courses = adapter.parseTaskActivities(html);
  assert.equal(courses.length, 1);
  assert.deepEqual(courses[0], {
    name: '高等数学',
    teacher: '张三',
    position: '教一101',
    day: 1,
    startSection: 3,
    endSection: 4,
    weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  });
});
