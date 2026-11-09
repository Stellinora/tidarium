const String mttAdapterScript = r'''
(function () {
  var bridge = window.shiguangBridgePromise;
  var nativeBridge = window.shiguangBridge;

  function text(value) {
    return value == null ? '' : String(value).replace(/\u00a0/g, ' ').trim();
  }

  function elementText(element) {
    if (!element) return '';
    return text(element.innerText || element.textContent);
  }

  function toast(message) {
    try {
      nativeBridge.showToast(message);
    } catch (_) {}
  }

  function alertUser(title, content) {
    return bridge.showAlert(title, content, '确定');
  }

  function cancelImport() {
    try {
      nativeBridge.cancelImport();
    } catch (_) {}
  }

  function parseWeeksFromText(value) {
    var content = text(value);
    if (!content) return [];

    var parity =
      content.indexOf('双周') >= 0 || content.indexOf('双') >= 0
        ? 2
        : content.indexOf('单周') >= 0 || content.indexOf('单') >= 0
          ? 1
          : 0;
    var weeks = [];
    var pattern = /(\d+)(?:\s*[-~至到–—]\s*(\d+))?\s*周/g;
    var match;
    while ((match = pattern.exec(content)) !== null) {
      var start = parseInt(match[1], 10);
      var end = match[2] ? parseInt(match[2], 10) : start;
      for (var week = start; week <= end; week++) weeks.push(week);
    }

    if (weeks.length === 0) {
      content
        .replace(/[，、;；]/g, ',')
        .split(',')
        .forEach(function (part) {
          var item = part.trim();
          if (!item) return;
          var range = item.match(/^(\d+)\s*[-~至到–—]\s*(\d+)$/);
          if (range) {
            for (var week = parseInt(range[1], 10); week <= parseInt(range[2], 10); week++) {
              weeks.push(week);
            }
            return;
          }
          if (/^\d+$/.test(item)) weeks.push(parseInt(item, 10));
        });
    }

    if (parity) {
      weeks = weeks.filter(function (week) {
        return week % 2 === (parity === 1 ? 1 : 0);
      });
    }
    return Array.from(new Set(weeks)).sort(function (a, b) {
      return a - b;
    });
  }

  function parseSectionsFromText(value) {
    var content = text(value);
    if (!content) return [];
    var cleaned = content.replace(/(\d+)(?:\s*[-~至到–—]\s*(\d+))?\s*周/g, ' ');

    var range = cleaned.match(/(\d+)\s*[-~至到–—]\s*(\d+)\s*节/);
    if (!range) range = cleaned.match(/第\s*(\d+)\s*[-~至到–—]\s*(\d+)\s*节/);
    if (range) {
      var start = parseInt(range[1], 10);
      var end = parseInt(range[2], 10);
      if (end >= start) return [start, end];
    }

    var comma = cleaned.match(/(\d+)\s*[,，]\s*(\d+)\s*节/);
    if (comma) {
      var first = parseInt(comma[1], 10);
      var second = parseInt(comma[2], 10);
      return [Math.min(first, second), Math.max(first, second)];
    }

    var single = cleaned.match(/第?\s*(\d+)\s*节/);
    if (single) {
      var number = parseInt(single[1], 10);
      return [number, number];
    }
    return [];
  }

  function parseDayFromText(value) {
    var match = text(value).match(/(?:星期|周|礼拜)([一二三四五六日天])/);
    if (!match) return 0;
    return {
      一: 1,
      二: 2,
      三: 3,
      四: 4,
      五: 5,
      六: 6,
      日: 7,
      天: 7,
    }[match[1]];
  }

  function parseClassroom(value) {
    var content = text(value);
    if (!content) return '';
    var parts = content
      .split(',')
      .map(function (part) {
        return part.trim();
      })
      .filter(function (part) {
        return part && !/周|星期|礼拜|节/.test(part);
      });
    if (parts.length) return parts[parts.length - 1];
    return '';
  }

  function addCourse(courses, seen, course) {
    if (!course.name || !course.day || !course.startSection || !course.endSection) {
      return;
    }
    var key = [
      course.name,
      course.teacher,
      course.position,
      course.day,
      course.startSection,
      course.endSection,
    ].join('|');
    if (seen[key]) {
      var existing = seen[key];
      existing.weeks = Array.from(
        new Set(existing.weeks.concat(course.weeks))
      ).sort(function (a, b) {
        return a - b;
      });
      return;
    }
    seen[key] = course;
    courses.push(course);
  }

  function parseCell(cell, fallbackDay) {
    var courses = [];
    var seen = {};
    if (!cell) return courses;

    var cellDay =
      parseInt(text(cell.getAttribute('data-week')), 10) || fallbackDay || 0;
    var beginUnit = parseInt(text(cell.getAttribute('data-begin-unit')), 10);
    var endUnit = parseInt(text(cell.getAttribute('data-end-unit')), 10);

    var items = cell.querySelectorAll('.mtt_arrange_item');
    if (items.length === 0 && cell.querySelector('.mtt_item_kcmc')) {
      items = [cell];
    }

    Array.from(items).forEach(function (item) {
      var nameElement = item.querySelector('.mtt_item_kcmc');
      if (!nameElement) return;
      var nameNode = nameElement.firstChild;
      var rawName =
        nameNode && nameNode.nodeValue
          ? text(nameNode.nodeValue)
          : elementText(nameElement);
      var name = rawName
        .replace(/\[[^\]]*\]/g, '')
        .split('\n')[0]
        .split(/[,，]/)[0]
        .trim();
      if (!name) return;

      var teacher =
        elementText(item.querySelector('.mtt_item_jxbmc')) ||
        elementText(item.querySelector('.mtt_item_teacher'));
      var timeText = elementText(item.querySelector('.mtt_item_sksj'));
      var roomText = elementText(item.querySelector('.mtt_item_room'));
      var combined = [timeText, roomText].filter(Boolean).join(',');

      var weeks = parseWeeksFromText(combined);
      var sections = parseSectionsFromText(combined);
      var day = cellDay || parseDayFromText(combined);

      var startSection = sections.length
        ? sections[0]
        : beginUnit > 0
          ? Math.min(beginUnit, endUnit || beginUnit)
          : 0;
      var endSection = sections.length
        ? sections[1]
        : endUnit > 0
          ? Math.max(beginUnit || endUnit, endUnit)
          : startSection;

      addCourse(courses, seen, {
        name: name,
        teacher: teacher,
        position: parseClassroom(roomText || timeText),
        day: day,
        weeks: weeks,
        startSection: startSection,
        endSection: endSection,
      });
    });

    return courses;
  }

  function parsePage() {
    var courses = [];
    var seen = {};
    var cells = Array.from(document.querySelectorAll('td[data-role="item"]'));

    if (cells.length === 0) {
      var items = Array.from(document.querySelectorAll('.mtt_arrange_item'));
      items.forEach(function (item) {
        var cell =
          item.closest && item.closest('td[data-role="item"]')
            ? item.closest('td[data-role="item"]')
            : item.parentElement;
        parseCell(cell, 0).forEach(function (course) {
          addCourse(courses, seen, course);
        });
      });
    } else {
      cells.forEach(function (cell) {
        parseCell(cell, 0).forEach(function (course) {
          addCourse(courses, seen, course);
        });
      });
    }

    courses.sort(function (a, b) {
      return (
        a.day - b.day ||
        a.startSection - b.startSection ||
        a.name.localeCompare(b.name)
      );
    });
    return courses;
  }

  async function run() {
    try {
      toast('正在读取 MTT 课表…');
      var courses = parsePage();
      if (courses.length === 0) {
        throw new Error(
          '没有解析到课程。请确认已登录并停留在课表页面；' +
            '如果当前页面不是课表，请在教务系统中打开「我的课表」后重试。'
        );
      }

      var maxWeek = 0;
      courses.forEach(function (course) {
        course.weeks.forEach(function (week) {
          if (week > maxWeek) maxWeek = week;
        });
      });

      await bridge.saveImportedCourses(JSON.stringify(courses));
      if (maxWeek > 0) {
        await bridge.saveCourseConfig(
          JSON.stringify({ semesterTotalWeeks: maxWeek })
        );
      }

      toast('已读取 ' + courses.length + ' 条课程，请确认作息时间');
      nativeBridge.notifyTaskCompletion();
    } catch (error) {
      await alertUser(
        'MTT 课表导入失败',
        String((error && error.message) || error) +
          '\n\n当前网址：' +
          (window.location.href || '')
      );
      cancelImport();
    }
  }

  if (globalThis.__MTT_TEST__) {
    globalThis.__MTT_TEST__.parseWeeksFromText = parseWeeksFromText;
    globalThis.__MTT_TEST__.parseSectionsFromText = parseSectionsFromText;
    globalThis.__MTT_TEST__.parseDayFromText = parseDayFromText;
    globalThis.__MTT_TEST__.parseClassroom = parseClassroom;
    globalThis.__MTT_TEST__.parseCell = parseCell;
    globalThis.__MTT_TEST__.parsePage = parsePage;
    return;
  }

  run();
})();
''';
