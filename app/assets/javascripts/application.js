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
// persists the choice, and injects a fixed toggle button.
(function () {
  function apply(t) { document.documentElement.setAttribute('data-theme', t); }
  var saved = null;
  try { saved = localStorage.getItem('gantry-theme'); } catch (e) {}
  apply(saved || 'light');
  function build() {
    if (document.getElementById('gantry-theme-toggle')) return;
    var b = document.createElement('button');
    b.id = 'gantry-theme-toggle';
    b.type = 'button';
    function label() {
      b.textContent = document.documentElement.getAttribute('data-theme') === 'dark' ? 'Light' : 'Dark';
    }
    label();
    b.addEventListener('click', function () {
      var next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      apply(next);
      try { localStorage.setItem('gantry-theme', next); } catch (e) {}
      label();
    });
    document.body.appendChild(b);
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
