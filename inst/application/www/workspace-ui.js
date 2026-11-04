/* workspace-ui.js (SPEC-WS-013). Display state only: the narrow menu, notification
 * dismissal and the job panel summary. It reads the DOM, writes text with
 * textContent, never uses eval and never inserts user text as HTML. */
(function () {
  'use strict';

  var NARROW = 767;
  var SUCCESS_HIDE_MS = 5000;

  function narrow() {
    return window.innerWidth <= NARROW;
  }

  /* F12: the slide-in menu closes once a destination is chosen. */
  function closeMenu() {
    if (narrow() && document.body.classList.contains('sidebar-open')) {
      document.body.classList.remove('sidebar-open');
    }
  }

  document.addEventListener('click', function (event) {
    var link = event.target.closest && event.target.closest('.main-sidebar .sidebar-menu a[data-toggle="tab"]');
    if (link) closeMenu();
  }, true);

  if (window.jQuery) {
    window.jQuery(document).on('shown.bs.tab', 'a[data-toggle="tab"]', function () {
      closeMenu();
      clearErrors();
    });
  }

  /* F13: an error notification does not follow the user to another step. */
  function removeNotification(node) {
    var id = node.id ? node.id.replace(/^shiny-notification-/, '') : '';
    if (id && window.Shiny && window.Shiny.notifications && window.Shiny.notifications.remove) {
      window.Shiny.notifications.remove(id);
    }
    if (node.parentNode) node.parentNode.removeChild(node);
  }

  function clearErrors() {
    var errors = document.querySelectorAll('.shiny-notification-error');
    Array.prototype.forEach.call(errors, removeNotification);
  }

  /* F13: success and information notifications hide by themselves. */
  var scheduled = typeof WeakSet === 'function' ? new WeakSet() : null;
  function scheduleHide(node) {
    if (!scheduled || scheduled.has(node)) return;
    if (node.classList.contains('shiny-notification-error')) return;
    scheduled.add(node);
    window.setTimeout(function () { removeNotification(node); }, SUCCESS_HIDE_MS);
  }

  /* F1: the job panel summarises itself in one line, stays collapsed while no job is
   * queued or running and opens for a new run (CSS hides it while there is no job). */
  var activeBefore = 0;
  var userTouched = false;
  function refreshJobs() {
    var panel = document.querySelector('section[aria-label="Analysis jobs"] .rs-jobs-disclosure');
    if (!panel) return;
    var rows = panel.querySelectorAll('.rs-job');
    var active = panel.querySelectorAll(
      '.rs-job[data-state="queued"], .rs-job[data-state="running"], .rs-job[data-state="cancel_requested"]').length;
    var summary = panel.querySelector('.rs-jobs-summary');
    if (!rows.length) {
      if (panel.open) panel.open = false;
      activeBefore = 0;
      userTouched = false;
      return;
    }
    var text = 'Analysis jobs: ' + rows.length;
    if (active) text += ' (' + active + ' running or queued)';
    if (summary && summary.textContent !== text) summary.textContent = text;
    if (active > activeBefore) {
      /* A new run opens the panel and hands it back to the automatic behaviour. */
      userTouched = false;
      if (!panel.open) panel.open = true;
    } else if (!active && !userTouched && panel.open) {
      panel.open = false;
    }
    activeBefore = active;
  }

  document.addEventListener('click', function (event) {
    if (event.target.closest && event.target.closest('.rs-jobs-summary')) userTouched = true;
  }, true);

  function observe() {
    var observer = new MutationObserver(function () {
      refreshJobs();
      var notes = document.querySelectorAll('.shiny-notification');
      Array.prototype.forEach.call(notes, scheduleHide);
    });
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    refreshJobs();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', observe);
  } else {
    observe();
  }
})();
