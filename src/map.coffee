class Map extends BaseClass
  defaultOptions:
    element: document.createElement 'div'
    zoom: 14
    center: [ -23.5, -46.6167 ]
    tileProvider: 'map'
    idPropertyName: 'id'
    urlPropertyName: 'url'
    featureURL: '#{baseURL}features/#{id}'
    geojsonTileURL: '#{baseURL}geoJSON/{z}/{x}/{y}'
    enableEditor: true
    enablePopup: true
    enableGeoJsonTile: false

  constructor: (@options = {}) ->
    super
    @log 'Initializing Map'
    @editing = false
    @_ensureLeafletMap()
    @_ensureTileProviders()
    @_ensureGeoJsonManager()
    @__defineLeafletDefaultImagePath()
    @selectTileProvider @getOption('tileProvider')

  destroy: -> @leafletMap.remove()

  load: (data, callback) ->
    # Loads GeoJSON `data` and then calls `callback`
    # Expect coordinates to be in [lon, lat] order
    if isNumber data  # received the feature id
      @load @getURL(data), callback
    else if isString data  # got an url
      requestJSON data, (resp) =>
        if resp
          @load resp, callback
        else
          callback? null
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
    return if not data?
    bounds = @_getBounds data
    @leafletMap.fitBounds bounds if bounds?
    this

  panTo: (data) ->
    return if not data?
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

  getURL: (feature) ->
    url = feature?.properties?[@getOption 'urlPropertyName']
    return url if url?
    url = interpolate @getOption('featureURL'), baseURL: @_getBaseURL()
    interpolate url, id: @_getGeoJSONId(feature)

  _getBounds: (data) ->
    layers = @_getLeafletLayers data
    bounds = undefined
    for layer in layers
      if layer?
        if layer.getBounds?
          bounds ?= layer.getBounds()
          bounds.extend layer.getBounds()
        else if layer.getLatLng?
          bounds ?= L.latLngBounds [layer.getLatLng()]
          bounds.extend layer.getLatLng()
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
    interpolate @getOption('geojsonTileURL'), baseURL: @_getBaseURL()

  _ensureLeafletMap: ->
    @element ?= if isString @getOption('element')
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
    options =
      style: styleCallback
      onEachFeature: onEachFeatureCallback
    @__geoJsonTileLayer ?= (new L.TileLayer.GeoJSON(@_getGeoJsonTileURL(), {
        clipTiles: true
        unique: (feature) => @_getGeoJSONId feature
      }, options)).addTo @leafletMap if @getOption 'enableGeoJsonTile'
    @_geoJsonManager ?= new L.GeoJSON([], options).addTo @leafletMap

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
    return feature if isNumber feature  # the argument is the id itself
    feature.properties?[@getOption 'idPropertyName']

  _getGeoJSONHash: (feature) ->
    getHash JSON.stringify(feature)

  _getLeafletLayers: (data) ->
    if data.type is 'FeatureCollection'
        features = data.features.slice()
    else
        features = [data]
    (@_getLeafletLayer feature for feature in features)

  _getLeafletLayer: (data) ->
    if isNumber(data) or isString(data)
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
    for script in scripts
      src = script.src
      if src.match meppitMapRe
        path = src.split(meppitMapRe)[0]
        L.Icon.Default.imagePath = (if path then path + '/' else '') + 'images'
        return

window.Meppit.Map = Map
