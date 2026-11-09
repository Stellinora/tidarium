import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const dartSource = readFileSync(
  new URL(
    '../lib/features/timetable/import/adapters/qiangzhi_adapter.dart',
    import.meta.url,
  ),
  'utf8',
);
const start = dartSource.indexOf("r'''") + 4;
const end = dartSource.lastIndexOf("'''");
const script = dartSource.slice(start, end);

function stripTags(value) {
  return value
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/gi, ' ')
    .trim();
}

function makeHolder(html) {
  const fonts = [];
  const withBreaks = html.replace(/<br\s*\/?>/gi, '\n');
  const replaced = withBreaks.replace(
    /<font\b[^>]*title="([^"]*)"[^>]*>([\s\S]*?)<\/font>/gi,
    (_, title, body) => {
      const value = stripTags(body);
      fonts.push({ title, text: value });
      return value;
    },
  );
  const plain = replaced
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/gi, ' ')
    .trim();
  const firstLine =
    plain
      .split('\n')
      .map((line) => line.trim())
      .find((line) => line.length > 0) || '';

  return {
    childNodes: firstLine ? [{ nodeType: 3, textContent: firstLine }] : [],
    textContent: plain,
    querySelector(selector) {
      const match = selector.match(/^font\[title\*="([^"]+)"\]$/);
      if (!match) return null;
      const found = fonts.find((item) => item.title.includes(match[1]));
      return found ? { textContent: found.text } : null;
    },
  };
}

globalThis.window = {
  location: {
    pathname: '/jsxsd/xskb/xskb_list.do',
    origin: 'https://jw.example.edu.cn',
    href: 'https://jw.example.edu.cn/jsxsd/xskb/xskb_list.do',
  },
  shiguangBridgePromise: {},
  shiguangBridge: {},
};
globalThis.location = globalThis.window.location;
globalThis.document = {
  createElement() {
    let holder = null;
    return {
      set innerHTML(value) {
        holder = makeHolder(value);
      },
      get childNodes() {
        return holder ? holder.childNodes : [];
      },
      get textContent() {
        return holder ? holder.textContent : '';
      },
      querySelector(selector) {
        return holder ? holder.querySelector(selector) : null;
      },
    };
  },
};

globalThis.__QIANGZHI_TEST__ = {};
// eslint-disable-next-line no-eval
eval(script);
const adapter = globalThis.__QIANGZHI_TEST__;

function block(innerHtml) {
  return { innerHTML: innerHtml };
}

function cell(blocks) {
  return {
    querySelectorAll(selector) {
      return selector.includes('kbcontent') ? blocks : [];
    },
  };
}

function row(label, cells) {
  return {
    querySelector(selector) {
      return selector === 'th' ? { textContent: label } : null;
    },
    querySelectorAll(selector) {
      return selector === 'td' ? cells : [];
    },
  };
}

function timetableDocument(rows) {
  const table = {
    querySelectorAll(selector) {
      return selector === 'tr' ? rows : [];
    },
  };
  return {
    getElementById(id) {
      return id === 'kbtable' ? table : null;
    },
    querySelectorAll(selector) {
      return selector === 'table' ? [table] : [];
    },
  };
}

test('parses odd weeks and bracket sections', () => {
  const parsed = adapter.parseWeeksAndSections('1-16周(单)[01-02节]');
  assert.deepEqual(parsed.weeks, [1, 3, 5, 7, 9, 11, 13, 15]);
  assert.deepEqual(parsed.sections, [1, 2]);
});

test('parses range lists and even weeks', () => {
  const parsed = adapter.parseWeeksAndSections('1-8,10-16周(双)[05-06节]');
  assert.deepEqual(parsed.weeks, [2, 4, 6, 8, 10, 12, 14, 16]);
  assert.deepEqual(parsed.sections, [5, 6]);
});

test('parses bare parity markers and parenthesised sections', () => {
  const bare = adapter.parseWeeksAndSections('1-16周单[01-02节]');
  assert.deepEqual(bare.weeks, [1, 3, 5, 7, 9, 11, 13, 15]);
  assert.deepEqual(bare.sections, [1, 2]);

  const parenthesised = adapter.parseWeeksAndSections('1-16周(01-02节)');
  assert.deepEqual(
    parenthesised.weeks,
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
  );
  assert.deepEqual(parenthesised.sections, [1, 2]);
});

test('parses a 强智 timetable row', () => {
  const monday = block(
    '<div>高等数学<br>' +
      '<font title="教师">张三</font><br>' +
      '<font title="周次">1-16周(单)</font><br>' +
      '<font title="地点">教一101</font></div>',
  );
  const tuesday = block(
    '<div>大学英语<br>' +
      '<font title="教师">李四</font><br>' +
      '<font title="周次">1-16周</font><br>' +
      '<font title="地点">教二202</font></div>',
  );

  const doc = timetableDocument([
    row('第1-2节', [cell([monday]), cell([tuesday])]),
  ]);
  const courses = adapter.parseTimetable(doc);

  assert.equal(courses.length, 2);
  assert.deepEqual(courses[0], {
    name: '高等数学',
    teacher: '张三',
    position: '教一101',
    day: 1,
    weeks: [1, 3, 5, 7, 9, 11, 13, 15],
    startSection: 1,
    endSection: 2,
  });
  assert.equal(courses[1].name, '大学英语');
  assert.equal(courses[1].day, 2);
});

test('merges continuous sections and deduplicates', () => {
  const merged = adapter.mergeAndDistinctCourses([
    {
      name: '高等数学',
      teacher: '张三',
      position: '教一101',
      day: 1,
      weeks: [1, 2, 3],
      startSection: 1,
      endSection: 2,
    },
    {
      name: '高等数学',
      teacher: '张三',
      position: '教一101',
      day: 1,
      weeks: [1, 2, 3],
      startSection: 3,
      endSection: 4,
    },
  ]);

  assert.equal(merged.length, 1);
  assert.equal(merged[0].startSection, 1);
  assert.equal(merged[0].endSection, 4);
});
