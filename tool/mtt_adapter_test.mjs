import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const dartSource = readFileSync(
  new URL(
    '../lib/features/timetable/import/adapters/mtt_adapter.dart',
    import.meta.url,
  ),
  'utf8',
);
const start = dartSource.indexOf("r'''") + 4;
const end = dartSource.lastIndexOf("'''");
const script = dartSource.slice(start, end);

globalThis.window = {
  location: { href: 'https://jw.example.edu.cn/jwapp/sys/wdkb/index.do' },
  shiguangBridgePromise: {},
  shiguangBridge: {},
};
globalThis.document = {
  querySelectorAll() {
    return [];
  },
};

globalThis.__MTT_TEST__ = {};
// eslint-disable-next-line no-eval
eval(script);
const adapter = globalThis.__MTT_TEST__;

test('parses weeks, sections, days and rooms', () => {
  assert.deepEqual(
    adapter.parseWeeksFromText('1-16周,星期三,3-4节,教一101'),
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
  );
  assert.deepEqual(adapter.parseWeeksFromText('1-16周(单)'), [
    1, 3, 5, 7, 9, 11, 13, 15,
  ]);
  assert.deepEqual(adapter.parseSectionsFromText('1-16周,星期三,3-4节'), [3, 4]);
  assert.equal(adapter.parseDayFromText('星期三'), 3);
  assert.equal(adapter.parseDayFromText('周日'), 7);
  assert.equal(adapter.parseClassroom('1-16周,星期三,3-4节,教一101'), '教一101');
});

function mockItem({
  name,
  teacher,
  time = '',
  room = '',
}) {
  return {
    querySelector(selector) {
      if (selector === '.mtt_item_kcmc') {
        return {
          firstChild: { nodeValue: name },
          textContent: name,
        };
      }
      if (selector === '.mtt_item_jxbmc') {
        return { innerText: teacher, textContent: teacher };
      }
      if (selector === '.mtt_item_sksj') {
        return time ? { innerText: time, textContent: time } : null;
      }
      if (selector === '.mtt_item_room') {
        return room ? { innerText: room, textContent: room } : null;
      }
      return null;
    },
  };
}

function mockCell(day, items) {
  return {
    getAttribute(name) {
      if (name === 'data-week') return String(day);
      return null;
    },
    querySelectorAll(selector) {
      return selector === '.mtt_arrange_item' ? items : [];
    },
    querySelector(selector) {
      return selector === '.mtt_item_kcmc' ? items[0]?.querySelector(selector) : null;
    },
  };
}

test('parses an MTT grid cell', () => {
  const cell = mockCell(3, [
    mockItem({
      name: '高等数学',
      teacher: '张三',
      room: '1-16周,星期三,3-4节,教一101',
    }),
  ]);
  const courses = adapter.parseCell(cell, 0);

  assert.equal(courses.length, 1);
  assert.deepEqual(courses[0], {
    name: '高等数学',
    teacher: '张三',
    position: '教一101',
    day: 3,
    weeks: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    startSection: 3,
    endSection: 4,
  });
});
