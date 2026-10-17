const status = document.querySelector('#status');
const trainingCalendar = document.querySelector('#training-calendar');
const calendarEmpty = document.querySelector('#empty-calendar');
const chartTooltip = document.querySelector('#chart-tooltip');
const activityTotal = document.querySelector('#activity-total');
const updatedAt = document.querySelector('#updated-at');
const ns = 'http://www.w3.org/2000/svg';
const ranges = { '1m': 1, '6m': 6, '1y': 12, all: null };
const lifts = [
  { key: 'squat', name: 'Squat' },
  { key: 'bench', name: 'Bench press' },
  { key: 'deadlift', name: 'Deadlift' },
  { key: 'overhead', name: 'Overhead press' },
];
let progressData;
let activeRange = '6m';
let volumeCutoffs = [];

const viewTabs = [...document.querySelectorAll('[role="tab"]')];

function activateTab(tab, focus = false) {
  for (const item of viewTabs) {
    const selected = item === tab;
    item.setAttribute('aria-selected', String(selected));
    item.tabIndex = selected ? 0 : -1;
    document.querySelector(`#${item.getAttribute('aria-controls')}`).hidden = !selected;
  }
  if (tab.id === 'tab-strength') drawStrengthCharts();
  if (focus) tab.focus();
}

viewTabs.forEach((tab, index) => {
  tab.addEventListener('click', () => activateTab(tab));
  tab.addEventListener('keydown', event => {
    let nextIndex;
    if (event.key === 'ArrowRight') nextIndex = (index + 1) % viewTabs.length;
    else if (event.key === 'ArrowLeft') nextIndex = (index - 1 + viewTabs.length) % viewTabs.length;
    else if (event.key === 'Home') nextIndex = 0;
    else if (event.key === 'End') nextIndex = viewTabs.length - 1;
    else return;
    event.preventDefault();
    activateTab(viewTabs[nextIndex], true);
  });
});

function element(name, attributes = {}, parent) {
  const node = document.createElementNS(ns, name);
  for (const [key, value] of Object.entries(attributes)) node.setAttribute(key, value);
  parent?.append(node);
  return node;
}

function formatDate(value, options = { year: 'numeric', month: 'short', day: 'numeric' }) {
  return new Intl.DateTimeFormat(undefined, options).format(new Date(`${value}T12:00:00`));
}

function makeSvg(svg, { width, height, title, description }) {
  svg.replaceChildren();
  svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  svg.setAttribute('width', width);
  svg.setAttribute('height', height);
  svg.removeAttribute('aria-labelledby');
  svg.setAttribute('aria-label', title);
  svg.setAttribute('aria-description', description);
}

function rangeStart(range = activeRange) {
  const months = ranges[range];
  if (months === null) return null;
  const cutoff = new Date();
  cutoff.setUTCHours(0, 0, 0, 0);
  const day = cutoff.getUTCDate();
  cutoff.setUTCDate(1);
  cutoff.setUTCMonth(cutoff.getUTCMonth() - months);
  const lastDay = new Date(Date.UTC(cutoff.getUTCFullYear(), cutoff.getUTCMonth() + 1, 0)).getUTCDate();
  cutoff.setUTCDate(Math.min(day, lastDay));
  return cutoff.toISOString().slice(0, 10);
}

function inRange(date, start) {
  return !start || date >= start;
}

function estimated1rm(point) {
  return point.estimated1RmKg;
}

function formatKg(value) {
  return `${Number(value.toFixed(1))} kg`;
}

function workoutVolume(day) {
  return day.exercises.reduce((total, exercise) => total + exercise.sets.reduce((sum, set) => sum + Math.max(0, set.weightKg) * set.reps, 0), 0);
}

function volumeQuartiles(days) {
  const values = days.map(workoutVolume).filter(value => value > 0).sort((a, b) => a - b);
  if (!values.length) return [];
  return [.25, .5, .75].map(quantile => values[Math.ceil(values.length * quantile) - 1]);
}

