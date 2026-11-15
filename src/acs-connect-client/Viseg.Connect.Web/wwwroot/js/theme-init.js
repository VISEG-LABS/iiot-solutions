// The server-rendered preference is authoritative before Fluent initializes.
(() => {
    const theme = document.documentElement.dataset.theme === 'light' ? 'light' : 'dark';
    try {
        const key = 'fluentui-blazor:theme-settings';
        const stored = JSON.parse(localStorage.getItem(key) || '{}');
        localStorage.setItem(key, JSON.stringify({ ...stored, theme, base: 'web' }));
    } catch { /* Cookies and CSS still render the correct theme when storage is unavailable. */ }
})();
