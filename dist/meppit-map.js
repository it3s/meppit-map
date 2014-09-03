(function() {
  var BaseClass, EditorManager, Map, Popup, counter, getDate, getHash, interpolate, isArray, isNumber, isString, requestJSON, reverseCoordinates, _log, _warn,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  if (window.Meppit == null) {
    window.Meppit = {};
  }

  window.Meppit.VERSION = '0.1.5';

  isArray = Meppit.isArray = function(data) {
    return Object.prototype.toString.call(data) === '[object Array]';
  };

  isNumber = Meppit.isNumber = function(data) {
    return typeof data === 'number';
  };

  isString = Meppit.isString = function(data) {
    return typeof data === 'string';
  };

  interpolate = Meppit.interpolate = function(tpl, obj) {
    return tpl.replace(/#{([^#{}]*)}/g, function(a, b) {
      var r;
      r = obj[b];
      if (isString(r) || isNumber(r)) {
        return r;
      } else {
        return a;
      }
    });
  };

  getHash = Meppit.getHash = function(data) {
    var char, hash, i, _i, _ref;
    hash = 0;
    if (data.length > 0) {
      for (i = _i = 0, _ref = data.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
        char = data.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash |= 0;
      }
    }
    return '_' + hash;
  };

  getDate = Meppit.getDate = function(date) {
    var day, month, months, year, yy;
    months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    if (date == null) {
      date = new Date();
    }
    day = date.getDate();
    month = date.getMonth();
    yy = date.getYear();
    year = yy < 1000 ? yy + 1900 : yy;
    return "" + months[month] + " " + day + " " + year;
  };

  _log = Meppit.log = function() {
    var args;
    args = ["[" + (getDate()) + "]"].concat(Array.prototype.slice.call(arguments));
    if (!window.MEPPIT_SILENCE) {
      return typeof console !== "undefined" && console !== null ? console.log(args.join(' ')) : void 0;
    }
  };

  _warn = Meppit.warn = function() {
    var args;
    args = ["[" + (getDate()) + "]"].concat(Array.prototype.slice.call(arguments));
    if (!window.MEPPIT_SILENCE) {
      return typeof console !== "undefined" && console !== null ? console.warn(args.join(' ')) : void 0;
    }
  };

  reverseCoordinates = Meppit.reverseCoordinates = function(data) {
    var feature, i;
    if (isNumber(data)) {
      return data;
    }
    if (isArray(data) && isArray(data[0])) {
      return (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = data.length; _i < _len; _i++) {
          i = data[_i];
          _results.push(reverseCoordinates(i));
        }
        return _results;
      })();
    }
    if (isArray(data) && isNumber(data[0])) {
      return data.reverse();
    }
    if (data.type === 'Feature') {
      data.geometry.coordinates = reverseCoordinates(data.geometry.coordinates);
    } else if (data.type === 'FeatureCollection') {
      data.features = (function() {
        var _i, _len, _ref, _results;
        _ref = data.features;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          feature = _ref[_i];
          _results.push(reverseCoordinates(feature));
        }
        return _results;
      })();
    }
    return data;
  };

  requestJSON = Meppit.requestJSON = function(url, callback) {
    var req;
    req = window.XMLHttpRequest ? new XMLHttpRequest() : window.ActiveXObject ? new ActiveXObject("Microsoft.XMLHTTP") : void 0;
    if (this._requests == null) {
      this._requests = [];
    }
    this._requests.push(req);
    req.onreadystatechange = function() {
      if (req.readyState === 4) {
        if (req.status === 200) {
          return callback(JSON.parse(req.responseText));
        } else {
          return callback(null);
        }
      }
    };
    req.open('GET', url, true);
    return req.send();
  };

  counter = 0;

  BaseClass = (function() {
    BaseClass.prototype.VERSION = '0.1.5';

    function BaseClass() {
      this.cid = counter++;
    }

    BaseClass.prototype.log = function() {
      var args;
      args = ["Log: " + this.constructor.name + "#" + this.cid + " -"].concat(Array.prototype.slice.call(arguments));
      return _log.apply(this, args);
    };

    BaseClass.prototype.warn = function() {
      var args;
      args = ["Warn: " + this.constructor.name + "#" + this.cid + " -"].concat(Array.prototype.slice.call(arguments));
      return _warn.apply(this, args);
    };

    BaseClass.prototype.getOption = function(key) {
      var _ref, _ref1, _ref2;
      return (_ref = (_ref1 = this.options) != null ? _ref1[key] : void 0) != null ? _ref : (_ref2 = this.defaultOptions) != null ? _ref2[key] : void 0;
    };

    BaseClass.prototype.setOption = function(key, value) {
      if (this.options == null) {
        this.options = {};
      }
      return this.options[key] = value;
    };

    return BaseClass;

  })();

  Meppit.BaseClass = BaseClass;

  if (typeof define === "function") {
    define([], function() {
      return window.Meppit;
    });
  }

  EditorManager = (function(_super) {
    __extends(EditorManager, _super);

    EditorManager.prototype.defaultOptions = {
      drawControl: false
    };

    function EditorManager(map, options) {
      this.map = map;
      this.options = options != null ? options : {};
      EditorManager.__super__.constructor.apply(this, arguments);
      this.log('Initializing Editor Manager...');
      this._initToolbars();
      this._uneditedLayerProps = {};
    }

    EditorManager.prototype.edit = function(data, callback) {
      var edit, layer;
      layer = this.map._getLeafletLayers(data)[0];
      if ((this._currentLayer != null) && this._currentLayer === layer) {
        return;
      }
      this.done();
      this._currentCallback = callback;
      this._currentLayer = layer;
      edit = (function(_this) {
        return function() {
          var enable;
          if (!_this._currentLayer) {
            return;
          }
          _this._backupLayer(_this._currentLayer);
          enable = function(layer) {
            var id, layer_, _ref, _ref1, _ref2, _results;
            if (!layer) {
              return;
            }
            if ((_ref = layer.editing) != null) {
              _ref.enable();
            }
            if ((_ref1 = layer.dragging) != null) {
              _ref1.enable();
            }
            if (layer._layers != null) {
              _ref2 = layer._layers;
              _results = [];
              for (id in _ref2) {
                layer_ = _ref2[id];
                _results.push(enable(layer_));
              }
              return _results;
            }
          };
          enable(_this._currentLayer);
          return _this.map.editing = true;
        };
      })(this);
      if (this._currentLayer) {
        return edit();
      } else {
        return this.map.load(data, (function(_this) {
          return function() {
            _this._currentLayer = _this.map._getLeafletLayers(data)[0];
            return edit();
          };
        })(this));
      }
    };

    EditorManager.prototype.draw = function(data, callback) {
      var type;
      this.cancel();
      this._currentCallback = callback;
      this.map.editing = true;
      type = Meppit.isString(data) ? data : data.geometry.type;
      type = type.toLowerCase();
      this._drawing = type === 'polygon' ? new L.Draw.Polygon(this.map.leafletMap) : type === 'linestring' ? new L.Draw.Polyline(this.map.leafletMap) : new L.Draw.Marker(this.map.leafletMap);
      this.map.leafletMap.once('draw:created', (function(_this) {
        return function(e) {
          var geoJSON;
          geoJSON = e.layer.toGeoJSON();
          if (data.properties != null) {
            geoJSON.properties = data.properties;
          }
          _this.map.load(geoJSON);
          return typeof callback === "function" ? callback(geoJSON) : void 0;
        };
      })(this));
      return this._drawing.enable();
    };

    EditorManager.prototype.done = function() {
      var _ref, _ref1;
      if (this._currentLayer) {
        if ((_ref = this._currentLayer.editing) != null) {
          _ref.disable();
        }
        if ((_ref1 = this._currentLayer.dragging) != null) {
          _ref1.disable();
        }
        if (typeof this._currentCallback === "function") {
          this._currentCallback(this._currentLayer.toGeoJSON());
        }
      }
      this._currentCallback = this._currentLayer = void 0;
      return this.map.editing = false;
    };

    EditorManager.prototype.cancel = function() {
      this.revert();
      this.done();
      return this.map.editing = false;
    };

    EditorManager.prototype.revert = function() {
      return this._revertLayer(this._currentLayer);
    };

    EditorManager.prototype._initToolbars = function() {
      if (!this.getOption('drawControl')) {
        return;
      }
      return this._initEditToolbar();
    };

    EditorManager.prototype._initEditToolbar = function() {
      this.drawnItems = this.map._ensureGeoJsonManager();
      this.drawControl = new L.Control.Draw({
        edit: {
          featureGroup: this.drawnItems
        }
      });
      return this.map._addLeafletControl(this.drawControl);
    };

    EditorManager.prototype._backupLayer = function(layer) {
      var id;
      id = L.Util.stamp(layer);
      if (!this._uneditedLayerProps[id]) {
        if (layer instanceof L.Polyline || layer instanceof L.Polygon) {
          return this._uneditedLayerProps[id] = {
            latlngs: L.LatLngUtil.cloneLatLngs(layer.getLatLngs())
          };
        } else if (layer instanceof L.Marker) {
          return this._uneditedLayerProps[id] = {
            latlng: L.LatLngUtil.cloneLatLng(layer.getLatLng())
          };
        }
      }
    };

    EditorManager.prototype._revertLayer = function(layer) {
      var id;
      if (layer == null) {
        return;
      }
      id = L.Util.stamp(layer);
      layer.edited = false;
      if (this._uneditedLayerProps.hasOwnProperty(id)) {
        if (layer instanceof L.Polyline || layer instanceof L.Polygon) {
          return layer.setLatLngs(this._uneditedLayerProps[id].latlngs);
        } else if (layer instanceof L.Marker) {
          return layer.setLatLng(this._uneditedLayerProps[id].latlng);
        }
      }
    };

    return EditorManager;

  })(Meppit.BaseClass);

  window.Meppit.EditorManager = EditorManager;

  Map = (function(_super) {
    __extends(Map, _super);

    Map.prototype.MAXZOOM = 15;

    Map.prototype.defaultOptions = {
      element: document.createElement('div'),
      zoom: 14,
      center: [-23.5, -46.6167],
      tileProvider: 'map',
      idPropertyName: 'id',
      urlPropertyName: 'url',
      featureURL: '#{baseURL}features/#{id}',
      geojsonTileURL: '#{baseURL}geoJSON/{z}/{x}/{y}',
      enableEditor: true,
      enablePopup: true,
      enableGeoJsonTile: false
    };

    function Map(options) {
      this.options = options != null ? options : {};
      Map.__super__.constructor.apply(this, arguments);
      this.log('Initializing Map');
      this.editing = false;
      this.buttons = {};
      this._ensureLeafletMap();
      this._ensureTileProviders();
      this._ensureGeoJsonManager();
      this.__defineLeafletDefaultImagePath();
      this.selectTileProvider(this.getOption('tileProvider'));
    }

    Map.prototype.destroy = function() {
      return this.leafletMap.remove();
    };

    Map.prototype.load = function(data, callback) {
      var count, data_, layer, layers, respCollection, _i, _j, _len, _len1;
      if (Meppit.isNumber(data)) {
        this.load(this.getURL(data), callback);
      } else if (Meppit.isString(data)) {
        Meppit.requestJSON(data, (function(_this) {
          return function(resp) {
            if (resp) {
              return _this.load(resp, callback);
            } else {
              return typeof callback === "function" ? callback(null) : void 0;
            }
          };
        })(this));
      } else if (Meppit.isArray(data)) {
        count = 0;
        respCollection = {
          "type": "FeatureCollection",
          "features": []
        };
        for (_i = 0, _len = data.length; _i < _len; _i++) {
          data_ = data[_i];
          this.load(data_, function(resp) {
            count++;
            respCollection.features.push(resp);
            if (count === data.length) {
              return callback(respCollection);
            }
          });
        }
      } else {
        layers = this._getLeafletLayers(data);
        for (_j = 0, _len1 = layers.length; _j < _len1; _j++) {
          layer = layers[_j];
          this._removeLeafletLayer(layer);
        }
        this._geoJsonManager.addData(data);
        if (typeof callback === "function") {
          callback(data);
        }
      }
      return this;
    };

    Map.prototype.show = function(data, callback) {
      this.load(data, (function(_this) {
        return function(geoJSON) {
          _this.fit(geoJSON);
          return typeof callback === "function" ? callback(geoJSON) : void 0;
        };
      })(this));
      return this;
    };

    Map.prototype.toGeoJSON = function() {
      return this._geoJsonManager.toGeoJSON();
    };

    Map.prototype.toSimpleGeoJSON = function() {
      var feature, geoJSON, _i, _len, _ref;
      geoJSON = this._geoJsonManager.toGeoJSON();
      _ref = geoJSON.features;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        feature = _ref[_i];
        feature.properties = {};
      }
      return geoJSON;
    };

    Map.prototype.get = function(id) {
      var _ref;
      return (_ref = this._getLeafletLayer(id)) != null ? _ref.toGeoJSON() : void 0;
    };

    Map.prototype.remove = function(data) {
      var layer, layers, _i, _len;
      layers = this._getLeafletLayers(data);
      for (_i = 0, _len = layers.length; _i < _len; _i++) {
        layer = layers[_i];
        this._removeLeafletLayer(layer);
      }
      return this;
    };

    Map.prototype.edit = function(data, callback) {
      var _ref;
      this.closePopup();
      this.panTo(data);
      if ((_ref = this._ensureEditorManager()) != null) {
        _ref.edit(data, callback);
      }
      return this;
    };

    Map.prototype.draw = function(data, callback) {
      var _ref;
      this.closePopup();
      if ((_ref = this._ensureEditorManager()) != null) {
        _ref.draw(data, callback);
      }
      return this;
    };

    Map.prototype.done = function() {
      var _ref;
      if ((_ref = this._editorManager) != null) {
        _ref.done();
      }
      return this;
    };

    Map.prototype.cancel = function() {
      var _ref;
      if ((_ref = this._editorManager) != null) {
        _ref.cancel();
      }
      return this;
    };

    Map.prototype.revert = function() {
      var _ref;
      if ((_ref = this._editorManager) != null) {
        _ref.revert();
      }
      return this;
    };

    Map.prototype.addButton = function(id, icon, callback, title, position) {
      var button;
      if (position == null) {
        position = 'topleft';
      }
      button = L.easyButton(icon, callback, title, '');
      button.options.position = position;
      this.leafletMap.addControl(button);
      this.buttons[id] = button;
      return this;
    };

    Map.prototype.removeButton = function(id) {
      var button;
      button = this.buttons[id];
      if (button) {
        this.leafletMap.removeControl(button);
      }
      this.buttons[id] = void 0;
      return this;
    };

    Map.prototype.showButton = function(id) {
      var button;
      button = this.buttons[id];
      button._container.style.display = '';
      return this;
    };

    Map.prototype.hideButton = function(id) {
      var button;
      button = this.buttons[id];
      button._container.style.display = 'none';
      return this;
    };

    Map.prototype.openPopup = function(data, content) {
      this.openPopupAt(data, content);
      return this;
    };

    Map.prototype.openPopupAt = function(data, content, latLng) {
      var _ref;
      if ((_ref = this._ensurePopupManager()) != null) {
        _ref.open(data, content, latLng);
      }
      return this;
    };

    Map.prototype.closePopup = function() {
      var _ref;
      if ((_ref = this._ensurePopupManager()) != null) {
        _ref.close();
      }
      return this;
    };

    Map.prototype.fit = function(data) {
      var bounds;
      if (data == null) {
        return this;
      }
      bounds = this._getBounds(data);
      if (bounds != null) {
        this.leafletMap.fitBounds(bounds, {
          maxZoom: this.MAXZOOM,
          animate: false
        });
      }
      return this;
    };

    Map.prototype.panTo = function(data) {
      var bounds;
      if (data == null) {
        return this;
      }
      bounds = this._getBounds(data);
      if (bounds != null) {
        this.leafletMap.panInsideBounds(bounds);
      }
      return this;
    };

    Map.prototype.selectTileProvider = function(provider) {
      var _ref;
      if ((_ref = this.tileProviders[provider]) != null) {
        _ref.addTo(this.leafletMap);
      }
      this.currentTileProvider = provider;
      return this;
    };

    Map.prototype.clear = function() {
      this._geoJsonManager.clearLayers();
      this.leafletLayers = {};
      return this;
    };

    Map.prototype.getZoom = function() {
      return this.leafletMap.getZoom.apply(this.leafletMap, arguments);
    };

    Map.prototype.setZoom = function() {
      this.leafletMap.setZoom.apply(this.leafletMap, arguments);
      return this;
    };

    Map.prototype.zoomIn = function() {
      this.leafletMap.zoomIn.apply(this.leafletMap, arguments);
      return this;
    };

    Map.prototype.zoomOut = function() {
      this.leafletMap.zoomOut.apply(this.leafletMap, arguments);
      return this;
    };

    Map.prototype.getURL = function(feature) {
      var url, _ref;
      url = feature != null ? (_ref = feature.properties) != null ? _ref[this.getOption('urlPropertyName')] : void 0 : void 0;
      if (url != null) {
        return url;
      }
      url = Meppit.interpolate(this.getOption('featureURL'), {
        baseURL: this._getBaseURL()
      });
      return Meppit.interpolate(url, {
        id: this._getGeoJSONId(feature)
      });
    };

    Map.prototype.refresh = function() {
      this.leafletMap._onResize();
      return this;
    };

    Map.prototype.locate = function(onSuccess, onError, timeout) {
      var timer, _locationFromIP, _onError, _onSuccess;
      if (timeout == null) {
        timeout = 5000;
      }
      timer = null;
      _locationFromIP = function() {
        var ipPos;
        ipPos = L.GeoIP.getPosition();
        if ((ipPos != null) && ipPos.lat !== 0 && ipPos.lng !== 0) {
          _onSuccess({
            latlng: ipPos,
            bounds: L.latLngBounds([[ipPos.lat - 0.05, ipPos.lng - 0.05], [ipPos.lat + 0.05, ipPos.lng + 0.05]])
          });
          return true;
        } else {
          return false;
        }
      };
      _onSuccess = function(e) {
        var bbox, coordinates, location;
        clearTimeout(timer);
        bbox = !e.bounds ? void 0 : [[e.bounds.getWest(), e.bounds.getSouth()], [e.bounds.getEast(), e.bounds.getNorth()]];
        coordinates = !e.latlng ? void 0 : [e.latlng.lng, e.latlng.lat];
        location = !coordinates ? void 0 : {
          "type": "Feature",
          "bbox": bbox,
          "geometry": {
            "type": "Point",
            "coordinates": coordinates
          }
        };
        return onSuccess({
          location: location,
          accuracy: e.accuracy,
          altitude: e.altitude,
          heading: e.heading,
          speed: e.speed,
          timestamp: e.timestamp
        });
      };
      _onError = function(e) {
        clearTimeout(timer);
        if (!_locationFromIP()) {
          return onError(e);
        }
      };
      if (onSuccess) {
        this.leafletMap.once('locationfound', _onSuccess);
      }
      if (onError) {
        this.leafletMap.once('locationerror', _onError);
      }
      this.leafletMap.once('locationfound locationerror', (function(_this) {
        return function() {
          _this.leafletMap.off('locationfound', _onSuccess);
          return _this.leafletMap.off('locationerror', _onError);
        };
      })(this));
      this.leafletMap.locate({
        setView: true,
        maxZoom: this.MAXZOOM
      });
      timer = setTimeout(function() {
        return _locationFromIP();
      }, timeout);
      return this;
    };

    Map.prototype._getBounds = function(data) {
      var bounds, layer, layers, _i, _len;
      layers = this._getLeafletLayers(data);
      bounds = void 0;
      if (layers.length > 0) {
        for (_i = 0, _len = layers.length; _i < _len; _i++) {
          layer = layers[_i];
          if (layer != null) {
            if (layer.getBounds != null) {
              if (bounds == null) {
                bounds = layer.getBounds();
              }
              bounds.extend(layer.getBounds());
            } else if (layer.getLatLng != null) {
              if (bounds == null) {
                bounds = L.latLngBounds([layer.getLatLng()]);
              }
              bounds.extend(layer.getLatLng());
            }
          }
        }
      } else if (data.bbox) {
        bounds = L.latLngBounds([[L.latLng(data.bbox[0][1], data.bbox[0][0])], [L.latLng(data.bbox[1][1], data.bbox[1][0])]]);
      }
      return bounds;
    };

    Map.prototype._getBaseURL = function() {
      var baseDocument, baseElements, baseURL;
      baseElements = document.getElementsByTagName('base');
      baseDocument = 'index.html';
      baseURL = this.getOption('baseURL');
      if (baseURL != null) {
        return baseURL;
      }
      if (baseElements.length > 0) {
        return baseElements[0].href.replace(baseDocument, "");
      } else {
        return location.protocol + '//' + location.hostname + (location.port !== '' ? ':' + location.port : '') + "/";
      }
    };

    Map.prototype._getGeoJsonTileURL = function() {
      return Meppit.interpolate(this.getOption('geojsonTileURL'), {
        baseURL: this._getBaseURL()
      });
    };

    Map.prototype._ensureLeafletMap = function() {
      if (this.element == null) {
        this.element = Meppit.isString(this.getOption('element')) ? document.getElementById(this.getOption('element')) : this.getOption('element');
      }
      return this.leafletMap != null ? this.leafletMap : this.leafletMap = new L.Map(this.element, this.__getLeafletMapOptions());
    };

    Map.prototype._ensureGeoJsonManager = function() {
      var onEachFeatureCallback, options, styleCallback;
      if (this.leafletLayers == null) {
        this.leafletLayers = {};
      }
      onEachFeatureCallback = (function(_this) {
        return function(feature, layer) {
          _this.__saveFeatureLayerRelation(feature, layer);
          return _this.__addLayerEventListeners(feature, layer);
        };
      })(this);
      styleCallback = (function(_this) {
        return function() {};
      })(this);
      options = {
        style: styleCallback,
        onEachFeature: onEachFeatureCallback
      };
      if (this.getOption('enableGeoJsonTile')) {
        if (this.__geoJsonTileLayer == null) {
          this.__geoJsonTileLayer = (new L.TileLayer.GeoJSON(this._getGeoJsonTileURL(), {
            clipTiles: true,
            unique: (function(_this) {
              return function(feature) {
                return _this._getGeoJSONId(feature);
              };
            })(this)
          }, options)).addTo(this.leafletMap);
        }
      }
      return this._geoJsonManager != null ? this._geoJsonManager : this._geoJsonManager = new L.GeoJSON([], options).addTo(this.leafletMap);
    };

    Map.prototype._ensureEditorManager = function() {
      var _ref;
      if (!this.getOption('enableEditor')) {
        this.warn('Editor manager have been disabled');
        return;
      }
      if (this._editorManager == null) {
        this._editorManager = (_ref = typeof Meppit.EditorManager === "function" ? new Meppit.EditorManager(this, this.options) : void 0) != null ? _ref : this.warn('Editor manager have not been loaded');
      }
      return this._editorManager;
    };

    Map.prototype._ensurePopupManager = function() {
      var _ref;
      if (!this.getOption('enablePopup')) {
        this.warn('Popup manager have been disabled');
        return;
      }
      if (this._popupManager == null) {
        this._popupManager = (_ref = typeof Meppit.PopupManager === "function" ? new Meppit.PopupManager(this, this.options) : void 0) != null ? _ref : this.warn('Popup manager have not been loaded');
      }
      return this._popupManager;
    };

    Map.prototype._ensureTileProviders = function() {
      var _base, _base1;
      if (this.tileProviders == null) {
        this.tileProviders = {};
      }
      if ((_base = this.tileProviders).map == null) {
        _base.map = new L.TileLayer('http://{s}.mqcdn.com/tiles/1.0.0/map/{z}/{x}/{y}.png', {
          attribution: 'Data, imagery and map information provided by ' + '<a href="http://www.mapquest.com/">MapQuest</a>, ' + '<a href="http://www.openstreetmap.org/">Open Street Map</a> ' + 'and contributors, <a href="http://creativecommons.org/' + 'licenses/by-sa/2.0/">CC-BY-SA</a>.',
          subdomains: ['otile1', 'otile2', 'otile3', 'otile4']
        });
      }
      if ((_base1 = this.tileProviders).satellite == null) {
        _base1.satellite = new L.TileLayer('http://{s}.mqcdn.com/tiles/1.0.0/sat/{z}/{x}/{y}.jpg', {
          attribution: 'Data and imagery provided by ' + '<a href="http://www.mapquest.com/">MapQuest</a>a>. ' + 'Portions Courtesy NASA/JPL-Caltech and ' + 'U.S. Depart. of Agriculture, Farm Service Agency.',
          subdomains: ['otile1', 'otile2', 'otile3', 'otile4']
        });
      }
      return this.tileProviders;
    };

    Map.prototype._addLeafletControl = function() {
      return this.leafletMap.addControl.apply(this.leafletMap, arguments);
    };

    Map.prototype._getGeoJSONId = function(feature) {
      var _ref;
      if (Meppit.isNumber(feature)) {
        return feature;
      }
      return (_ref = feature.properties) != null ? _ref[this.getOption('idPropertyName')] : void 0;
    };

    Map.prototype._getGeoJSONHash = function(feature) {
      return Meppit.getHash(JSON.stringify(feature));
    };

    Map.prototype._getLeafletLayers = function(data) {
      var feature, features, layers;
      if (data.type === 'FeatureCollection') {
        features = data.features.slice();
      } else {
        features = [data];
      }
      layers = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = features.length; _i < _len; _i++) {
          feature = features[_i];
          _results.push(this._getLeafletLayer(feature));
        }
        return _results;
      }).call(this);
      if (layers.length === 1 && layers[0] === void 0) {
        return [];
      }
      return layers;
    };

    Map.prototype._getLeafletLayer = function(data) {
      var _ref;
      if (Meppit.isNumber(data) || Meppit.isString(data)) {
        return this.leafletLayers[data];
      } else if (data != null) {
        return this._getLeafletLayer((_ref = this._getGeoJSONId(data)) != null ? _ref : this._getGeoJSONHash(data));
      }
    };

    Map.prototype._removeLeafletLayer = function(layer) {
      var geoJSON, _ref;
      if (layer == null) {
        return;
      }
      this._geoJsonManager.removeLayer(layer);
      this.__clearLayerEventListeners(layer);
      geoJSON = layer.toGeoJSON();
      return (_ref = this.leafletLayers) != null ? _ref[this._getGeoJSONId(geoJSON != null ? geoJSON : this._getGeoJSONHash(geoJSON))] = void 0 : void 0;
    };

    Map.prototype.__addLayerEventListeners = function(feature, layer) {
      return layer.on('click', (function(_this) {
        return function(e) {
          return _this.openPopupAt(feature, void 0, e.latlng);
        };
      })(this));
    };

    Map.prototype.__clearLayerEventListeners = function(layer) {
      return layer.off('click');
    };

    Map.prototype.__getLeafletMapOptions = function() {
      return {
        center: this.getOption('center'),
        zoom: this.getOption('zoom')
      };
    };

    Map.prototype.__saveFeatureLayerRelation = function(feature, layer) {
      var hash, _ref, _ref1;
      hash = (_ref = (_ref1 = feature.properties) != null ? _ref1.id : void 0) != null ? _ref : this._getGeoJSONHash(feature);
      return this.leafletLayers[hash] = layer;
    };

    Map.prototype.__defineLeafletDefaultImagePath = function() {
      var imagePath, meppitMapRe, path, script, scripts, src, _i, _len;
      if (L.Icon.Default.imagePath != null) {
        return;
      }
      scripts = document.getElementsByTagName('script');
      meppitMapRe = /[\/^]meppit-map[\-\._]?([\w\-\._]*)\.js\??/;
      imagePath = '/assets';
      for (_i = 0, _len = scripts.length; _i < _len; _i++) {
        script = scripts[_i];
        src = script.src;
        if (src.match(meppitMapRe)) {
          path = src.split(meppitMapRe)[0];
          imagePath = (path ? path + '/' : '') + 'images';
          break;
        }
      }
      return L.Icon.Default.imagePath = imagePath;
    };

    return Map;

  })(Meppit.BaseClass);

  window.Meppit.Map = Map;

  Popup = (function(_super) {
    __extends(Popup, _super);

    Popup.prototype.defaultOptions = {
      popupTemplate: '<h1 class="title"><a href="#{url}">#{name}</a></h1>'
    };

    function Popup(map, options) {
      this.map = map;
      this.options = options;
      this._createPopup();
    }

    Popup.prototype.open = function(data, content, latLng) {
      var layer;
      if (this.map.editing) {
        return;
      }
      layer = this.map._getLeafletLayer(data);
      if (layer == null) {
        return;
      }
      if (latLng == null) {
        latLng = layer.getLatLng != null ? layer.getLatLng() : layer.getBounds != null ? layer.getBounds().getCenter() : void 0;
      }
      this._popup.setLatLng(latLng);
      this._popup.setContent(content != null ? content : this._getContent(layer.toGeoJSON()));
      return this._popup.openOn(this.map.leafletMap);
    };

    Popup.prototype.close = function() {
      return this.map.leafletMap.closePopup(this._popup);
    };

    Popup.prototype._getContent = function(feature) {
      var content, template, _ref, _ref1;
      if (!feature) {
        return '';
      }
      template = (_ref = (_ref1 = feature.properties) != null ? _ref1.popupContent : void 0) != null ? _ref : this.getOption('popupTemplate');
      content = Meppit.interpolate(template, feature.properties);
      content = Meppit.interpolate(content, {
        url: this.map.getURL(feature)
      });
      return content;
    };

    Popup.prototype._createPopup = function() {
      return this._popup = new L.Popup();
    };

    return Popup;

  })(Meppit.BaseClass);

  window.Meppit.PopupManager = Popup;

}).call(this);

//# sourceMappingURL=meppit-map.js.map
