window.Meppit ?= {}
window.Meppit.VERSION = '<%= pkg.version %>'

isArray = Meppit.isArray = (data) ->
  Object.prototype.toString.call(data) is '[object Array]'

isNumber = Meppit.isNumber = (data) ->
  typeof data is 'number'

isString = Meppit.isString = (data) ->
  typeof data is 'string'

interpolate = Meppit.interpolate = (tpl, obj) ->
  # http://javascript.crockford.com/remedial.html
  tpl.replace /#{([^#{}]*)}/g, (a, b) ->
    r = obj[b]
    if isString(r) or isNumber(r) then r else a

getHash = Meppit.getHash = (data) ->
  hash = 0
  if data.length > 0
    for i  in [0 .. data.length - 1]
      char = data.charCodeAt i
      hash = ((hash << 5) - hash) + char
      hash |= 0  # Convert to 32bit integer
  '_' + hash

getDate = Meppit.getDate = (date) ->
  months = ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December']
  date ?= new Date()
  day = date.getDate()
  month = date.getMonth() + 1
  yy = date.getYear()
  year = if yy < 1000 then yy + 1900 else yy

  "#{months[month]} #{day} #{year}"

_log = Meppit.log = ->
  args = ["[#{getDate()}]"].concat Array.prototype.slice.call(arguments)
  console?.log args.join(' ') if not window.MEPPIT_SILENCE

_warn = Meppit.warn = ->
  args = ["[#{getDate()}]"].concat Array.prototype.slice.call(arguments)
  console?.warn args.join(' ') if not window.MEPPIT_SILENCE

reverseCoordinates = Meppit.reverseCoordinates = (data) ->
  return data if isNumber(data)
  return (reverseCoordinates(i) for i in data) if isArray(data) and
                                                 isArray(data[0])
  return data.reverse() if isArray(data) and isNumber(data[0])
  if data.type is 'Feature'
    data.geometry.coordinates = reverseCoordinates data.geometry.coordinates
  else if data.type is 'FeatureCollection'
    data.features = (reverseCoordinates(feature) for feature in data.features)
  return data

requestJSON = Meppit.requestJSON = (url, callback) ->
  # TODO: Test
  req = if window.XMLHttpRequest  # Mozilla, Safari, ...
    new XMLHttpRequest()
  else if window.ActiveXObject  # IE 8 and older
    new ActiveXObject "Microsoft.XMLHTTP"
  @_requests ?= []
  @_requests.push req
  req.onreadystatechange = ->
    if req.readyState is 4
      if req.status is 200
        callback JSON.parse(req.responseText)
      else
        callback null
  req.open 'GET', url, true
  req.send()


counter = 0
class BaseClass
  VERSION: '<%= pkg.version %>'

  constructor: ->
    @cid = counter++

  log: ->
    args = ["Log: #{@constructor.name}##{@.cid} -"].concat(
        Array.prototype.slice.call(arguments))
    _log.apply this, args

  warn: ->
    args = ["Warn: #{@constructor.name}##{@.cid} -"].concat(
        Array.prototype.slice.call(arguments))
    _warn.apply this, args

  getOption: (key) ->
    @options?[key] ? @defaultOptions?[key]

  setOption: (key, value) ->
    @options ?= {}
    @options[key] = value

Meppit.BaseClass = BaseClass


define? [], -> window.Meppit

