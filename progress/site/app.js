const status = document.querySelector('#status');
const weeklyChart = document.querySelector('#weekly-chart');
const weeklyEmpty = document.querySelector('#empty-weekly');
const workoutTotal = document.querySelector('#workout-total');
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
  element('title', { id: `${svg.id}-title` }, svg).textContent = title;
  element('desc', { id: `${svg.id}-desc` }, svg).textContent = description;
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

function weeksInRange(weeks) {
  const start = rangeStart();
  return weeks.filter(week => inRange(week.weekStart, start));
}

function drawWeeklyChart(weeks) {
  weeks = weeksInRange(weeks);
  weeklyEmpty.hidden = weeks.length > 0;
  if (!weeks.length) {
    weeklyChart.replaceChildren();
    return;
  }

  const width = Math.max(760, weeks.length * 13 + 64);
  const height = 230;
  const left = 34;
  const right = 12;
  const top = 12;
  const bottom = 34;
  const chartHeight = height - top - bottom;
  const chartWidth = width - left - right;
  const max = Math.max(1, ...weeks.map(week => week.workouts));
  const step = chartWidth / weeks.length;
  const barWidth = Math.max(2, step * .62);
  makeSvg(weeklyChart, {
    width,
    height,
    title: 'Workouts by week',
    description: `Weekly workout counts across ${weeks.length} weeks, from ${formatDate(weeks[0].weekStart)} to ${formatDate(weeks.at(-1).weekStart)}.`,
  });

  const tickCount = Math.min(max, 4);
  for (let tick = 0; tick <= tickCount; tick += 1) {
    const value = Math.round(max * tick / tickCount);
    const y = top + chartHeight - chartHeight * value / max;
    element('line', { x1: left, x2: width - right, y1: y, y2: y, class: 'axis' }, weeklyChart);
    const label = element('text', { x: left - 8, y: y + 4, 'text-anchor': 'end', class: 'axis-label' }, weeklyChart);
    label.textContent = String(value);
  }

  const labelEvery = Math.max(1, Math.ceil(weeks.length / 8));
  weeks.forEach((week, index) => {
    const barHeight = chartHeight * week.workouts / max;
    const x = left + index * step + (step - barWidth) / 2;
    const rect = element('rect', {
      x,
      y: top + chartHeight - barHeight,
      width: barWidth,
      height: Math.max(0, barHeight),
      rx: Math.min(3, barWidth / 3),
      class: 'bar',
    }, weeklyChart);
    element('title', {}, rect).textContent = `${formatDate(week.weekStart)}: ${week.workouts} workout${week.workouts === 1 ? '' : 's'}`;

    if (index % labelEvery === 0 || index === weeks.length - 1) {
      const label = element('text', { x: x + barWidth / 2, y: height - 10, 'text-anchor': 'middle', class: 'axis-label' }, weeklyChart);
      label.textContent = formatDate(week.weekStart, { month: 'short', year: weeks.length > 52 ? '2-digit' : undefined });
    }
  });
}

function drawStrengthChart(lift, exercises) {
  const svg = document.querySelector(`#strength-${lift.key}`);
  const latestSet = document.querySelector(`#latest-${lift.key}`);
  const empty = document.querySelector(`#empty-${lift.key}`);
  const start = rangeStart();
  const points = (exercises.find(exercise => exercise.name === lift.name)?.points ?? [])
    .filter(point => inRange(point.date, start));
  if (!points.length) {
    svg.replaceChildren();
    latestSet.textContent = '';
    empty.hidden = false;
    return;
  }
  empty.hidden = true;

  const width = Math.max(720, points.length * 26 + 60);
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

  const workingSetLine = coordinates.map(point => `${point.x},${point.weightY}`).join(' ');
  const estimatedLine = coordinates.map(point => `${point.x},${point.estimatedY}`).join(' ');
  element('polyline', { points: workingSetLine, class: 'strength-line' }, svg);
  element('polyline', { points: estimatedLine, class: 'estimated-line' }, svg);
  const labelEvery = Math.max(1, Math.ceil(points.length / 8));
  coordinates.forEach(({ point, x, weightY, estimatedY }, index) => {
    const circle = element('circle', { cx: x, cy: weightY, r: 5, class: 'strength-point' }, svg);
    element('title', {}, circle).textContent = `${formatDate(point.date)}: working set ${formatKg(point.weightKg)} × ${point.reps}`;
    const estimate = element('circle', { cx: x, cy: estimatedY, r: 4, class: 'estimated-point' }, svg);
    element('title', {}, estimate).textContent = `${formatDate(point.date)}: estimated 1RM ${formatKg(estimated1rm(point))} (Epley, from ${formatKg(point.weightKg)} × ${point.reps})`;
    if (index % labelEvery === 0 || index === points.length - 1) {
      const label = element('text', { x, y: height - 12, 'text-anchor': 'middle', class: 'axis-label' }, svg);
      label.textContent = formatDate(point.date, { month: 'short', day: 'numeric', year: points.length > 20 ? '2-digit' : undefined });
    }
  });

  const latest = points.at(-1);
  latestSet.textContent = `Latest: ${formatDate(latest.date)} | ${formatKg(latest.weightKg)} x ${latest.reps} | estimated 1RM ${formatKg(estimated1rm(latest))}`;
}

function showData(data) {
  progressData = data;
  const weeks = weeksInRange(data.weeks);
  const visibleWorkouts = weeks.reduce((total, week) => total + week.workouts, 0);
  workoutTotal.textContent = `${visibleWorkouts} workout${visibleWorkouts === 1 ? '' : 's'}`;
  drawWeeklyChart(weeks);
  for (const lift of lifts) drawStrengthChart(lift, data.exercises);

  if (data.generatedAtUtc) {
    updatedAt.textContent = `Generated ${new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(data.generatedAtUtc))}.`;
  }
  status.textContent = data.totalWorkouts ? '' : 'No workouts found in the generated summary yet.';
}

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
