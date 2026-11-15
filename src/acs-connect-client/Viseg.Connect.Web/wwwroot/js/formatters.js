export function displayNumber(value, culture, digits = 1) {
    return new Intl.NumberFormat(culture, { maximumFractionDigits: digits, minimumFractionDigits: digits }).format(value);
}

export function displayTime(utcValue, culture, timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone) {
    return new Intl.DateTimeFormat(culture, { timeZone, hour: '2-digit', minute: '2-digit', month: 'short', day: 'numeric' }).format(new Date(utcValue));
}
