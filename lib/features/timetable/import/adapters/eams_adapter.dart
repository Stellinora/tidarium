const String eamsAdapterScript = r'''
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

  function powerSplit(raw) {
    var args = [];
    var current = '';
    var depth = 0;
    var quote = '';
    for (var i = 0; i < raw.length; i++) {
      var ch = raw.charAt(i);
      if (quote) {
        current += ch;
        if (ch === quote && raw.charAt(i - 1) !== '\\') quote = '';
        continue;
      }
      if (ch === '"' || ch === "'") {
        quote = ch;
        current += ch;
        continue;
      }
      if (ch === '(' || ch === '[' || ch === '{') {
        depth += 1;
        current += ch;
        continue;
      }
      if (ch === ')' || ch === ']' || ch === '}') {
        depth -= 1;
        current += ch;
        continue;
      }
      if (ch === ',' && depth === 0) {
        args.push(current.trim());
        current = '';
        continue;
      }
      current += ch;
    }
    if (current.trim()) args.push(current.trim());
    return args;
  }

  function unquote(value) {
    var result = text(value);
    if (
      (result.charAt(0) === '"' && result.charAt(result.length - 1) === '"') ||
      (result.charAt(0) === "'" && result.charAt(result.length - 1) === "'")
    ) {
      result = result.slice(1, -1);
    }
    return result;
  }

  function parseWeeksBitmap(bitmap) {
    var value = text(bitmap);
    var weeks = [];
    for (var week = 1; week < value.length && week <= 60; week++) {
      if (value.charAt(week) === '1') weeks.push(week);
    }
    return weeks;
  }

  function cleanName(value) {
    return text(value).replace(/\([^()]*\)\s*$/, '').trim();
  }

  function cleanPosition(value) {
    return text(value)
      .replace(/\([^()]*\)/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function parseParameters(html) {
    var value = String(html || '');
    var idsMatch = value.match(
      /bg\.form\.addInput\(\s*form\s*,\s*["']ids["']\s*,\s*["']([^"']+)["']\s*\)/
    );
    var tagIdMatch = value.match(/id=["'](semesterBar\d+Semester)["']/);
    if (!idsMatch || !tagIdMatch) return null;

    var tagId = tagIdMatch[1];
    var elementMatch = value.match(
      new RegExp('<[^>]*\\bid=["\']' + tagId + '["\'][^>]*>', 'i')
    );
    var currentMatch = elementMatch
      ? elementMatch[0].match(/\bvalue=["'](\d+)["']/i)
      : null;
    return {
      ids: idsMatch[1],
      tagId: tagId,
      currentSemesterId: currentMatch ? currentMatch[1] : null,
    };
  }

  function parseSemesterResponse(raw) {
    var data;
    try {
      data = new Function('return (' + raw + ');')();
    } catch (_) {
      return [];
    }
    var semesters = data && data.semesters ? data.semesters : {};
    var list = [];
    Object.keys(semesters).forEach(function (key) {
      var entries = Array.isArray(semesters[key]) ? semesters[key] : [];
      entries.forEach(function (item) {
        if (!item || item.id == null) return;
        list.push({
          id: String(item.id),
          name: [item.schoolYear, item.name].filter(Boolean).join(' '),
        });
      });
    });
    return list;
  }

  function mergeCourses(courses) {
    if (!Array.isArray(courses) || courses.length <= 1) return courses;

    var list = courses.map(function (course) {
      return Object.assign({}, course, {
        weeks: Array.isArray(course.weeks)
          ? course.weeks.slice().sort(function (a, b) {
              return a - b;
            })
          : [],
      });
    });

    list.sort(function (a, b) {
      return (
        a.name.localeCompare(b.name) ||
        a.teacher.localeCompare(b.teacher) ||
        a.position.localeCompare(b.position) ||
        a.day - b.day ||
        a.weeks.join(',').localeCompare(b.weeks.join(',')) ||
        a.startSection - b.startSection
      );
    });

    var step1 = [];
    var current = list[0];
    for (var i = 1; i < list.length; i++) {
      var next = list[i];
      var sameCourseAndWeeks =
        current.name === next.name &&
        current.teacher === next.teacher &&
        current.position === next.position &&
        current.day === next.day &&
        current.weeks.join(',') === next.weeks.join(',');
      var continuous = current.endSection + 1 === next.startSection;
      var duplicate =
        current.startSection === next.startSection &&
        current.endSection === next.endSection;

      if (sameCourseAndWeeks && continuous) {
        current.endSection = next.endSection;
      } else if (sameCourseAndWeeks && duplicate) {
        continue;
      } else {
        step1.push(current);
        current = next;
      }
    }
    step1.push(current);

    step1.sort(function (a, b) {
      return (
        a.name.localeCompare(b.name) ||
        a.teacher.localeCompare(b.teacher) ||
        a.position.localeCompare(b.position) ||
        a.day - b.day ||
        a.startSection - b.startSection ||
        a.endSection - b.endSection
      );
    });

    var step2 = [];
    var merged = step1[0];
    for (var j = 1; j < step1.length; j++) {
      var following = step1[j];
      var sameSection =
        merged.name === following.name &&
        merged.teacher === following.teacher &&
        merged.position === following.position &&
        merged.day === following.day &&
        merged.startSection === following.startSection &&
        merged.endSection === following.endSection;
      if (sameSection) {
        merged.weeks = Array.from(
          new Set(merged.weeks.concat(following.weeks))
        ).sort(function (a, b) {
          return a - b;
        });
      } else {
        step2.push(merged);
        merged = following;
      }
    }
    step2.push(merged);
    return step2;
  }

  function parseTaskActivities(html) {
    var source = String(html || '');
    var unitMatch = source.match(/\bunitCount\s*=\s*(\d+)\s*;/);
    var unitCount = unitMatch ? parseInt(unitMatch[1], 10) : 14;
    var indexRegex = new RegExp(
      'index\\s*=\\s*(\\d+)\\s*\\*\\s*(?:unitCount|' +
        unitCount +
        ')\\s*\\+\\s*(\\d+)\\s*;',
      'g'
    );
    var simpleIndexRegex = /index\s*=\s*(\d+)\s*;/g;
    var blocks = source.split(/var\s+teachers\s*=/);
    if (blocks.length <= 1) blocks = ['', source];
    var results = [];

    for (var b = 1; b < blocks.length; b++) {
      var block = blocks[b];
      var teacher = '未知教师';
      var teacherMatch = block.match(/actTeachers\s*=\s*\[([\s\S]*?)\]\s*;/);
      if (teacherMatch) {
        var names = [];
        var nameRegex = /["']?name["']?\s*:\s*["']([^"']+)["']/g;
        var nameMatch;
        while ((nameMatch = nameRegex.exec(teacherMatch[1])) !== null) {
          names.push(nameMatch[1]);
        }
        if (names.length) teacher = names.join(',');
      }

      var activityRegex = /new\s+TaskActivity\(([\s\S]*?)\)\s*;/g;
      var activities = [];
      var activityMatch;
      while ((activityMatch = activityRegex.exec(block)) !== null) {
        activities.push({
          argsRaw: activityMatch[1],
          start: activityMatch.index,
          end: activityRegex.lastIndex,
        });
      }

      for (var a = 0; a < activities.length; a++) {
        var activity = activities[a];
        var args = powerSplit(activity.argsRaw).map(unquote);
        if (args.length < 6) continue;

        var bitmapIndex = -1;
        for (var i = args.length - 1; i >= 0; i--) {
          if (/^[01]{8,}$/.test(args[i])) {
            bitmapIndex = i;
            break;
          }
        }
        if (bitmapIndex < 4) continue;

        var name = cleanName(args[3] || '');
        var position = cleanPosition(args[bitmapIndex - 1] || '');
        var weeks = parseWeeksBitmap(args[bitmapIndex]);
        if (!name || weeks.length === 0) continue;

        var scopeEnd =
          a + 1 < activities.length ? activities[a + 1].start : block.length;
        var scope = block.slice(activity.end, scopeEnd);
        var matched = 0;
        var indexMatch;
        indexRegex.lastIndex = 0;
        while ((indexMatch = indexRegex.exec(scope)) !== null) {
          addCourse(
            parseInt(indexMatch[1], 10),
            parseInt(indexMatch[2], 10)
          );
          matched += 1;
        }

        if (matched === 0) {
          simpleIndexRegex.lastIndex = 0;
          while ((indexMatch = simpleIndexRegex.exec(scope)) !== null) {
            var rawIndex = parseInt(indexMatch[1], 10);
            addCourse(
              Math.floor(rawIndex / unitCount),
              rawIndex % unitCount
            );
          }
        }

        function addCourse(rawDay, rawSection) {
          var day = rawDay + 1;
          var section = rawSection + 1;
          if (day < 1 || day > 7 || section < 1 || section > unitCount) return;
          results.push({
            name: name,
            teacher: teacher,
            position: position,
            day: day,
            startSection: section,
            endSection: section,
            weeks: weeks.slice(),
          });
        }
      }
    }

    return mergeCourses(results);
  }

  async function request(url, options) {
    var response = await fetch(
      url,
      Object.assign(
        {
          credentials: 'include',
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
        },
        options || {}
      )
    );
    if (!response.ok) throw new Error('HTTP ' + response.status);
    return response.text();
  }

  async function fetchCourses(params) {
    var pageHtml = await request(
      window.location.origin + '/eams/courseTableForStd.action?sf_request_type=ajax'
    );
    var current = parseParameters(pageHtml) || params;
    if (!current) {
      throw new Error('未识别到 EAMS 课表参数，请确认已登录并进入教务系统');
    }

    var semesters = [];
    try {
      var raw = await request(
        window.location.origin + '/eams/dataQuery.action?sf_request_type=ajax',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
          },
          body:
            'tagId=' +
            encodeURIComponent(current.tagId) +
            '&dataType=semesterCalendar',
        }
      );
      semesters = parseSemesterResponse(raw);
    } catch (_) {}

    var semesterId = current.currentSemesterId;
    var defaultIndex = 0;
    semesters.forEach(function (item, index) {
      if (item.id === semesterId) defaultIndex = index;
    });
    if (!semesterId && semesters.length) semesterId = semesters[0].id;

    if (semesters.length > 1) {
      var choice = await bridge.showSingleSelection(
        '选择学期',
        semesters.map(function (item) {
          return item.name || item.id;
        }),
        defaultIndex
      );
      if (choice === null || choice === undefined) {
        toast('导入已取消');
        cancelImport();
        return null;
      }
      var picked = Number(choice);
      if (Number.isInteger(picked) && picked >= 0 && picked < semesters.length) {
        semesterId = semesters[picked].id;
      }
    }

    if (!semesterId) {
      throw new Error('未获取到学期信息，请确认教务系统可以正常打开课表');
    }

    var html = await request(
      window.location.origin +
        '/eams/courseTableForStd!courseTable.action?sf_request_type=ajax',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        },
        body:
          'ignoreHead=1&setting.kind=std&semester.id=' +
          encodeURIComponent(semesterId) +
          '&ids=' +
          encodeURIComponent(current.ids),
      }
    );
    return parseTaskActivities(html);
  }

  async function run() {
    try {
      toast('正在读取树维 EAMS 课表…');
      var pageHtml =
        document && document.documentElement
          ? document.documentElement.innerHTML
          : '';
      var courses = /new\s+TaskActivity\s*\(/.test(pageHtml)
        ? parseTaskActivities(pageHtml)
        : await fetchCourses(parseParameters(pageHtml));

      if (courses === null) return;
      if (!courses || courses.length === 0) {
        throw new Error(
          '没有解析到课程。请确认已登录并进入「我的课表」页面；' +
            '若页面需要选择学期，请先切换学期后重试。'
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
        '树维 EAMS 导入失败',
        String((error && error.message) || error) +
          '\n\n当前网址：' +
          (window.location.href || '')
      );
      cancelImport();
    }
  }

  if (globalThis.__EAMS_TEST__) {
    globalThis.__EAMS_TEST__.powerSplit = powerSplit;
    globalThis.__EAMS_TEST__.parseWeeksBitmap = parseWeeksBitmap;
    globalThis.__EAMS_TEST__.parseParameters = parseParameters;
    globalThis.__EAMS_TEST__.parseSemesterResponse = parseSemesterResponse;
    globalThis.__EAMS_TEST__.parseTaskActivities = parseTaskActivities;
    globalThis.__EAMS_TEST__.mergeCourses = mergeCourses;
    return;
  }

  run();
})();
''';
