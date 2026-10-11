const ritualPwaBase = new URL('./', document.currentScript.src);
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    const base = ritualPwaBase;
    navigator.serviceWorker.register(new URL('sw.js', base), { scope: base.pathname })
      .catch(error => console.warn('Ritual One offline setup failed:', error));
  });
}