class EditorManager extends BaseClass
  # TODO: implement undo
  defaultOptions:
    drawControl: false

  constructor: (@map, @options = {}) ->
    super
    @log 'Initializing Editor Manager...'
    @_initToolbars()
    @_uneditedLayerProps = {}

  edit: (data, callback) ->
    layer = @map._getLeafletLayer data
    return if @_currentLayer? and @_currentLayer is layer
    @done()
    @_currentCallback = callback
    @_currentLayer = layer
    edit = =>
      return if not @_currentLayer
      @_backupLayer @_currentLayer
      @_currentLayer?.editing?.enable()  # Paths
      @_currentLayer?.dragging?.enable()  # Markers
      @map.editing = true
    # Try to load the data if it was not found
    if not @_currentLayer
      @map.load data, =>
        # TODO: Test me
        @_currentLayer = @map._getLeafletLayer data
        edit()
      @_currentLayer = @map._getLeafletLayer data
    edit()

  draw: (data, callback) ->
    @cancel()
    @_currentCallback = callback
    @map.editing = true
    type = if isString data then data else data.geometry.type
    type = type.toLowerCase()
    @_drawing =
      if type is 'polygon'
        new L.Draw.Polygon @map.leafletMap
      else if type is 'linestring'
        new L.Draw.Polyline @map.leafletMap
      else
        new L.Draw.Marker @map.leafletMap
    @map.leafletMap.once 'draw:created', (e) =>
      geoJSON = e.layer.toGeoJSON()
      geoJSON.properties = data.properties if data.properties?
      @map.load geoJSON
      callback? geoJSON
    @_drawing.enable()

  done: ->
    if @_currentLayer
      @_currentLayer.editing?.disable()  # Paths
      @_currentLayer.dragging?.disable()  # Markers
      @_currentCallback?(@_currentLayer.toGeoJSON())
    @_currentCallback = @_currentLayer = undefined
    @map.editing = false

  cancel: ->
    @_revertLayer @_currentLayer
    @done()  # FIXME: Should we call the same callback here?
    @map.editing = false

  _initToolbars: ->
      return if not @getOption 'drawControl'
      @_initEditToolbar()

  _initEditToolbar: ->
    # Initialise the FeatureGroup to store editable layers
    @drawnItems = @map._ensureGeoJsonManager()

    # Initialise the draw control and pass it the FeatureGroup of
    # editable layers
    @drawControl = new L.Control.Draw
        edit:
            featureGroup: @drawnItems

    @map._addLeafletControl @drawControl

  _backupLayer: (layer) ->
    # https://github.com/Leaflet/Leaflet.draw/blob/768c67892a363129c362e7bcdf562a95f592dbd7/src/edit/handler/EditToolbar.Edit.js#L103
    id = L.Util.stamp layer

    if not @_uneditedLayerProps[id]
      # Polyline or Polygon
      if layer instanceof L.Polyline or layer instanceof L.Polygon
        @_uneditedLayerProps[id] =
          latlngs: L.LatLngUtil.cloneLatLngs layer.getLatLngs()
      else if layer instanceof L.Marker  # Marker
        @_uneditedLayerProps[id] =
          latlng: L.LatLngUtil.cloneLatLng layer.getLatLng()

  _revertLayer: (layer) ->
    # https://github.com/Leaflet/Leaflet.draw/blob/768c67892a363129c362e7bcdf562a95f592dbd7/src/edit/handler/EditToolbar.Edit.js#L125
    return if not layer?
    id = L.Util.stamp layer
    layer.edited = false
    if this._uneditedLayerProps.hasOwnProperty id
      # Polyline or Polygon
      if layer instanceof L.Polyline or layer instanceof L.Polygon
        layer.setLatLngs this._uneditedLayerProps[id].latlngs
      else if layer instanceof L.Marker  # Marker
        layer.setLatLng this._uneditedLayerProps[id].latlng

window.Meppit.EditorManager = EditorManager

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
    enableGeoJsonTile: true

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
          callback? false
    else
      @_geoJsonManager.addData data
      callback? true
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
    layer = @_getLeafletLayer data
    return if not layer?
    if layer.getBounds?
      @leafletMap.fitBounds layer.getBounds()
    else if layer.getLatLng?
      @leafletMap.setView layer.getLatLng(), @leafletMap.getMaxZoom()
    this

  panTo: (data) ->
    layer = @_getLeafletLayer data
    return if not layer?
    if layer.getBounds?
      @leafletMap.panInsideBounds layer.getBounds()
    else if layer.getLatLng?
      @leafletMap.panTo layer.getLatLng()
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

class Popup extends BaseClass
  defaultOptions:
    popupTemplate: '<h1 class="title"><a href="#{url}">#{name}</a></h1>'

  constructor: (@map, @options) ->
    @_createPopup()

  open: (data, content, latLng) ->
    return if @map.editing  # TODO: test this if
    layer = @map._getLeafletLayer data
    return if not layer?
    latLng ?=
      if layer.getLatLng?
        layer.getLatLng()
      else if layer.getBounds?
        layer.getBounds().getCenter()
    @_popup.setLatLng latLng
    @_popup.setContent content ? @_getContent(layer.toGeoJSON())
    @_popup.openOn @map.leafletMap

  close: -> @map.leafletMap.closePopup @_popup

  _getContent: (feature) ->
    return '' if not feature
    template = feature.properties?.popupContent ? @getOption('popupTemplate')
    # interpolate the feature properties
    content = interpolate template, feature.properties
    # interpolate urls and images
    content = interpolate content, url: @map.getURL feature
    content

  _createPopup: -> @_popup = new L.Popup()

window.Meppit.PopupManager = Popup
