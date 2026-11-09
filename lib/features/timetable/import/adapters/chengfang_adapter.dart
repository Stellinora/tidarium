const String chengfangAdapterScript = r'''
(function () {
  var bridge = window.shiguangBridgePromise;
  var nativeBridge = window.shiguangBridge;

  function text(value) {
    return value == null ? '' : String(value).replace(/\u00a0/g, ' ').trim();
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

  function parseWeeks(value) {
    var content = text(value)
      .replace(/[，、;；]/g, ',')
      .replace(/周|第/g, '');
    if (!content) return [];

    var parity = content.indexOf('双') >= 0 ? 2 : content.indexOf('单') >= 0 ? 1 : 0;
    var weeks = [];
    content
      .replace(/[()（）]/g, '')
      .replace(/[单双]/g, '')
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

    if (parity) {
      weeks = weeks.filter(function (week) {
        return week % 2 === (parity === 1 ? 1 : 0);
      });
    }
    return Array.from(new Set(weeks)).sort(function (a, b) {
      return a - b;
    });
  }

  function parseSections(value) {
    var content = text(value).replace(/[，、;；]/g, ',');
    if (!content) return [];
    var sections = [];
    content.split(',').forEach(function (part) {
      var item = part.trim();
      if (!item) return;
      var range = item.match(/^(\d+)\s*[-~至到–—]\s*(\d+)$/);
      if (range) {
        for (var section = parseInt(range[1], 10); section <= parseInt(range[2], 10); section++) {
          sections.push(section);
        }
        return;
      }
      if (/^\d+$/.test(item)) sections.push(parseInt(item, 10));
    });
    return Array.from(new Set(sections)).sort(function (a, b) {
      return a - b;
    });
  }

  function extractKbxx(html) {
    var match = String(html || '').match(/(?:var\s+)?kbxx\s*=\s*(\[[\s\S]*?\])\s*;/);
    if (!match || !match[1]) return null;
    try {
      return JSON.parse(match[1]);
    } catch (_) {
      return null;
    }
  }

  function toCourses(kbxx) {
    if (!Array.isArray(kbxx)) return [];
    var courses = [];
    var seen = {};

    kbxx.forEach(function (item) {
      if (!item || typeof item !== 'object') return;
      var name = text(item.kcmc);
      var teacher = text(item.teaxms);
      var position = text(item.jxcdmcs) || text(item.jxbmc);
      var day = parseInt(text(item.xq), 10);
      var sections = parseSections(item.jcdm2);
      if (!name || !Number.isInteger(day) || day < 1 || day > 7 || sections.length === 0) {
        return;
      }

      var course = {
        name: name,
        teacher: teacher,
        position: position,
        day: day,
        weeks: parseWeeks(item.zcs),
        startSection: sections[0],
        endSection: sections[sections.length - 1],
      };
      var key = [
        course.name,
        course.teacher,
        course.position,
        course.day,
        course.startSection,
        course.endSection,
        course.weeks.join(','),
      ].join('|');
      if (seen[key]) return;
      seen[key] = true;
      courses.push(course);
    });

    courses.sort(function (a, b) {
      return (
        a.day - b.day ||
        a.startSection - b.startSection ||
        a.name.localeCompare(b.name)
      );
    });
    return courses;
  }

  function parseSemesters(doc) {
    var select = doc.querySelector(
      'select#xnxqdm, select[name="xnxqdm"], select#xnxq'
    );
    if (!select) return [];
    var list = [];
    Array.from(select.querySelectorAll('option')).forEach(function (option) {
      var value =
        text(option.getAttribute('value')) || text(option.value);
      if (!value) return;
      list.push({
        value: value,
        label: text(option.textContent) || value,
        selected: option.selected || option.hasAttribute('selected'),
      });
    });
    return list;
  }

  function findSemester(doc) {
    var select = doc.querySelector(
      'select#xnxqdm, select[name="xnxqdm"], select#xnxq'
    );
    if (select) {
      var selected = select.querySelector('option[selected]');
      if (selected) return text(selected.getAttribute('value')) || text(selected.value);
      var value = text(select.getAttribute('value')) || text(select.value);
      if (value) return value;
    }
    var hidden = doc.querySelector('input[name="xnxqdm"]');
    if (hidden) {
      var hiddenValue = text(hidden.getAttribute('value')) || text(hidden.value);
      if (hiddenValue) return hiddenValue;
    }
    try {
      return new URL(window.location.href).searchParams.get('xnxqdm') || '';
    } catch (_) {
      return '';
    }
  }

  function parseDocument(html) {
    return new DOMParser().parseFromString(html, 'text/html');
  }

  function currentHtml() {
    return document && document.documentElement
      ? document.documentElement.innerHTML
      : '';
  }

  async function fetchText(url) {
    var response = await fetch(url, {
      credentials: 'include',
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
    });
    if (!response.ok) throw new Error('HTTP ' + response.status);
    return response.text();
  }

  async function loadCourses(semester) {
    var fromPage = extractKbxx(currentHtml());
    if (fromPage && fromPage.length) {
      return { courses: toCourses(fromPage), errors: [] };
    }

    var paths = [];
    if (semester) {
      paths.push('/xsgrkbcx!xsAllKbList.action?xnxqdm=' + encodeURIComponent(semester));
      paths.push('/xsgrkbcx!getXsgrbkList.action?xnxqdm=' + encodeURIComponent(semester));
    } else {
      paths.push('/xsgrkbcx!xsAllKbList.action');
      paths.push('/xsgrkbcx!getXsgrbkList.action');
    }

    var errors = [];
    for (var i = 0; i < paths.length; i++) {
      try {
        var html = await fetchText(window.location.origin + paths[i]);
        var kbxx = extractKbxx(html);
        if (kbxx && kbxx.length) {
          return { courses: toCourses(kbxx), errors: errors };
        }
      } catch (error) {
        errors.push(paths[i] + '：' + String((error && error.message) || error));
      }
    }
    return { courses: [], errors: errors };
  }

  async function run() {
    try {
      var doc = document;
      var semesters = parseSemesters(doc);
      var semester = findSemester(doc);
      if (!semester && semesters.length) {
        semester = semesters[0].value;
      }

      var defaultIndex = 0;
      semesters.forEach(function (item, index) {
        if (item.selected || item.value === semester) defaultIndex = index;
      });

      if (semesters.length > 1) {
        var choice = await bridge.showSingleSelection(
          '选择学期',
          semesters.map(function (item) {
            return item.label;
          }),
          defaultIndex
        );
        if (choice === null || choice === undefined) {
          toast('导入已取消');
          cancelImport();
          return;
        }
        var index = Number(choice);
        if (Number.isInteger(index) && index >= 0 && index < semesters.length) {
          semester = semesters[index].value;
        }
      }

      toast('正在读取乘方教务课表…');
      var result = await loadCourses(semester);
      if (result.courses.length === 0) {
        throw new Error(
          '没有解析到课程。请确认已登录并停留在课表页面。' +
            (result.errors.length ? '\n\n接口返回：\n' + result.errors.join('\n') : '')
        );
      }

      var maxWeek = 0;
      result.courses.forEach(function (course) {
        course.weeks.forEach(function (week) {
          if (week > maxWeek) maxWeek = week;
        });
      });

      await bridge.saveImportedCourses(JSON.stringify(result.courses));
      if (maxWeek > 0) {
        await bridge.saveCourseConfig(
          JSON.stringify({ semesterTotalWeeks: maxWeek })
        );
      }

      toast('已读取 ' + result.courses.length + ' 条课程，请确认作息时间');
      nativeBridge.notifyTaskCompletion();
    } catch (error) {
      await alertUser(
        '乘方教务导入失败',
        String((error && error.message) || error) +
          '\n\n当前网址：' +
          (window.location.href || '')
      );
      cancelImport();
    }
  }

  if (globalThis.__CHENGFANG_TEST__) {
    globalThis.__CHENGFANG_TEST__.parseWeeks = parseWeeks;
    globalThis.__CHENGFANG_TEST__.parseSections = parseSections;
    globalThis.__CHENGFANG_TEST__.extractKbxx = extractKbxx;
    globalThis.__CHENGFANG_TEST__.toCourses = toCourses;
    globalThis.__CHENGFANG_TEST__.parseSemesters = parseSemesters;
    return;
  }

  run();
})();
''';