function showChartTooltip(target, x, y) {
  chartTooltip.replaceChildren();
  chartTooltip.classList.remove('workout-tooltip');
  chartTooltip.classList.remove('strength-tooltip');
  chartTooltip.classList.remove('strength-tooltip-estimated');
  if (target.dataset.workoutSummary) {
    const day = JSON.parse(target.dataset.workoutSummary);
    chartTooltip.classList.add('workout-tooltip');

    const heading = document.createElement('strong');
    heading.className = 'workout-tooltip-date';
    heading.textContent = formatDate(day.date, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
    chartTooltip.append(heading);

    const totals = document.createElement('div');
    totals.className = 'workout-tooltip-totals';
    for (const value of [
      `${day.workouts} workout${day.workouts === 1 ? '' : 's'}`,
      `${day.sets} sets`,
      `${day.reps} reps`,
      `${Math.round(workoutVolume(day)).toLocaleString()} kg·reps`,
    ]) {
      const chip = document.createElement('span');
      chip.textContent = value;
      totals.append(chip);
    }
    chartTooltip.append(totals);

    if (day.exercises.length) {
      const details = document.createElement('div');
      details.className = 'workout-tooltip-exercises';
      for (const exercise of day.exercises) {
        const section = document.createElement('section');
        section.className = 'workout-tooltip-exercise';
        const name = document.createElement('h4');
        name.textContent = exercise.name;
        section.append(name);

        const groupedSets = new Map();
        for (const set of exercise.sets) {
          const key = `${set.reps}|${set.weightKg}`;
          groupedSets.set(key, (groupedSets.get(key) ?? 0) + 1);
        }
        for (const [key, count] of groupedSets) {
          const [reps, weight] = key.split('|').map(Number);
          const row = document.createElement('div');
          row.className = 'workout-tooltip-set';
          const prescription = document.createElement('span');
          prescription.textContent = `${count} ${count === 1 ? 'set' : 'sets'} x ${reps} reps`;
          const load = document.createElement('span');
          load.textContent = weight > 0 ? `${formatKg(weight)}` : 'Bodyweight';
          row.append(prescription, load);
          section.append(row);
        }
        details.append(section);
      }
      chartTooltip.append(details);
    } else {
      const empty = document.createElement('p');
      empty.className = 'workout-tooltip-empty';
      empty.textContent = 'No working sets recorded.';
      chartTooltip.append(empty);
    }
  } else if (target.dataset.strengthSummary) {
    const point = JSON.parse(target.dataset.strengthSummary);
    chartTooltip.classList.add('strength-tooltip');
    if (point.kind === 'estimated') chartTooltip.classList.add('strength-tooltip-estimated');

    const date = document.createElement('span');
    date.className = 'strength-tooltip-date';
    date.textContent = formatDate(point.date, { weekday: 'short', year: 'numeric', month: 'long', day: 'numeric' });
    const label = document.createElement('span');
    label.className = 'strength-tooltip-label';
    label.textContent = point.kind === 'estimated' ? 'Estimated 1RM' : 'Working set';
    const value = document.createElement('strong');
    value.className = 'strength-tooltip-value';
    value.textContent = formatKg(point.kind === 'estimated' ? point.estimated1RmKg : point.weightKg);
    const detail = document.createElement('span');
    detail.className = 'strength-tooltip-detail';
    detail.textContent = point.kind === 'estimated'
      ? `Epley estimate from ${formatKg(point.weightKg)} x ${point.reps} reps`
      : `${point.reps} reps`;
    chartTooltip.append(date, label, value, detail);
  } else {
    chartTooltip.textContent = target.dataset.tooltip;
  }
  chartTooltip.hidden = false;
  positionChartTooltip(x, y);
}

function positionChartTooltip(x, y) {
  const bounds = chartTooltip.getBoundingClientRect();
  chartTooltip.style.left = `${Math.max(8, Math.min(x + 12, window.innerWidth - bounds.width - 8))}px`;
  chartTooltip.style.top = `${Math.max(8, Math.min(y + 12, window.innerHeight - bounds.height - 8))}px`;
}

const tooltipTarget = target => target?.closest?.('[data-tooltip], [data-workout-summary], [data-strength-summary]');
const tooltipDelayMs = 120;
let tooltipTimer;
let pendingTooltipTarget;
let visibleTooltipTarget;
let pendingTooltipPosition;

function closePointerTooltip(target, force = false) {
  if (target === pendingTooltipTarget) {
    clearTimeout(tooltipTimer);
    pendingTooltipTarget = undefined;
    tooltipTimer = undefined;
  }
  if (target === visibleTooltipTarget && (force || !target.matches(':focus-visible'))) {
    chartTooltip.hidden = true;
    visibleTooltipTarget = undefined;
  }
}

document.addEventListener('pointerover', event => {
  const target = tooltipTarget(event.target);
  if (!target || target === visibleTooltipTarget || target === pendingTooltipTarget) return;
  clearTimeout(tooltipTimer);
  pendingTooltipTarget = target;
  pendingTooltipPosition = { x: event.clientX, y: event.clientY };
  tooltipTimer = setTimeout(() => {
    if (pendingTooltipTarget !== target) return;
    showChartTooltip(target, pendingTooltipPosition.x, pendingTooltipPosition.y);
    visibleTooltipTarget = target;
    pendingTooltipTarget = undefined;
    tooltipTimer = undefined;
  }, tooltipDelayMs);
});

document.addEventListener('pointermove', event => {
  const target = tooltipTarget(event.target);
  if (visibleTooltipTarget?.matches?.('[data-strength-summary]')
      && target !== visibleTooltipTarget) {
    closePointerTooltip(visibleTooltipTarget, true);
  }
  if (!target) return;
  if (target === pendingTooltipTarget) pendingTooltipPosition = { x: event.clientX, y: event.clientY };
  if (target === visibleTooltipTarget) positionChartTooltip(event.clientX, event.clientY);
});

document.addEventListener('pointerout', event => {
  const from = tooltipTarget(event.target);
  const to = tooltipTarget(event.relatedTarget);
  const enteringTooltip = event.relatedTarget === chartTooltip || chartTooltip.contains(event.relatedTarget);
  if (!from || from === to || enteringTooltip) return;
  closePointerTooltip(from, true);
});

chartTooltip.addEventListener('pointerleave', () => {
  chartTooltip.hidden = true;
  visibleTooltipTarget = undefined;
});

document.addEventListener('focusin', event => {
  const target = tooltipTarget(event.target);
  if (!target) return;
  clearTimeout(tooltipTimer);
  pendingTooltipTarget = undefined;
  tooltipTimer = undefined;
  const bounds = target.getBoundingClientRect();
  showChartTooltip(target, bounds.left + bounds.width / 2, bounds.top + bounds.height / 2);
  visibleTooltipTarget = target;
});

document.addEventListener('focusout', event => {
  if (tooltipTarget(event.target) === visibleTooltipTarget) {
    chartTooltip.hidden = true;
    visibleTooltipTarget = undefined;
  }
});

function daysInRange(days) {
  const start = rangeStart();
  return days.filter(day => inRange(day.date, start));
}

function calendarDay(date, daySummary, rangeStartDate, currentDate) {
  const cell = document.createElement('div');
  const dayNumber = document.createElement('span');
  dayNumber.className = 'calendar-day-number';
  dayNumber.textContent = String(date.getUTCDate());
  cell.append(dayNumber);

  const key = date.toISOString().slice(0, 10);
  const summary = daySummary.get(key);
  if (summary) {
    const volume = workoutVolume(summary);
    const level = volumeCutoffs.reduce((current, cutoff) => current + (volume > cutoff ? 1 : 0), 1);
    const counts = document.createElement('span');
    counts.className = 'calendar-day-counts';
    counts.textContent = `${summary.sets}/${summary.reps}`;
    cell.className = 'calendar-day has-workout';
    cell.dataset.level = String(level);
    cell.dataset.workoutSummary = JSON.stringify(summary);
    cell.setAttribute('role', 'img');
    cell.setAttribute('aria-label', `${formatDate(key)}: ${summary.workouts} workout${summary.workouts === 1 ? '' : 's'}, ${summary.sets} working sets, ${summary.reps} reps`);
    cell.tabIndex = 0;
    cell.append(counts);
  } else {
    cell.className = 'calendar-day';
    cell.dataset.level = '0';
    cell.setAttribute('aria-hidden', 'true');
  }
  if (key < rangeStartDate || key > currentDate) cell.classList.add('outside-range');
  return cell;
}

function renderCalendar(days) {
  trainingCalendar.replaceChildren();
  calendarEmpty.hidden = days.length > 0;
  const sets = days.reduce((total, day) => total + day.sets, 0);
  const reps = days.reduce((total, day) => total + day.reps, 0);
  activityTotal.textContent = `${sets} sets / ${reps} reps`;
  if (!days.length) return;

  const daysByDate = new Map(days.map(day => [day.date, day]));
  const currentDate = new Date().toISOString().slice(0, 10);
  const startString = rangeStart() ?? days[0].date;
  const firstWeek = new Date(`${startString}T00:00:00Z`);
  firstWeek.setUTCDate(firstWeek.getUTCDate() - (firstWeek.getUTCDay() + 6) % 7);
  const lastWeek = new Date(`${currentDate}T00:00:00Z`);
  lastWeek.setUTCDate(lastWeek.getUTCDate() - (lastWeek.getUTCDay() + 6) % 7);
  const monthFormatter = new Intl.DateTimeFormat(undefined, { month: 'long', year: 'numeric', timeZone: 'UTC' });

  const header = document.createElement('div');
  header.className = 'calendar-header';
  const labelSpacer = document.createElement('span');
  labelSpacer.setAttribute('aria-hidden', 'true');
  header.append(labelSpacer);
  for (const weekday of ['M', 'T', 'W', 'T', 'F', 'S', 'S']) {
    const label = document.createElement('span');
    label.className = 'calendar-weekday';
    label.setAttribute('aria-hidden', 'true');
    label.textContent = weekday;
    header.append(label);
  }
  trainingCalendar.append(header);

  const monthGroups = [];
  for (const weekStart = new Date(firstWeek); weekStart <= lastWeek; weekStart.setUTCDate(weekStart.getUTCDate() + 7)) {
    const weekEnd = new Date(weekStart);
    weekEnd.setUTCDate(weekEnd.getUTCDate() + 6);
    const monthKey = `${weekEnd.getUTCFullYear()}-${weekEnd.getUTCMonth()}`;
    let group = monthGroups.at(-1);
    if (!group || group.key !== monthKey) {
      group = { key: monthKey, label: monthFormatter.format(weekEnd), weeks: [] };
      monthGroups.push(group);
    }

    const week = [];
    for (let day = 0; day < 7; day += 1) {
      const date = new Date(weekStart);
      date.setUTCDate(date.getUTCDate() + day);
      week.push(calendarDay(date, daysByDate, startString, currentDate));
    }
    group.weeks.push(week);
  }

  monthGroups.reverse();
  for (const group of monthGroups) {
    const monthSection = document.createElement('section');
    monthSection.className = 'calendar-month';
    monthSection.style.gridTemplateRows = `repeat(${group.weeks.length}, minmax(2.55rem, auto))`;
    monthSection.setAttribute('aria-label', group.label);
    const monthLabel = document.createElement('span');
    monthLabel.className = 'calendar-month-label';
    monthLabel.style.gridRow = `1 / span ${group.weeks.length}`;
    monthLabel.textContent = group.label;
    monthSection.append(monthLabel);

    const weeks = document.createElement('div');
    weeks.className = 'calendar-weeks';
    for (const daysInWeek of group.weeks.reverse()) {
      const row = document.createElement('div');
      row.className = 'calendar-week';
      for (const day of daysInWeek) row.append(day);
      weeks.append(row);
    }
    monthSection.append(weeks);
    trainingCalendar.append(monthSection);
  }
}

function drawStrengthDateLabels(svg, { firstTime, lastTime, span, chartWidth, left, height, pointCount }) {
  const spanDays = (lastTime - firstTime) / 86400000;
  const addLabel = (time, options) => {
    const date = new Date(time);
    const x = left + (time - firstTime) / span * chartWidth;
    const label = element('text', { x, y: height - 12, 'text-anchor': 'middle', class: 'axis-label' }, svg);
    label.textContent = formatDate(date.toISOString().slice(0, 10), options);
  };

  if (pointCount === 1 || spanDays < 7) {
    addLabel(firstTime, { month: 'short', day: 'numeric', year: '2-digit' });
    return;
  }

  if (spanDays <= 70) {
    const tick = new Date(firstTime);
    tick.setUTCHours(12, 0, 0, 0);
    tick.setUTCDate(tick.getUTCDate() + (8 - tick.getUTCDay()) % 7);
    while (tick.getTime() <= lastTime) {
      addLabel(tick.getTime(), { month: 'short', day: 'numeric' });
      tick.setUTCDate(tick.getUTCDate() + 7);
    }
    return;
  }

  const monthInterval = spanDays > 730 ? 3 : 1;
  const tick = new Date(firstTime);
  tick.setUTCHours(12, 0, 0, 0);
  tick.setUTCDate(1);
  if (tick.getTime() < firstTime) tick.setUTCMonth(tick.getUTCMonth() + 1);
  while (tick.getTime() <= lastTime) {
    if (tick.getUTCMonth() % monthInterval === 0) {
      addLabel(tick.getTime(), { month: 'short', year: spanDays > 330 ? '2-digit' : undefined });
    }
    tick.setUTCMonth(tick.getUTCMonth() + 1);
  }
}

function createLiftStat(labelText, valueText, detailText, variant = '') {
  const card = document.createElement('div');
  card.className = `lift-stat ${variant}`.trim();
  const label = document.createElement('span');
  label.className = 'lift-stat-label';
  label.textContent = labelText;
  const value = document.createElement('strong');
  value.className = 'lift-stat-value';
  value.textContent = valueText;
  const detail = document.createElement('span');
  detail.className = 'lift-stat-detail';
  detail.textContent = detailText;
  card.append(label, value, detail);
  return card;
}

function drawStrengthChart(lift, exercises) {
  const svg = document.querySelector(`#strength-${lift.key}`);
  const summary = document.querySelector(`#summary-${lift.key}`);
  const empty = document.querySelector(`#empty-${lift.key}`);
  const start = rangeStart();
  const points = (exercises.find(exercise => exercise.name === lift.name)?.points ?? [])
    .filter(point => inRange(point.date, start));
  if (!points.length) {
    svg.replaceChildren();
    summary.replaceChildren();
    empty.hidden = false;
    return;
  }
  empty.hidden = true;

  const width = svg.parentElement.clientWidth || 720;
  const height = 300;
  const left = 54;
  const right = 22;
  const top = 18;
  const bottom = 46;
  const chartWidth = width - left - right;
  const chartHeight = height - top - bottom;
  const maxWeight = Math.max(...points.flatMap(point => [point.weightKg, estimated1rm(point)]));
  const max = Math.max(10, Math.ceil(maxWeight / 10) * 10);
  const firstTime = new Date(`${points[0].date}T12:00:00`).getTime();
  const lastTime = new Date(`${points.at(-1).date}T12:00:00`).getTime();
  const span = Math.max(1, lastTime - firstTime);
  const coordinates = points.map(point => {
    const x = left + (new Date(`${point.date}T12:00:00`).getTime() - firstTime) / span * chartWidth;
    return {
      point,
      x,
      weightY: top + chartHeight - point.weightKg / max * chartHeight,
      estimatedY: top + chartHeight - estimated1rm(point) / max * chartHeight,
    };
  });

  makeSvg(svg, {
    width,
    height,
    title: `${lift.name} working-set and estimated 1RM trend`,
    description: `${points.length} completed working-set records, measured in kilograms. The solid line shows working-set weight and the dashed line shows Epley estimated one-rep max from the set weight and repetitions.`,
  });

  for (let tick = 0; tick <= 4; tick += 1) {
    const value = max * tick / 4;
    const y = top + chartHeight - chartHeight * tick / 4;
    element('line', { x1: left, x2: width - right, y1: y, y2: y, class: 'axis' }, svg);
    const label = element('text', { x: left - 9, y: y + 4, 'text-anchor': 'end', class: 'axis-label' }, svg);
    label.textContent = `${value} kg`;
  }

  drawStrengthDateLabels(svg, { firstTime, lastTime, span, chartWidth, left, height, pointCount: points.length });
  const workingSetLine = coordinates.map(point => `${point.x},${point.weightY}`).join(' ');
  const estimatedLine = coordinates.map(point => `${point.x},${point.estimatedY}`).join(' ');
  element('polyline', { points: workingSetLine, class: 'strength-line' }, svg);
  element('polyline', { points: estimatedLine, class: 'estimated-line' }, svg);
  coordinates.forEach(({ point, x, weightY, estimatedY }) => {
    const workingTooltip = `${formatDate(point.date)}: working set ${formatKg(point.weightKg)} × ${point.reps}`;
    const workingPoint = element('circle', {
      cx: x, cy: weightY, r: 5, class: 'strength-point',
      'data-tooltip': workingTooltip, 'aria-label': workingTooltip, tabindex: 0,
      'data-strength-summary': JSON.stringify({ date: point.date, kind: 'working', weightKg: point.weightKg, reps: point.reps }),
    }, svg);
    workingPoint.addEventListener('pointerleave', () => closePointerTooltip(workingPoint, true));
    const estimatedTooltip = `${formatDate(point.date)}: estimated 1RM ${formatKg(estimated1rm(point))} (Epley, from ${formatKg(point.weightKg)} × ${point.reps})`;
    const estimatedPoint = element('circle', {
      cx: x, cy: estimatedY, r: 4, class: 'estimated-point',
      'data-tooltip': estimatedTooltip, 'aria-label': estimatedTooltip, tabindex: 0,
      'data-strength-summary': JSON.stringify({ date: point.date, kind: 'estimated', estimated1RmKg: estimated1rm(point), weightKg: point.weightKg, reps: point.reps }),
    }, svg);
    estimatedPoint.addEventListener('pointerleave', () => closePointerTooltip(estimatedPoint, true));
  });

  const latest = points.at(-1);
  const bestEstimate = points.reduce((best, point) => estimated1rm(point) >= estimated1rm(best) ? point : best, points[0]);
  const maxWeightSet = points.reduce((best, point) => point.weightKg > best.weightKg ? point : best, points[0]);
  summary.replaceChildren(
    createLiftStat('Latest estimated 1RM', formatKg(estimated1rm(latest)), `${formatDate(latest.date)} | from ${formatKg(latest.weightKg)} x ${latest.reps}`),
    createLiftStat('Best estimated 1RM', formatKg(estimated1rm(bestEstimate)), `${formatDate(bestEstimate.date)} | from ${formatKg(bestEstimate.weightKg)} x ${bestEstimate.reps}`, 'lift-stat-best'),
    createLiftStat('Max weight lifted', formatKg(maxWeightSet.weightKg), `${formatDate(maxWeightSet.date)} | ${maxWeightSet.reps} reps`),
  );
}

function showData(data) {
  progressData = data;
  volumeCutoffs = volumeQuartiles(data.days ?? []);
  const days = daysInRange(data.days ?? []);
  renderCalendar(days);
  drawStrengthCharts();

  if (data.generatedAtUtc) {
    updatedAt.textContent = `Generated ${new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(data.generatedAtUtc))}.`;
  }
  status.textContent = data.totalWorkouts ? '' : 'No workouts found in the generated summary yet.';
}

function drawStrengthCharts() {
  if (!progressData) return;
  for (const lift of lifts) drawStrengthChart(lift, progressData.exercises);
}

let chartResizeTimer;
window.addEventListener('resize', () => {
  clearTimeout(chartResizeTimer);
  chartResizeTimer = setTimeout(() => {
    if (!document.querySelector('#panel-strength').hidden) drawStrengthCharts();
  }, 100);
});

document.querySelectorAll('[data-range]').forEach(button => {
  button.addEventListener('click', () => {
    activeRange = button.dataset.range;
    document.querySelectorAll('[data-range]').forEach(item => {
      item.setAttribute('aria-pressed', String(item === button));
    });
    if (progressData) showData(progressData);
  });
});

try {
  const response = await fetch('./data.json', { cache: 'no-store' });
  if (!response.ok) throw new Error(`Could not load progress data (${response.status}).`);
  const data = await response.json();
  showData(data);
} catch (error) {
  status.textContent = `${error.message} Run the local generator to create the summary.`;
  status.dataset.error = 'true';
}
