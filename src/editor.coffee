class EditorManager extends Meppit.BaseClass
  # TODO: implement undo
  defaultOptions:
    drawControl: false

  constructor: (@map, @options = {}) ->
    super
    @log 'Initializing Editor Manager...'
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
      @_currentLayer?.editing?.enable()  # Paths
      @_currentLayer?.dragging?.enable()  # Markers
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
