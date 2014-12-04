class Map extends Meppit.BaseClass
  MAXZOOM: 15
  defaultOptions:
    element: document.createElement 'div'
    zoom: 14
    center: [ -23.5, -46.6167 ]
    tileProvider: 'map'
    idPropertyName: 'id'
    urlPropertyName: 'url'
    featureURL: '#{baseURL}geo_data/#{id}'
    geojsonTileURL: '#{baseURL}geo_data/tile/{z}/{x}/{y}'
    enableEditor: true
    enablePopup: true
    enableGeoJsonTile: false

  constructor: (@options = {}) ->
    super
    @log 'Initializing Map'
    @editing = false
    @buttons = {}
    @_ensureLeafletMap()
    @_ensureEditorManager()
    @_ensureTileProviders()
    @_ensureGeoJsonManager()
    @_ensureGroupsManager()
    @__defineLeafletDefaultImagePath()
    @selectTileProvider @getOption('tileProvider')

  destroy: -> @leafletMap.remove()

  load: (data, callback) ->
    # Loads GeoJSON `data` and then calls `callback`
    # Expect coordinates to be in [lon, lat] order
    if Meppit.isNumber data  # received the feature id
      @load @getURL(data), callback
    else if Meppit.isString data  # got an url
      Meppit.requestJSON data, (resp) =>
        if resp
          @load resp, callback
        else
          callback? null
    else if Meppit.isArray data # got a list of id or url
      count = 0
      respCollection =
        "type": "FeatureCollection",
        "features": []
      for data_ in data
        @load data_, (resp) ->
          count++
          respCollection.features.push resp
          if count == data.length
            callback? respCollection
    else
      # Removes the old version of already loaded features before loading the
      # new one.
      layers = @_getLeafletLayers data
      for layer in layers
        @_removeLeafletLayer layer
      @_geoJsonManager.addData data
      callback? data
    this

  show: (data, callback) ->
    @load data, (geoJSON) =>
      @fit geoJSON
      callback? geoJSON
    this

  toGeoJSON: ->
    # Returns a GeoJSON FeatureCollection containing all features loaded
    @_geoJsonManager.toGeoJSON()

  toSimpleGeoJSON: ->
    # Return a simplified version of GeoJSON FeatureCollection containing all
    # features loaded whithout the `properties` field
    geoJSON = @_geoJsonManager.toGeoJSON()
    for feature in geoJSON.features
      feature.properties = {}
    geoJSON

  get: (id) ->
    # Returns a GeoJSON Feature or undefined
    @_getLeafletLayer(id)?.toGeoJSON()

  remove: (data) ->
    # Removes the given features fom map
    # `data` can be a GeoJSON or a feature id
    layers = @_getLeafletLayers data
    for layer in layers
      @_removeLeafletLayer layer
    this

  edit: (data, callback) ->
    # Edits the feature given by `data` and then calls `callback`
    # `data` can be a GeoJSON or a feature id
    @closePopup()
    @panTo data
    @_ensureEditorManager()?.edit data, callback
    this

  draw: (data, callback) ->
    @closePopup()
    @_ensureEditorManager()?.draw data, callback
    this

  done: ->
    @_editorManager?.done()
    this

  cancel: ->
    @_editorManager?.cancel()
    this

  revert: ->
    @_editorManager?.revert()
    this

  addButton: (id, icon, callback, title, position = 'topleft') ->
    button = L.easyButton icon, callback, title, ''
    button.options.position = position
    @leafletMap.addControl button
    @buttons[id] = button
    this

  removeButton: (id) ->
    button = @buttons[id]
    @leafletMap.removeControl button if button
    @buttons[id] = undefined
    this

  showButton: (id) ->
    button = @buttons[id]
    button._container.style.display = ''
    this

  hideButton: (id) ->
    button = @buttons[id]
    button._container.style.display = 'none'
    this

  openPopup: (data, content) ->
    @openPopupAt data, content
    this

  openPopupAt: (data, content, latLng) ->
    @_ensurePopupManager()?.open data, content, latLng
    this

  closePopup: ->
    @_ensurePopupManager()?.close()
    this

  fit: (data) ->
    return this if not data?
    bounds = @_getBounds data
    @leafletMap.fitBounds bounds, {
      maxZoom: @MAXZOOM,
      animate: false
    } if bounds?
    this

  panTo: (data) ->
    return this if not data?
    bounds = @_getBounds data
    @leafletMap.panInsideBounds bounds if bounds?
    this

  selectTileProvider: (provider) ->
    @tileProviders[provider]?.addTo(@leafletMap)
    @currentTileProvider = provider
    this

  clear: ->
    @_geoJsonManager.clearLayers()  # remove all layers
    @leafletLayers = {}  # clear the assossiation between layers and ids
    this

  getZoom: ->
    @leafletMap.getZoom.apply @leafletMap, arguments

  setZoom: ->
    @leafletMap.setZoom.apply @leafletMap, arguments
    this

  zoomIn: ->
    @leafletMap.zoomIn.apply @leafletMap, arguments
    this

  zoomOut: ->
    @leafletMap.zoomOut.apply @leafletMap, arguments
    this

  showLayer: (layer) ->
    @_groupsManager.show.apply @_groupsManager, arguments
    this

  hideLayer: (layer) ->
    @_groupsManager.hide.apply @_groupsManager, arguments
    this

  addLayer: (layer) ->
    @_groupsManager.addGroup.apply @_groupsManager, arguments
    this

  getLayers: ->
    @_groupsManager.getGroups.apply @_groupsManager, arguments

  getURL: (feature) ->
    url = feature?.properties?[@getOption 'urlPropertyName']
    return url if url?
    url = Meppit.interpolate @getOption('featureURL'), baseURL: @_getBaseURL()
    Meppit.interpolate url, id: @_getGeoJSONId(feature)

  refresh: ->
    @leafletMap._onResize()
    this

  locate: (onSuccess, onError, timeout=5000) ->
    timer = null
    _locationFromIP = ->
      ipPos = L.GeoIP.getPosition()
      if ipPos? and ipPos.lat isnt 0 and ipPos.lng isnt 0
        _onSuccess {
            latlng: ipPos
            bounds: L.latLngBounds [[ipPos.lat - 0.05, ipPos.lng - 0.05],
                                    [ipPos.lat + 0.05, ipPos.lng + 0.05]]
        }
        return true
      else
        return false

    # binds events
    _onSuccess = (e) ->
      clearTimeout timer
      bbox = if not e.bounds then undefined else
        [[e.bounds.getWest(), e.bounds.getSouth()],
         [e.bounds.getEast(), e.bounds.getNorth()]]
      coordinates = if not e.latlng then undefined else
        [e.latlng.lng, e.latlng.lat]
      location = if not coordinates then undefined else {
        "type": "Feature"
        "bbox": bbox
        "geometry": {
          "type": "Point",
          "coordinates": coordinates
        }
      }
      onSuccess {
        location: location
        accuracy: e.accuracy
        altitude: e.altitude
        heading: e.heading
        speed: e.speed
        timestamp: e.timestamp
      }

    _onError = (e) ->
      clearTimeout timer
      onError(e) if not _locationFromIP()

    @leafletMap.once 'locationfound', _onSuccess if onSuccess
    @leafletMap.once 'locationerror', _onError   if onError
    @leafletMap.once 'locationfound locationerror', =>
      # unbinds the unused callback
      @leafletMap.off 'locationfound', _onSuccess
      @leafletMap.off 'locationerror', _onError
    # locates the user
    @leafletMap.locate {setView: true, maxZoom: @MAXZOOM}
    timer = setTimeout ->
      _locationFromIP()
    , timeout
    this

  _getBounds: (data) ->
    layers = @_getLeafletLayers data
    bounds = undefined
    if layers.length > 0
      for layer in layers
        if layer?
          if layer.getBounds?
            bounds ?= layer.getBounds()
            bounds.extend layer.getBounds()
          else if layer.getLatLng?
            bounds ?= L.latLngBounds [layer.getLatLng()]
            bounds.extend layer.getLatLng()
    else if data.bbox
      bounds = L.latLngBounds [[L.latLng(data.bbox[0][1], data.bbox[0][0])],
                               [L.latLng(data.bbox[1][1], data.bbox[1][0])]]
    bounds

  _getBaseURL: ->
    baseElements = document.getElementsByTagName 'base'
    baseDocument = 'index.html'
    baseURL = @getOption 'baseURL'
    return baseURL if baseURL?
    if baseElements.length > 0
      baseElements[0].href.replace baseDocument, ""
    else
      location.protocol + '//' + location.hostname + (
          if location.port isnt '' then (':' + location.port) else '' ) + "/"

  _getGeoJsonTileURL: ->
    Meppit.interpolate @getOption('geojsonTileURL'), baseURL: @_getBaseURL()

  _ensureLeafletMap: ->
    @element ?= if Meppit.isString @getOption('element')
      document.getElementById @getOption 'element'
    else
      @getOption 'element'
    @leafletMap ?= new L.Map @element, @__getLeafletMapOptions()

  _ensureGeoJsonManager: ->
    @leafletLayers ?= {}
    onEachFeatureCallback = (feature, layer) =>
      @__saveFeatureLayerRelation feature, layer
      @__addLayerEventListeners feature, layer
    styleCallback = =>
      # TODO
    pointToLayerCallback = (feature, latLng) =>
      L.circleMarker latLng,
        weight: 5
        radius: 7
    options =
      style: styleCallback
      onEachFeature: onEachFeatureCallback
      pointToLayer: pointToLayerCallback
    @_geoJsonManager ?= new L.GeoJSON([], options).addTo @leafletMap
    @_geoJsonManager.on 'layeradd', (evt) =>
      @__addLayerToGroups evt.layer
    @__geoJsonTileLayer ?= (new L.TileLayer.GeoJSON(@_getGeoJsonTileURL(), {
      unique: (feature) =>
        @_getGeoJSONId feature
      }, this)).addTo @leafletMap if @getOption 'enableGeoJsonTile'

  _ensureGroupsManager: ->
    @_groupsManager ?= new Meppit.GroupsManager?(this, @options) ?
        @warn 'Groups manager have not been loaded'
    @_groupsManager

  _ensureEditorManager: ->
    if not @getOption 'enableEditor'
      @warn 'Editor manager have been disabled'
      return
    @_editorManager ?= new Meppit.EditorManager?(this, @options) ?
        @warn 'Editor manager have not been loaded'
    @_editorManager

  _ensurePopupManager: ->
    if not @getOption 'enablePopup'
      @warn 'Popup manager have been disabled'
      return
    @_popupManager ?= new Meppit.PopupManager?(this, @options) ?
        @warn 'Popup manager have not been loaded'
    @_popupManager

  _ensureTileProviders: ->
    @tileProviders ?= {}
    @tileProviders.map ?= new L.TileLayer(
        'http://{s}.mqcdn.com/tiles/1.0.0/map/{z}/{x}/{y}.png',
            attribution: 'Data, imagery and map information provided by '+
            '<a href="http://www.mapquest.com/">MapQuest</a>, '+
            '<a href="http://www.openstreetmap.org/">Open Street Map</a> '+
            'and contributors, <a href="http://creativecommons.org/'+
            'licenses/by-sa/2.0/">CC-BY-SA</a>.'
            subdomains: ['otile1', 'otile2', 'otile3', 'otile4'] )
    @tileProviders.satellite ?= new L.TileLayer(
        'http://{s}.mqcdn.com/tiles/1.0.0/sat/{z}/{x}/{y}.jpg',
            attribution: 'Data and imagery provided by ' +
            '<a href="http://www.mapquest.com/">MapQuest</a>a>. ' +
            'Portions Courtesy NASA/JPL-Caltech and ' +
            'U.S. Depart. of Agriculture, Farm Service Agency.'
            subdomains: ['otile1', 'otile2', 'otile3', 'otile4'] )
    @tileProviders

  _addLeafletControl: ->
    @leafletMap.addControl.apply @leafletMap, arguments

  _getGeoJSONId: (feature) ->
    return feature if Meppit.isNumber feature  # the argument is the id itself
    feature.properties?[@getOption 'idPropertyName'] or feature[@getOption 'idPropertyName']

  _getGeoJSONHash: (feature) ->
    Meppit.getHash JSON.stringify(feature)

  _getLeafletLayers: (data) ->
    if data.type is 'FeatureCollection'
        features = data.features.slice()
    else
        features = [data]
    layers = (@_getLeafletLayer feature for feature in features)
    return [] if layers.length is 1 and layers[0] is undefined
    layers

  _getLeafletLayer: (data) ->
    if Meppit.isNumber(data) or Meppit.isString(data)
      @leafletLayers[data]
    else if data?
      @_getLeafletLayer(@_getGeoJSONId(data) ? @_getGeoJSONHash(data))

  _removeLeafletLayer: (layer) ->
    return if not layer?
    @_geoJsonManager.removeLayer layer
    @__clearLayerEventListeners layer
    # Remove the reference from hash used to associate the feature id
    # with the leaflet layer
    geoJSON = layer.toGeoJSON()
    @leafletLayers?[@_getGeoJSONId geoJSON ? @_getGeoJSONHash geoJSON] =
        undefined

  __addLayerEventListeners: (feature, layer) ->
    layer.on 'click', (e) => @openPopupAt feature, undefined, e.latlng

  __clearLayerEventListeners: (layer) ->
    layer.off 'click'

  __getLeafletMapOptions: ->
    center: @getOption 'center'
    zoom: @getOption 'zoom'

  __saveFeatureLayerRelation: (feature, layer) ->
    # FIXME: Prevent collisions
    hash = feature.properties?.id ? @_getGeoJSONHash(feature)
    @leafletLayers[hash] = layer

  __defineLeafletDefaultImagePath: ->
    return if L.Icon.Default.imagePath?
    scripts = document.getElementsByTagName 'script'
    meppitMapRe = /[\/^]meppit-map[\-\._]?([\w\-\._]*)\.js\??/
    imagePath = '/assets'
    for script in scripts
      src = script.src
      if src.match meppitMapRe
        path = src.split(meppitMapRe)[0]
        imagePath = (if path then path + '/' else '') + 'images'
        break
    L.Icon.Default.imagePath = imagePath

  __addLayerToGroups: (layer) ->
    @_groupsManager.addLayer layer

window.Meppit.Map = Map
