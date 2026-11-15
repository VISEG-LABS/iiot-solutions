import * as echarts from '../vendor/echarts/6.1.0/echarts.esm.min.js';
import { displayNumber, displayTime } from './formatters.js';

export function mount(element, tableBody, culture, initialDays) {
    const chart = echarts.init(element, null, { renderer: 'svg' });
    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const css = getComputedStyle(document.body);
    const token = name => css.getPropertyValue(name).trim();
    function setRange(days) {
        const end = Date.UTC(2026, 10, 15, 12, 0);
        const data = Array.from({ length: 97 }, (_, index) => {
            const time = end - days * 86400000 + index * days * 900000;
            return [time, +(62 + Math.sin(index / 9) * 3 + Math.cos(index / 3.7) * 0.7 + Math.exp(-((index - 61) ** 2) / 130) * 7).toFixed(2),
                +(57 + Math.sin(index / 10 + 0.8) * 2 + Math.cos(index / 4.8) * 0.4).toFixed(2)];
        });
        chart.setOption({
            animation: !matchMedia('(prefers-reduced-motion: reduce)').matches,
            animationDuration: 180,
            color: [token('--chart-series-1'), token('--chart-series-2')],
            grid: { top: 22, left: 42, right: 18, bottom: 34 },
            tooltip: { trigger: 'axis', renderMode: 'richText', backgroundColor: token('--surface-panel'), borderColor: token('--border-default'),
                textStyle: { color: token('--text-primary'), fontSize: 11 }, valueFormatter: value => displayNumber(value, culture) },
            xAxis: { type: 'time', min: data[0][0], max: end, splitNumber: 6, axisLine: { show: false }, axisTick: { show: false },
                axisLabel: { color: token('--text-secondary'), fontSize: 10, formatter: value => new Intl.DateTimeFormat(culture, { timeZone, ...(days === 1 ? { hour: '2-digit', minute: '2-digit' } : { month: 'short', day: 'numeric' }) }).format(new Date(value)) }, splitLine: { show: false } },
            yAxis: { type: 'value', min: 50, max: 75, splitNumber: 5, axisLabel: { color: token('--text-secondary'), fontSize: 10, formatter: value => displayNumber(value, culture, 0) },
                splitLine: { lineStyle: { color: token('--chart-grid'), type: 'dashed' } } },
            series: [0, 1].map(index => ({ type: 'line', showSymbol: false, smooth: 0.25, data: data.map(row => [row[0], row[index + 1]]),
                lineStyle: { width: index === 0 ? 2.3 : 1.7, type: index === 0 ? 'solid' : 'dashed' } }))
        }, true);
        tableBody.replaceChildren(...data.filter((_, index) => index % 16 === 0).map(row => {
            const tr = document.createElement('tr');
            [displayTime(row[0], culture, timeZone), displayNumber(row[1], culture), displayNumber(row[2], culture)].forEach(value => {
                const td = document.createElement('td'); td.textContent = value; tr.append(td);
            });
            return tr;
        }));
        element.dataset.ready = 'true';
        element.dataset.days = String(days);
        element.dataset.timeZone = timeZone;
    }
    const observer = new ResizeObserver(() => chart.resize());
    observer.observe(element);
    setRange(initialDays);
    return { setRange, dispose() { observer.disconnect(); chart.dispose(); } };
}
