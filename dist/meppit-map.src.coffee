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
  month = date.getMonth()
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

class EditorManager extends Meppit.BaseClass
  # TODO: implement undo
  defaultOptions:
    drawControl: false

  constructor: (@map, @options = {}) ->
    super
    @log 'Initializing Editor Manager...'
    @_applyFixes()
    @_initToolbars()
    @_uneditedLayerProps = {}

  edit: (data, callback) ->
    layer = @map._getLeafletLayers(data)[0]
    return if @_currentLayer? and @_currentLayer is layer
    @done()
    @_currentCallback = callback
    @_currentLayer = layer
    edit = =>
      return if not @_currentLayer
      @_backupLayer @_currentLayer
      enable = (layer) ->
        return if not layer
        layer.editing?.enable()  # Paths
        layer.dragging?.enable()  # Markers
        enable layer_ for id, layer_ of layer._layers if layer._layers? # Collection
      enable @_currentLayer
      @map.editing = true
    # Try to load the data if it was not found
    if @_currentLayer
      edit()
    else
      @map.load data, =>
        @_currentLayer = @map._getLeafletLayers(data)[0]
        edit()

  draw: (data, callback) ->
    @cancel()
    @_currentCallback = callback
    @map.editing = true
    type = if Meppit.isString data then data else data.geometry.type
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
    @revert()
    @done()  # FIXME: Should we call the same callback here?
    @map.editing = false

  revert: ->
    @_revertLayer @_currentLayer

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
      # Marker
      else if layer instanceof L.Marker or layer instanceof L.CircleMarker
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
      # Marker
      else if layer instanceof L.Marker or layer instanceof L.CircleMarker
        layer.setLatLng this._uneditedLayerProps[id].latlng


  _applyFixes: ->
    # Remove resize handler from CircleMarker
    # https://github.com/Leaflet/Leaflet.draw/issues/226
    L.Edit.CircleMarker = L.Edit.Circle.extend
      _resize: ->

    L.CircleMarker.addInitHook ->
      if L.Edit.CircleMarker
        @editing = new L.Edit.CircleMarker(this)
        @editing.enable() if @options.editable

      @on 'add',    -> @editing.addHooks()    if @editing?.enabled()
      @on 'remove', -> @editing.removeHooks() if @editing?.enabled()

window.Meppit.EditorManager = EditorManager

equal_ops = ['==', 'is', 'equal', 'equals']
not_equal_ops = ['!=', 'isnt', 'not equal', 'not equals', 'different']
in_ops = ['in']
contains_ops = ['contains', 'has']
not_ops = ['!', 'not']
or_ops = ['or']
and_ops = ['and']

# Unused possibilities are temporarily commented
eval_expr = (expr, obj) ->
  return true if not expr? or not expr.operator?
  #return false if not obj?
  operator = expr.operator
  objValue = obj[expr.property] ? obj.properties[expr.property]
  #if operator in equal_ops
  #  objValue is expr.value
  #else if operator in not_equal_ops
  #  not objValue is expr.value
  #else if operator in in_ops
  #  objValue? and objValue in expr.value
  #else ...
  if operator in contains_ops and Object.prototype.toString.call(expr.value) is '[object Array]'
    res = true
    for v in expr.value
      res = res and objValue? and v in objValue
    res
  #else if operator in contains_ops
  #  objValue and expr.value in objValue
  #else if operator in not_ops
  #  not eval_expr(expr.child, obj)
  #else if operator in or_ops
  #  eval_expr(expr.left, obj) or eval_expr(expr.right, obj)
  #else if operator in and_ops
  #  eval_expr(expr.left, obj) and eval_expr(expr.right, obj)

class Group extends Meppit.BaseClass
  POSITION: 999
  FILLCOLOR: '#0000ff'
  STROKECOLOR: '#0000ff'
  FILLOPACITY: 0.4
  STROKEOPACITY: 0.8
  WEIGHT: 3

  constructor: (@map, @data) ->
    super
    @_initializeData()
    @_featureGroup = @_createLeafletFeatureGroup()
    @refresh()

  hide: ->
    @visible = false
    @_featureGroup.eachLayer (layer) =>
      @_hideLayer layer
    this

  show: ->
    @visible = true
    @_featureGroup.eachLayer (layer) =>
      @_showLayer layer
    this

  refresh: ->
    if @visible is true then @show() else @hide()
    @_featureGroup.setStyle @__style
    this

  match: (feature) ->
    feature = feature.feature if feature?.feature  # Accept Leaflet Layer
    eval_expr @rule, feature

  addLayer: (layer) ->
    return if @hasLayer layer
    @_featureGroup.addLayer layer
    @_setLayerVisibility layer
    @_setLayerStyle layer
    this

  hasLayer: (layer) ->
    @_featureGroup.hasLayer layer

  getLayers: ->
    @_featureGroup.getLayers()

  count: ->
    @getLayers().length

  removeLayer: (layer) ->
    @_featureGroup.removeLayer layer
    this

  _initializeData: ->
    @name = @data.name
    @id = @data.id
    @position = @data.position ? @POSITION
    @strokeColor = @data.strokeColor ? @data.stroke_color ? @STROKECOLOR
    @fillColor = @data.fillColor ? @data.fill_color ? @FILLCOLOR
    @rule = @data.rule
    @visible = @data.visible ? true
    @__style =
      color: @strokeColor
      fillColor: @fillColor
      weight: @WEIGHT
      opacity: @STROKEOPACITY
      fillOpacity: @FILLOPACITY
    this

  _createLeafletFeatureGroup: ->
    featureGroup = L.geoJson()
    featureGroup.on 'layeradd', (evt) =>
      @_setLayerVisibility evt.layer
      @_setLayerStyle evt.layer
    featureGroup

  _hideLayer: (layer) ->
    if @map.leafletMap.hasLayer(layer)
      @map.leafletMap.removeLayer(layer)
    this

  _showLayer: (layer) ->
    if not @map.leafletMap.hasLayer(layer)
      @map.leafletMap.addLayer(layer)
    this

  _setLayerStyle: (layer) ->
    layer.setStyle? @__style
    this

  _setLayerVisibility: (layer) ->
    @_hideLayer(layer) if not @visible
    this


