const String qiangzhiAdapterScript = r'''
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

  function resolveBase() {
    var path = window.location.pathname || '';
    var lower = path.toLowerCase();
    var index = lower.indexOf('/jsxsd');
    if (index < 0) return null;
    return window.location.origin + path.slice(0, index);
  }

  function jsxsdUrl(base, path) {
    return base + '/jsxsd' + path;
  }

  function parseDocument(html) {
    return new DOMParser().parseFromString(html, 'text/html');
  }

  function requestText(url, options) {
    return fetch(
      url,
      Object.assign(
        {
          credentials: 'include',
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
          },
        },
        options || {}
      )
    ).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return response.text();
    });
  }

  function optionValue(option) {
    if (!option) return '';
    return (
      text(option.getAttribute('value')) ||
      text(option.value) ||
      text(option.textContent)
    );
  }

  function parseSemesters(doc) {
    var select = doc.querySelector(
      'select[name="xnxq01id"], select#xnxq01id'
    );
    if (!select) return [];
    var list = [];
    Array.from(select.querySelectorAll('option')).forEach(function (option) {
      var value = optionValue(option);
      if (!value) return;
      list.push({
        value: value,
        label: text(option.textContent) || value,
        selected: option.selected || option.hasAttribute('selected'),
      });
    });
    return list;
  }

  function parseKbjcmsid(doc) {
    var select = doc.querySelector('select[name="kbjcmsid"]');
    if (!select) return '';
    var option =
      select.querySelector('option[selected]') || select.querySelector('option');
    return optionValue(option);
  }

  function parseWeeksAndSections(rawText) {
    var result = { weeks: [], sections: [] };
    var content = text(rawText);
    if (!content) return result;

    var parity = content.indexOf('双') >= 0 ? 2 : content.indexOf('单') >= 0 ? 1 : 0;
    var bracketIndex = content.indexOf('[');
    var cleaned = (bracketIndex >= 0 ? content.slice(0, bracketIndex) : content)
      .replace(/[（(][^（）()]*[）)]/g, '')
      .replace(/至|到|~/g, '-')
      .replace(/[单双]周?/g, '')
      .replace(/周|第/g, '');

    cleaned.split(/[,，、;；\s]+/).forEach(function (segment) {
      var item = segment.trim();
      if (!item) return;
      var range = item.match(/^(\d+)\s*[-–—]\s*(\d+)$/);
      if (range) {
        for (var week = parseInt(range[1], 10); week <= parseInt(range[2], 10); week++) {
          result.weeks.push(week);
        }
        return;
      }
      if (/^\d+$/.test(item)) {
        result.weeks.push(parseInt(item, 10));
      }
    });

    if (parity) {
      result.weeks = result.weeks.filter(function (week) {
        return week % 2 === (parity === 1 ? 1 : 0);
      });
    }
    result.weeks = Array.from(new Set(result.weeks)).sort(function (a, b) {
      return a - b;
    });

    var sectionMatch =
      content.match(/\[([^\]]*)\]/) ||
      content.match(/[（(]([^（）()]*节)[）)]/);
    if (sectionMatch) {
      (sectionMatch[1].match(/\d+/g) || []).forEach(function (number) {
        var section = parseInt(number, 10);
        if (result.sections.indexOf(section) < 0) result.sections.push(section);
      });
      result.sections.sort(function (a, b) {
        return a - b;
      });
    }
    return result;
  }

  function findTimetableTable(doc) {
    var table = doc.getElementById('timetable') || doc.getElementById('kbtable');
    if (table) return table;
    var tables = Array.from(doc.querySelectorAll('table'));
    return (
      tables.find(function (item) {
        var value = text(item.textContent);
        return value.indexOf('星期一') >= 0 && item.querySelector('.kbcontent, .kbcontent1');
      }) || null
    );
  }

  function collectCellCandidates(cellDiv, day, output, rowSections) {
    var html = String(cellDiv.innerHTML || '').trim();
    if (!html || html.replace(/&nbsp;/gi, '').trim() === '') return;

    html.split(/[-—–]{6,}\s*(?:<br\s*\/?>)?/i).forEach(function (blockHtml) {
      if (!blockHtml.trim()) return;

      var holder = document.createElement('div');
      holder.innerHTML = blockHtml;

      var name = '';
      for (var i = 0; i < holder.childNodes.length; i++) {
        var node = holder.childNodes[i];
        if (node.nodeType === 3 && /[\u4e00-\u9fa5]/.test(node.textContent)) {
          name = text(node.textContent);
          break;
        }
      }
      if (!name) name = text(holder.textContent).split('\n')[0].trim();
      if (!name) return;

      function pickText(titles) {
        for (var i = 0; i < titles.length; i++) {
          var element = holder.querySelector('font[title*="' + titles[i] + '"]');
          if (element && text(element.textContent)) return text(element.textContent);
        }
        return '';
      }

      var timeText = pickText(['周次', '节次']);
      if (!/\[[^\]]*\]/.test(timeText)) {
        var bracket = String(holder.textContent || '').match(/\[[^\]]*\]/);
        if (bracket) timeText += bracket[0];
      }

      var parsed = parseWeeksAndSections(timeText || holder.textContent);
      if (parsed.weeks.length === 0) return;
      if (parsed.sections.length === 0 && rowSections) {
        for (var section = rowSections[0]; section <= rowSections[1]; section++) {
          parsed.sections.push(section);
        }
      }

      var teacher = pickText(['教师', '老师']);
      var position = pickText(['教室', '地点']).replace(/\[\s*\d+\s*-\s*\d+\s*\]\s*节?$/, '').trim();

      output.push({
        name: name,
        teacher: teacher,
        position: position,
        day: day,
        weeks: parsed.weeks,
        sections: parsed.sections,
        score:
          (teacher ? 4 : 0) +
          (/\[[^\]]*\]/.test(timeText) ? 3 : 0) +
          (position ? 1 : 0) +
          (parsed.sections.length > 1 ? 1 : 0),
      });
    });
  }

  function mergeCellCandidates(candidates) {
    var groups = {};
    var order = [];
    candidates.forEach(function (item) {
      var key = item.name + '|' + item.weeks.join(',') + '|' + item.position;
      if (groups[key] === undefined) {
        groups[key] = item;
        order.push(key);
      } else if (item.score > groups[key].score) {
        groups[key] = item;
      }
    });

    var courses = [];
    order.forEach(function (key) {
      var item = groups[key];
      if (item.sections.length === 0) return;
      courses.push({
        name: item.name,
        teacher: item.teacher || '未知教师',
        position: item.position || '未知地点',
        day: item.day,
        weeks: item.weeks,
        startSection: item.sections[0],
        endSection: item.sections[item.sections.length - 1],
      });
    });
    return courses;
  }

  function parseTimetable(doc) {
    var table = findTimetableTable(doc);
    if (!table) return [];

    var courses = [];
    Array.from(table.querySelectorAll('tr')).forEach(function (row) {
      var label = row.querySelector('th');
      var labelText = label ? text(label.textContent) : '';
      var labelMatch = labelText.match(/(\d+)\s*[~～\-—至到]\s*(\d+)/);
      var singleMatch = labelText.match(/第\s*(\d+)\s*节/);
      var rowSections = labelMatch
        ? [parseInt(labelMatch[1], 10), parseInt(labelMatch[2], 10)]
        : singleMatch
          ? [parseInt(singleMatch[1], 10), parseInt(singleMatch[1], 10)]
          : null;

      var cells = Array.from(row.querySelectorAll('td'));
      var dayOffset = label ? 1 : cells.length <= 7 ? 1 : 0;
      cells.forEach(function (cell, index) {
        var blocks = cell.querySelectorAll('div.kbcontent, div.kbcontent1');
        if (blocks.length === 0) return;
        var candidates = [];
        Array.from(blocks).forEach(function (block) {
          collectCellCandidates(block, index + dayOffset, candidates, rowSections);
        });
        mergeCellCandidates(candidates).forEach(function (course) {
          courses.push(course);
        });
      });
    });
    return courses;
  }

  function mergeAndDistinctCourses(courses) {
    if (!Array.isArray(courses) || courses.length <= 1) return courses;

    var list = courses.map(function (course) {
      return Object.assign({}, course, {
        name: course.name || '',
        teacher: course.teacher || '',
        position: course.position || '',
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
        (a.day || 0) - (b.day || 0) ||
        a.weeks.join(',').localeCompare(b.weeks.join(',')) ||
        (a.startSection || 0) - (b.startSection || 0)
      );
    });

    var step1Merged = [];
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
        step1Merged.push(current);
        current = next;
      }
    }
    step1Merged.push(current);

    step1Merged.sort(function (a, b) {
      return (
        a.name.localeCompare(b.name) ||
        a.teacher.localeCompare(b.teacher) ||
        a.position.localeCompare(b.position) ||
        (a.day || 0) - (b.day || 0) ||
        (a.startSection || 0) - (b.startSection || 0) ||
        (a.endSection || 0) - (b.endSection || 0)
      );
    });

    var step2Merged = [];
    var merged = step1Merged[0];
    for (var j = 1; j < step1Merged.length; j++) {
      var following = step1Merged[j];
      var sameCourseAndSection =
        merged.name === following.name &&
        merged.teacher === following.teacher &&
        merged.position === following.position &&
        merged.day === following.day &&
        merged.startSection === following.startSection &&
        merged.endSection === following.endSection;
      if (sameCourseAndSection) {
        merged.weeks = Array.from(
          new Set(merged.weeks.concat(following.weeks))
        ).sort(function (a, b) {
          return a - b;
        });
      } else {
        step2Merged.push(merged);
        merged = following;
      }
    }
    step2Merged.push(merged);
    return step2Merged;
  }

  function toDate(value) {
    var match = text(value).match(/(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})/);
    if (!match) return null;
    var month = String(match[2]).padStart(2, '0');
    var day = String(match[3]).padStart(2, '0');
    return match[1] + '-' + month + '-' + day;
  }

  function parseCalendar(doc) {
    var result = { semesterStartDate: null, totalWeeks: null };
    var table = doc.querySelector('table');
    if (!table) return result;

    Array.from(table.querySelectorAll('tr')).forEach(function (row) {
      var cells = Array.from(row.children);
      if (cells.length < 2) return;
      var first = text(cells[0].textContent);
      var week = parseInt(first, 10);
      if (!Number.isInteger(week) || week < 1) return;
      result.totalWeeks = result.totalWeeks === null ? week : Math.max(result.totalWeeks, week);
      if (week === 1 && !result.semesterStartDate) {
        result.semesterStartDate =
          toDate(cells[1].getAttribute('title')) || toDate(cells[1].textContent);
      }
    });
    return result;
  }

  async function fetchTimetable(base, semester, kbjcmsid) {
    var body =
      'jx0404id=&cj0701id=&zc=&demo=&xnxq01id=' +
      encodeURIComponent(semester) +
      '&sfFD=1&wkbkc=1';
    if (kbjcmsid) body += '&kbjcmsid=' + encodeURIComponent(kbjcmsid);
    var html = await requestText(jsxsdUrl(base, '/xskb/xskb_list.do'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: body,
    });
    return parseDocument(html);
  }

  async function fetchCalendar(base, semester) {
    var html = await requestText(jsxsdUrl(base, '/jxzl/jxzl_query'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: 'xnxq01id=' + encodeURIComponent(semester) + '&sfFD=1',
    });
    return parseCalendar(parseDocument(html));
  }

  async function run() {
    var base = resolveBase();
    if (!base) {
      await alertUser(
        '请先进入教务课表页面',
        '当前页面不是强智教务系统。请登录后进入「课表查询 / 个人课表」页面，再点击执行导入。'
      );
      cancelImport();
      return;
    }

    try {
      toast('正在读取强智教务学期信息…');
      var listHtml = await requestText(jsxsdUrl(base, '/xskb/xskb_list.do'));
      var listDoc = parseDocument(listHtml);
      var semesters = parseSemesters(listDoc);
      if (semesters.length === 0) {
        throw new Error('未获取到学期列表，请确认已登录且课表页面可以正常打开');
      }

      var semesters_ = semesters;
      var defaultIndex = 0;
      semesters_.forEach(function (item, index) {
        if (item.selected) defaultIndex = index;
      });
      var picked = defaultIndex;
      if (semesters_.length > 1) {
        var choice = await bridge.showSingleSelection(
          '选择学期',
          semesters_.map(function (item) {
            return item.label;
          }),
          defaultIndex
        );
        if (choice === null || choice === undefined) {
          toast('导入已取消');
          cancelImport();
          return;
        }
        picked = Number(choice);
        if (!Number.isInteger(picked) || picked < 0 || picked >= semesters_.length) {
          picked = defaultIndex;
        }
      }

      var semester = semesters_[picked];
      toast('正在读取 ' + semester.label + ' 课表…');
      var tableDoc = await fetchTimetable(base, semester.value, parseKbjcmsid(listDoc));
      var courses = mergeAndDistinctCourses(parseTimetable(tableDoc));
      if (courses.length === 0) {
        throw new Error(
          semester.label + ' 没有解析到课程，该学期课表可能尚未发布或页面结构不受支持'
        );
      }

      await bridge.saveImportedCourses(JSON.stringify(courses));

      try {
        var calendar = await fetchCalendar(base, semester.value);
        var maxWeek = 0;
        courses.forEach(function (course) {
          course.weeks.forEach(function (week) {
            if (week > maxWeek) maxWeek = week;
          });
        });
        if (calendar.semesterStartDate || calendar.totalWeeks || maxWeek) {
          await bridge.saveCourseConfig(
            JSON.stringify({
              semesterStartDate: calendar.semesterStartDate,
              semesterTotalWeeks: calendar.totalWeeks || maxWeek,
            })
          );
        }
        if (!calendar.semesterStartDate) {
          toast('未读取到开学日期，请在课表设置中确认');
        }
      } catch (_) {
        toast('课表已读取，但学期日期读取失败，请在课表设置中确认');
      }

      toast('已读取 ' + courses.length + ' 条课程，请确认作息时间');
      nativeBridge.notifyTaskCompletion();
    } catch (error) {
      await alertUser(
        '强智教务导入失败',
        String((error && error.message) || error) +
          '\n\n当前网址：' +
          (window.location.href || '')
      );
      cancelImport();
    }
  }

  if (globalThis.__QIANGZHI_TEST__) {
    globalThis.__QIANGZHI_TEST__.parseWeeksAndSections = parseWeeksAndSections;
    globalThis.__QIANGZHI_TEST__.parseTimetable = parseTimetable;
    globalThis.__QIANGZHI_TEST__.parseCalendar = parseCalendar;
    globalThis.__QIANGZHI_TEST__.parseSemesters = parseSemesters;
    globalThis.__QIANGZHI_TEST__.mergeAndDistinctCourses = mergeAndDistinctCourses;
    return;
  }

  run();
})();
''';
