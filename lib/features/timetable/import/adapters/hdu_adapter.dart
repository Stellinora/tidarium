const String hduAdapterScript = r'''
(function () {
  var HOST = 'newjw.hdu.edu.cn';
  var BASE = 'https://' + HOST;
  var PAGE = BASE + '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default';
  var SCHEDULE = BASE + '/jwglxt/kbcx/xskbcx_cxXsgrkb.html?gnmkdm=N2151';
  var WEEKS = BASE + '/jwglxt/kbcx/xskbcxZccx_cxZcByXnxq.html?gnmkdm=N2154';
  var SLOTS = BASE + '/jwglxt/kbcx/xskbcx_cxRjc.html?gnmkdm=N2151';
  var bridge = window.shiguangBridgePromise;

  function text(value) {
    return value == null ? '' : String(value).trim();
  }

  async function post(url, body) {
    var response = await fetch(url, {
      method: 'POST',
      credentials: 'include',
      referrer: PAGE,
      referrerPolicy: 'strict-origin-when-cross-origin',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: body
    });
    var raw = await response.text();
    if (!response.ok) throw new Error('HTTP ' + response.status);
    try {
      return JSON.parse(raw);
    } catch (error) {
      throw new Error('教务接口返回了非 JSON 内容，请确认已登录且页面没有失效');
    }
  }

  function optionValue(element) {
    if (!element) return '';
    if (text(element.value)) return text(element.value);
    return element.options && element.options.length
      ? text(element.options[0].value)
      : '';
  }

  async function getSemester() {
    var response = await fetch(PAGE, { credentials: 'include' });
    if (!response.ok) throw new Error('无法打开个人课表页面');
    var html = await response.text();
    var doc = new DOMParser().parseFromString(html, 'text/html');
    var xnm = doc.querySelector('#xnm');
    var xqm = doc.querySelector('#xqm');
    var year = optionValue(xnm);
    var term = optionValue(xqm);
    if (!year || !term) throw new Error('无法读取当前学年学期，请在教务系统打开个人课表后重试');
    return { xnm: year, xqm: term };
  }

  function parseWeeks(value) {
    var normalized = text(value)
      .replace(/[，、]/g, ',')
      .replace(/（/g, '(')
      .replace(/）/g, ')')
      .replace(/\s+/g, '');
    var result = new Set();
    normalized.split(',').forEach(function (part) {
      if (!part) return;
      var even = part.indexOf('双') >= 0;
      var odd = part.indexOf('单') >= 0;
      var cleaned = part.replace(/[单双周()]/g, '');
      var match = cleaned.match(/^(\d+)(?:-(\d+))?/);
      if (!match) return;
      var start = Number(match[1]);
      var end = Number(match[2] || match[1]);
      if (!Number.isInteger(start) || !Number.isInteger(end) || start < 1 || end < start) return;
      for (var week = start; week <= end; week++) {
        if (even && week % 2 !== 0) continue;
        if (odd && week % 2 === 0) continue;
        result.add(week);
      }
    });
    return Array.from(result).sort(function (a, b) { return a - b; });
  }

  function parseSections(value) {
    var normalized = text(value)
      .replace(/[，、]/g, ',')
      .replace(/[^\d,-]/g, '');
    var ranges = [];
    normalized.split(',').forEach(function (part) {
      var match = part.match(/^(\d+)(?:-(\d+))?$/);
      if (!match) return;
      var start = Number(match[1]);
      var end = Number(match[2] || match[1]);
      if (Number.isInteger(start) && Number.isInteger(end) && start > 0 && end >= start) {
        ranges.push([start, end]);
      }
    });
    return ranges;
  }

  function parseCourses(data) {
    var result = [];
    var list = Array.isArray(data.kbList) ? data.kbList : [];
    list.forEach(function (item) {
      var name = text(item.kcmc);
      var day = Number(item.xqj);
      var weeks = parseWeeks(item.zcd || '');
      var ranges = parseSections(item.jcs || item.jc || '');
      if (!name || !day || day < 1 || day > 7 || !weeks.length || !ranges.length) return;

      var teacher = text(item.xm);
      var position = text(item.cdmc);
      ranges.forEach(function (range) {
        result.push({
          name: name,
          teacher: teacher,
          position: position,
          day: day,
          startSection: range[0],
          endSection: range[1],
          weeks: weeks
        });
      });
    });
    return result;
  }

  function maxWeek(courses) {
    var max = 0;
    courses.forEach(function (course) {
      course.weeks.forEach(function (week) {
        if (week > max) max = week;
      });
    });
    return max;
  }

  async function getSlots(xnm, xqm, campusId) {
    var body = 'xnm=' + encodeURIComponent(xnm) +
      '&xqm=' + encodeURIComponent(xqm) +
      '&xqh_id=' + encodeURIComponent(campusId);
    var data = await post(SLOTS, body);
    var list = Array.isArray(data)
      ? data
      : (Array.isArray(data.items) ? data.items : (Array.isArray(data.rows) ? data.rows : []));
    var result = [];
    list.forEach(function (item) {
      var number = Number(item.jcmc);
      var start = text(item.qssj).slice(0, 5);
      var end = text(item.jssj).slice(0, 5);
      if (!number || !/^\d{2}:\d{2}$/.test(start) || !/^\d{2}:\d{2}$/.test(end)) return;
      result.push({ number: number, startTime: start, endTime: end });
    });
    return result;
  }

  async function getSemesterStart(xnm, xqm) {
    var data = await post(WEEKS, 'xnm=' + encodeURIComponent(xnm) + '&xqm=' + encodeURIComponent(xqm));
    var list = Array.isArray(data)
      ? data
      : (Array.isArray(data.items)
        ? data.items
        : (Array.isArray(data.rows) ? data.rows : []));
    if (!list.length) return null;
    var first = list[0];
    var raw = text(first.rq);
    var start = raw.split('/')[0];
    return {
      semesterStartDate: /^\d{4}-\d{2}-\d{2}$/.test(start) ? start : null,
      semesterTotalWeeks: list.length
    };
  }

  async function run() {
    if (location.hostname !== HOST) {
      await bridge.showAlert(
        '请先进入教务系统',
        '当前不在杭电新教务域名下。请先在网页中完成统一身份认证并进入 ' + HOST + '，再执行导入。',
        '确定'
      );
      return;
    }

    try {
      window.shiguangBridge.showToast('正在读取杭电教务课表...');
      var semester = await getSemester();
      var data = await post(
        SCHEDULE,
        'xnm=' + encodeURIComponent(semester.xnm) +
          '&xqm=' + encodeURIComponent(semester.xqm) +
          '&kzlx=ck&xsdm=&kclbdm=&kclxdm='
      );
      var courses = parseCourses(data);
      if (!courses.length) {
        throw new Error('没有解析到排课记录，请确认当前学期有课且课表已开放');
      }

      await bridge.saveImportedCourses(JSON.stringify(courses));
      if (Array.isArray(data.sjkList) && data.sjkList.length) {
        window.shiguangBridge.showToast('实践/其他安排暂未导入，当前仅导入网格课程');
      }

      var campusId = '1';
      for (var i = 0; i < (data.kbList || []).length; i++) {
        if (text(data.kbList[i].xqh_id)) {
          campusId = text(data.kbList[i].xqh_id);
          break;
        }
      }

      try {
        var slots = await getSlots(semester.xnm, semester.xqm, campusId);
        if (slots.length) {
          await bridge.savePresetTimeSlots(JSON.stringify(slots));
        }
      } catch (slotError) {
        window.shiguangBridge.showToast('课表已读取，但作息时间读取失败，将使用当前作息');
      }

      try {
        var meta = await getSemesterStart(semester.xnm, semester.xqm);
        if (meta && meta.semesterStartDate) {
          await bridge.saveCourseConfig(JSON.stringify({
            semesterStartDate: meta.semesterStartDate,
            semesterTotalWeeks: Math.max(meta.semesterTotalWeeks, maxWeek(courses))
          }));
        }
      } catch (weekError) {
        window.shiguangBridge.showToast('课表已读取，但学期日期读取失败');
      }

      window.shiguangBridge.notifyTaskCompletion();
    } catch (error) {
      await bridge.showAlert('杭电教务导入失败', String(error.message || error), '确定');
    }
  }

  run();
})();
''';
