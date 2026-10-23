// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require_tree .

// GANTRY theme toggle. Sets data-theme on <html> early (no flash),
// persists the choice, and places a sun/moon icon button in the header.
(function () {
  var SUN = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.4 1.4M17.6 17.6L19 19M19 5l-1.4 1.4M6.4 17.6L5 19"/></svg>';
  var MOON = '<svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></svg>';
  function apply(t) { document.documentElement.setAttribute('data-theme', t); }
  var saved = null;
  try { saved = localStorage.getItem('gantry-theme'); } catch (e) {}
  apply(saved || 'light');
  function build() {
    if (document.getElementById('gantry-theme-toggle')) return;
    var b = document.createElement('button');
    b.id = 'gantry-theme-toggle';
    b.type = 'button';
    b.setAttribute('aria-label', 'Toggle light and dark theme');
    function icon() {
      b.innerHTML = document.documentElement.getAttribute('data-theme') === 'dark' ? SUN : MOON;
    }
    icon();
    b.addEventListener('click', function () {
      var next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      apply(next);
      try { localStorage.setItem('gantry-theme', next); } catch (e) {}
      icon();
    });
    var host = document.getElementById('header') || document.querySelector('.navbar.navbar-default') || document.body;
    host.appendChild(b);
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', build);
  } else {
    build();
  }
})();

// GANTRY mobile nav. Toggles the plain #header menu on small screens.
// The bootstrap .navbar layout uses its own collapse, so this only
// wires the #header hamburger.
(function () {
  function init() {
    var header = document.getElementById('header');
    var toggle = document.getElementById('nav-toggle');
    if (!header || !toggle) return;
    toggle.addEventListener('click', function () {
      var open = header.classList.toggle('nav-open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
