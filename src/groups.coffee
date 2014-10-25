equal_ops = ['==', 'is', 'equal', 'equals']
not_equal_ops = ['!=', 'isnt', 'not equal', 'not equals', 'different']
in_ops = ['in']
contains_ops = ['contains', 'has']
not_ops = ['!', 'not']
or_ops = ['or']
and_ops = ['and']

eval_expr = (expr, obj) ->
  return true if not expr? or not expr.operator?
  return false if not obj?
  operator = expr.operator
  objValue = obj[expr.property] ? obj.properties[expr.property]
  if operator in equal_ops
    objValue is expr.value
  else if operator in not_equal_ops
    not objValue is expr.value
  else if operator in in_ops
    objValue? and objValue in expr.value
  else if operator in contains_ops and Object.prototype.toString.call(expr.value) is '[object Array]'
    res = true
    for v in expr.value
      res = res and objValue? and v in objValue
    res
  else if operator in contains_ops
    objValue and expr.value in objValue
  else if operator in not_ops
    not eval_expr(expr.child, obj)
  else if operator in or_ops
    eval_expr(expr.left, obj) or eval_expr(expr.right, obj)
  else if operator in and_ops
    eval_expr(expr.left, obj) and eval_expr(expr.right, obj)

class Group extends Meppit.BaseClass
  FILLCOLOR: '#0000ff'
  STROKECOLOR: '#0000ff'
  FILLOPACITY: 0.4
  STROKEOPACITY: 0.8

  constructor: (@map, @data) ->
    @_initializeData()
    @_featureGroup = @_createLeafletFeatureGroup()
    @refresh()

  getName: ->
    @data.name

  addLayer: (layer) ->
    @_featureGroup.addLayer layer

  getLayers: ->
    @_featureGroup.getLayers()

  removeLayer: (layer) ->
    @_featureGroup.removeLayer layer

  match: (feature) ->
    feature = feature.feature if feature?.feature  # Accept Leaflet Layer
    eval_expr @rule, feature

  hide: ->
    @visible = false
    @_featureGroup.eachLayer (layer) =>
      @_hideLayer layer

  show: ->
    @visible = true
    @_featureGroup.eachLayer (layer) =>
      @_showLayer layer

  refresh: ->
    if @visible is true then @show() else @hide()
    @_featureGroup.setStyle @__style

  _initializeData: ->
    @name = @data.name
    @id = @data.id
    @position = @data.position ? 999
    @strokeColor = @data.strokeColor ? @data.stroke_color ? @STROKECOLOR
    @fillColor = @data.fillColor ? @data.fill_color ? @FILLCOLOR
    @rule = @data.rule
    @visible = @data.visible ? true
    @__style =
      color: @strokeColor
      fillcolor: @fillColor
      weight: 5
      opacity: @STROKEOPACITY
      fillOpacity: @FILLOPACITY

  _createLeafletFeatureGroup: ->
    featureGroup = L.geoJson()
    featureGroup.on 'layeradd', (evt) =>
      @_setLayerVisibility evt.layer
      @_setLayerStyle evt.layer
    featureGroup

  _hideLayer: (layer) ->
    if @map.leafletMap.hasLayer(layer)
      @map.leafletMap.removeLayer(layer)

  _showLayer: (layer) ->
    if not @map.leafletMap.hasLayer(layer)
      @map.leafletMap.addLayer(layer)

  _setLayerStyle: (layer) ->
    layer.setStyle? @__style

  _setLayerVisibility: (layer) ->
    @_hideLayer(layer) if not @visible


class GroupsManager extends Meppit.BaseClass
  defaultOptions:
    foo: 'bar'

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

  getGroup: (id) ->
    if id instanceof Group
      id
    else if Meppit.isNumber id
      @__groups[id]
    else if id?.id?
      @getGroup id.id

  show: (id) ->
    @getGroup(id)?.show()

  hide: (id) ->
    @getGroup(id)?.hide()

  count: -> @__groupsIds.length

  addFeature: (feature) ->
    group = @_getGroupFor feature
    @log "Adding feature '#{feature.properties?.name}' to group '#{group.name}'..."
    layer = @map._getLeafletLayer feature
    group.addLayer layer

  addLayer: (layer) ->
    group = @_getGroupFor layer.feature
    @log "Adding feature '#{layer.feature.properties?.name}' to group '#{group.name}'..."
    group.addLayer layer

  getGroups: ->
    groups = (@__groups[groupId] for groupId in @__groupsIds)
    groups.push @__defaultGroup
    groups

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
    @__defaultGroup = new Group @map, name: 'Others'

  _populateGroup: (group) ->
    for g in @getGroups() when g.position > group.position
      for l in g.getLayers()
        if group.match l
          g.removeLayer l
          group.addLayer l

  hasGroup: (group) ->
    @_getGroupId(group) in @__groupsIds

window.Meppit.GroupsManager = GroupsManager
