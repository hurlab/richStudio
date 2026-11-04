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

  /* Copy buttons: the text to copy is in data-copy; nothing is written as HTML. */
  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest('.rs-copy');
    if (!button) return;
    var text = button.getAttribute('data-copy') || '';
    var done = function () {
      var label = button.getAttribute('data-label') || button.textContent;
      button.setAttribute('data-label', label);
      button.textContent = 'Copied';
      window.setTimeout(function () { button.textContent = label; }, 2000);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () {});
    } else {
      var area = document.createElement('textarea');
      area.value = text;
      document.body.appendChild(area);
      area.select();
      try { document.execCommand('copy'); done(); } catch (e) { /* the command stays selectable */ }
      document.body.removeChild(area);
    }
  });

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
    /* Persistent notifications (a running job's progress, id job-<run>) stay until the server removes them. */
    if (/^shiny-notification-job-/.test(node.id || '')) return;
    scheduled.add(node);
    window.setTimeout(function () { removeNotification(node); }, SUCCESS_HIDE_MS);
  }

  /* The job tray (M5): a slide-over that only the user opens, with the job badge as
   * its button. Opening moves focus into the tray; Escape or Close closes it and
   * returns focus to the badge. The tray also writes its one-line summary. */
  function tray() { return document.querySelector('.rs-job-tray'); }
  function badge() { return document.querySelector('.rs-job-badge'); }
  function trayOpen() {
    var t = tray();
    return !!t && t.classList.contains('rs-job-tray-open');
  }
  function syncBadge() {
    var b = badge();
    if (b) b.setAttribute('aria-expanded', trayOpen() ? 'true' : 'false');
  }
  function openTray() {
    var t = tray();
    if (!t) return;
    t.classList.add('rs-job-tray-open');
    syncBadge();
    t.focus();
  }
  function closeTray(returnFocus) {
    var t = tray();
    if (!t || !trayOpen()) return;
    t.classList.remove('rs-job-tray-open');
    syncBadge();
    var b = badge();
    if (returnFocus && b) b.focus();
  }

  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target.closest) return;
    if (target.closest('.rs-job-badge')) {
      if (trayOpen()) closeTray(true); else openTray();
    } else if (target.closest('.rs-job-tray-close')) {
      closeTray(true);
    } else if (target.closest('.rs-context-toggle')) {
      var bar = target.closest('.rs-context-bar');
      var open = !bar.classList.contains('rs-context-open');
      contextOpen = open;
      bar.classList.toggle('rs-context-open', open);
      target.closest('.rs-context-toggle').setAttribute('aria-expanded', open ? 'true' : 'false');
    }
  }, true);

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && trayOpen()) {
      event.preventDefault();
      closeTray(true);
    }
  });

  /* The jobs stay listed while the tray is open: the disclosure cannot be closed. */
  document.addEventListener('toggle', function (event) {
    var d = event.target;
    if (d && d.classList && d.classList.contains('rs-jobs-disclosure') && !d.open) d.open = true;
  }, true);

  // The context bar is rebuilt by the server; keep its narrow-viewport open state across rebuilds.
  var contextOpen = false;
  function syncContext() {
    var bar = document.querySelector('.rs-context-bar');
    var toggle = bar && bar.querySelector('.rs-context-toggle');
    if (!bar || !toggle) return;
    if (bar.classList.contains('rs-context-open') !== contextOpen) {
      bar.classList.toggle('rs-context-open', contextOpen);
      toggle.setAttribute('aria-expanded', contextOpen ? 'true' : 'false');
    }
  }

  function refreshJobs() {
    syncContext();
    var panel = document.querySelector('section[aria-label="Analysis jobs"] .rs-jobs-disclosure');
    if (!panel) return;
    var rows = panel.querySelectorAll('.rs-job');
    var active = panel.querySelectorAll(
      '.rs-job[data-state="queued"], .rs-job[data-state="running"], .rs-job[data-state="cancel_requested"]').length;
    var summary = panel.querySelector('.rs-jobs-summary');
    if (!rows.length) {
      if (trayOpen()) closeTray(false);
      return;
    }
    var text = 'Analysis jobs: ' + rows.length;
    if (active) text += ' (' + active + ' running or queued)';
    if (summary && summary.textContent !== text) summary.textContent = text;
    if (!panel.open) panel.open = true;
    syncBadge();
  }

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
