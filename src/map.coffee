class Map extends BaseClass
  defaultOptions:
    element: document.createElement 'div'
    tileProvider: 'map'
    center: [ -23.5, -46.6167 ]
    zoom: 14
    idPropertyName: 'id'
    urlPropertyName: 'url'
    featureURL: '#{baseURL}features/#{id}'
    enableEditor: true
    enablePopup: true
    enableGeoJsonTile: true
    geojsonURL: '#{baseURL}geoJSON/{z}/{x}/{y}'

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
    # Expect coordinates to be in [lon, lat] order
    if isNumber data  # received the feature id
      @load @getURL(data), callback
    else if isString data  # got an url
      requestJSON data, (resp) =>
        if resp
          @load resp, callback
        else
          callback? false
    else
      @_geoJsonManager.addData data
      callback? true

  toGeoJSON: -> @_geoJsonManager.toGeoJSON()

  get: (id) ->
    @_getLeafletLayer(id)?.toGeoJSON()

  remove: (data) ->
    if data.type == 'FeatureCollection'
      @remove feature for feature in data.features
    else
      layer = @_getLeafletLayer data
      @leafletMap.removeLayer layer
      @__clearLayerEventListeners layer
      # Remove the reference from hash used to associate the feature id
      # with the leaflet layer
      geoJSON = layer.toGeoJSON()
      @leafletLayers?[@_getGeoJSONId geoJSON ? @_getGeoJSONHash geoJSON] =
          undefined

  edit: (data, callback) ->
    @closePopup()
    @panTo data
    @_ensureEditorManager()?.edit data, callback

  draw: (data, callback) ->
    @closePopup()
    @_ensureEditorManager()?.draw data, callback

  done: -> @_editorManager?.done()

  cancel: -> @_editorManager?.cancel()

  openPopup: (data, content) ->
    @openPopupAt data, content

  openPopupAt: (data, content, latLng) ->
    @_ensurePopupManager()?.open data, content, latLng

  closePopup: ->
    @_ensurePopupManager()?.close()

  fit: (data) ->
    layer = @_getLeafletLayer data
    return if not layer?
    if layer.getBounds?
      @leafletMap.fitBounds layer.getBounds()
    else if layer.getLatLng?
      @leafletMap.setView layer.getLatLng(), @leafletMap.getMaxZoom()

  panTo: (data) ->
    layer = @_getLeafletLayer data
    return if not layer?
    if layer.getBounds?
      @leafletMap.panInsideBounds layer.getBounds()
    else if layer.getLatLng?
      @leafletMap.panTo layer.getLatLng()

  selectTileProvider: (provider) ->
    @tileProviders[provider]?.addTo(@leafletMap)
    @currentTileProvider = provider

  clear: ->
    @_geoJsonManager.clearLayers()  # remove all layers
    @leafletLayers = {}  # clear the assossiation between layers and ids

  getZoom: -> @leafletMap.getZoom.apply @leafletMap, arguments

  setZoom: -> @leafletMap.setZoom.apply @leafletMap, arguments

  zoomIn: -> @leafletMap.zoomIn.apply @leafletMap, arguments

  zoomOut: -> @leafletMap.zoomOut.apply @leafletMap, arguments

  getURL: (feature) ->
    url = feature?.properties?[@getOption 'urlPropertyName']
    return url if url?
    url = interpolate @getOption('featureURL'), baseURL: @_getBaseURL()
    interpolate url, id: @_getGeoJSONId(feature)

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

  _getGeoJsonURL: ->
    interpolate @getOption('geojsonURL'), baseURL: @_getBaseURL()

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
    @__geoJsonTileLayer ?= (new L.TileLayer.GeoJSON(@_getGeoJsonURL(), {
        clipTiles: true
        unique: (feature) => @_getGeoJSONId feature
      }, options)).addTo @leafletMap if @getOption 'enableGeoJsonTile'
    @_geoJsonManager ?= @__geoJsonTileLayer?.geojsonLayer ? new L.GeoJSON([],
        options).addTo @leafletMap

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

  _getLeafletLayer: (data) ->
    if isNumber(data) or isString(data)
      @leafletLayers[data]
    else if data?
      @_getLeafletLayer(@_getGeoJSONId(data) ? @_getGeoJSONHash(data))

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
