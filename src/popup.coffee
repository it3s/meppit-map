class Popup extends BaseClass
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
    content = interpolate template, feature.properties
    # interpolate urls and images
    content = interpolate content, url: @map.getURL feature
    content

  _createPopup: -> @_popup = new L.Popup()

window.Meppit.PopupManager = Popup