class GroupsManager extends Meppit.BaseClass
  constructor: (@map, @options = {}) ->
    super
    @log 'Initializing Groups Manager...'
    @__groups = {}
    @__groupsIds = []
    @_createDefaultGroup()
    @loadGroups @options.groups ? @options.layers

  loadGroups: (groups) ->
    return if not groups?
    @addGroup group for group in groups
    this

  addGroup: (data) ->
    return if @hasGroup data
    group = @_createGroup data
    @log "Adding group '#{group.name}'..."
    @_populateGroup group
    this

  removeGroup: (data) ->
    group = @getGroup data
    return if not group?
    @log "Removing group '#{group.name}'..."
    groupId = @_getGroupId(group)
    groupsIds = (id for id in @__groupsIds when id isnt groupId)
    @__groupsIds = groupsIds
    @__groups[groupId] = undefined
    this

  getGroup: (id) ->
    if id instanceof Group
      id
    else if Meppit.isNumber id
      @__groups[id]
    else if id?.id?
      @getGroup id.id

  getGroups: ->
    groups = (@__groups[groupId] for groupId in @__groupsIds)
    groups.push @__defaultGroup
    groups

  hasGroup: (group) ->
    @_getGroupId(group) in @__groupsIds

  show: (id) ->
    @getGroup(id)?.show()
    this

  hide: (id) ->
    @getGroup(id)?.hide()
    this

  count: -> @__groupsIds.length

  addFeature: (feature) ->
    group = @_getGroupFor feature
    @log "Adding feature '#{feature.properties?.name}' to group '#{group.name}'..."
    layer = @map._getLeafletLayer feature
    group.addLayer layer
    this

  addLayer: (layer) ->
    group = @_getGroupFor layer.feature
    @log "Adding feature '#{layer.feature.properties?.name}' to group '#{group.name}'..."
    group.addLayer layer
    this

  _getGroupFor: (feature) ->
    for group in @getGroups()
      return group if group.match feature
    return @__defaultGroup

  _getGroupId: (group) ->
    # TODO: create an unique identifier if there is no `group.id`
    group.id

  _createGroup: (data) ->
    groupId = @_getGroupId data
    @__groupsIds.push groupId
    @__groups[groupId] = new Group @map, data

  _createDefaultGroup: ->
    @__defaultGroup = new Group @map,
      id: -1
      name: 'Others'
    @__groups[-1] = @__defaultGroup

  _populateGroup: (group) ->
    for g in @getGroups() when g.position > group.position
      for l in g.getLayers()
        if group.match l
          g.removeLayer l
          group.addLayer l

window.Meppit.Group = Group
window.Meppit.GroupsManager = GroupsManager

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
    mapboxToken: __testing ? __testToken : undefined

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
        'https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}',
            attribution: 'Map data &copy; ' +
            '<a href="http://openstreetmap.org">OpenStreetMap</a> contributors, ' +
            '<a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, ' +
            'Imagery © <a href="http://mapbox.com">Mapbox</a>',
            maxZoom: 18,
            id: 'mapbox.streets',
            accessToken: @getOption('mapboxToken')
    )
    @tileProviders.satellite ?= new L.TileLayer(
        'https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}',
            attribution: 'Map data &copy; ' +
            '<a href="http://openstreetmap.org">OpenStreetMap</a> contributors, ' +
            '<a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, ' +
            'Imagery © <a href="http://mapbox.com">Mapbox</a>',
            maxZoom: 18,
            id: 'mapbox.satellite',
            accessToken: @getOption('mapboxToken')
    )
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

class Popup extends Meppit.BaseClass
  defaultOptions:
    popupTemplate: '<h1 class="title"><a href="#{url}">#{name}</a></h1>'

  constructor: (@map, @options) ->
    @_createPopup()

  open: (data, content, latLng) ->
    return if @map.editing
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
    content = Meppit.interpolate template, feature.properties
    # interpolate urls and images
    content = Meppit.interpolate content, url: @map.getURL feature
    content

  _createPopup: -> @_popup = new L.Popup()

window.Meppit.PopupManager = Popup
