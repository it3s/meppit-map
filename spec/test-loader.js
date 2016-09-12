define([
  '../node_modules/sinon/lib/sinon',
  '../node_modules/sinon/lib/sinon/spy',
  '../node_modules/sinon/lib/sinon/call',
  '../node_modules/sinon/lib/sinon/behavior',
  '../node_modules/sinon/lib/sinon/stub',
  '../node_modules/sinon/lib/sinon/mock',
  '../node_modules/sinon/lib/sinon/collection',
  '../node_modules/sinon/lib/sinon/assert',
  '../node_modules/sinon/lib/sinon/sandbox',
  '../node_modules/sinon/lib/sinon/test',
  '../node_modules/sinon/lib/sinon/test_case',
  '../node_modules/sinon/lib/sinon/assert',
  '../node_modules/sinon/lib/sinon/match',
  '../node_modules/sinon/lib/sinon/util/event',
  '../node_modules/sinon/lib/sinon/util/fake_xml_http_request',
  '../node_modules/sinon/lib/sinon/util/fake_server',
  '../node_modules/sinon/lib/sinon/util/fake_timers',
  '../node_modules/sinon/lib/sinon/util/fake_server_with_clock',
  "test-suite"
], function(sinon){
  "use strict";

  chai.Assertion.includeStack = true;

  // http://chaijs.com/api/bdd/
  window.expect = chai.expect;
  window.sinon = sinon;
  window.MEPPIT_SILENCE = true;

  // https://github.com/cjohansen/Sinon.JS/issues/319#issuecomment-34325683
  if (navigator.userAgent.indexOf('PhantomJS') !== -1){
    window.ProgressEvent = function (type, params) {
      params = params || {};

      this.lengthComputable = params.lengthComputable || false;
      this.loaded = params.loaded || 0;
      this.total = params.total || 0;
    };
  }

  window.simulate = function(element, eventName) {
  // http://stackoverflow.com/a/6158050
    var extend = function(destination, source) {
      for (var property in source)
        destination[property] = source[property];
      return destination;
    };
    var eventMatchers = {
      'HTMLEvents': /^(?:load|unload|abort|error|select|change|submit|reset|focus|blur|resize|scroll)$/,
      'MouseEvents': /^(?:click|dblclick|mouse(?:down|up|over|move|out))$/
    };
    var defaultOptions = {
       pointerX: 0,
      pointerY: 0,
      button: 0,
      ctrlKey: false,
      altKey: false,
      shiftKey: false,
      metaKey: false,
      bubbles: true,
      cancelable: true
    };
    var options = extend(defaultOptions, arguments[2] || {});
    var oEvent, eventType = null;

    for (var name in eventMatchers) {
      if (eventMatchers[name].test(eventName)) { eventType = name; break; }
    }

    if (!eventType)
      throw new SyntaxError('Only HTMLEvents and MouseEvents interfaces are supported');

    if (document.createEvent) {
      oEvent = document.createEvent(eventType);
      if (eventType == 'HTMLEvents') {
        oEvent.initEvent(eventName, options.bubbles, options.cancelable);
      }
      else {
        oEvent.initMouseEvent(eventName, options.bubbles, options.cancelable, document.defaultView,
        options.button, options.pointerX, options.pointerY, options.pointerX, options.pointerY,
        options.ctrlKey, options.altKey, options.shiftKey, options.metaKey, options.button, element);
      }
      element.dispatchEvent(oEvent);
    }
    else {
      options.clientX = options.pointerX;
      options.clientY = options.pointerY;
      var evt = document.createEventObject();
      oEvent = extend(evt, options);
      element.fireEvent('on' + eventName, oEvent);
    }
    return element;
  }


  return {
    start: function() {
      window.__testing = true;
      window.__testToken = 'pk.eyJ1IjoibWVwcGl0IiwiYSI6ImNpc3pncnozYzBobWYyb3BnMXgxNWN6cWcifQ.jBGkz5FC3zrB10uU-liRmw';
      // Once dependencies have been loaded using RequireJS, go ahead and run the tests...
      mocha.run();
    }
  };
});
