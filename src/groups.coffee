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

window.ee = eval_expr

class Group extends Meppit.BaseClass
  constructor: (@map, @data) ->
    @_initializeData()
    @__featureGroup = @_createLeafletFeatureGroup()
    @refresh()

  getName: ->
    @data.name

  addLayer: (layer) ->
    @__featureGroup.addLayer layer

  match: (feature) ->
    eval_expr @rule, feature

  hide: ->
    @visible = false
    @__featureGroup.eachLayer (layer) =>
      @_hideLayer layer

  show: ->
    @visible = true
    @__featureGroup.eachLayer (layer) =>
      @_showLayer layer

  refresh: ->
    if @visible is true then @show() else @hide()

  _initializeData: ->
    @name = @data.name
    @id = @data.id
    @strokeColor = @data.strokeColor ? @data.stroke_color ? '#0000ff'
    @fillColor = @data.fillColor ? @data.fill_color ? '#0000ff'
    @rule = @data.rule
    @visible = @data.visible ? true

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
    layer.setStyle?(
      color: @strokeColor
      fillcolor: @fillColor
      weight: 5
      opacity: 0.8
      fillOpacity: 0.4
    )

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
    @__groups[id]

  count: -> @__groupsIds.length

  addFeature: (feature) ->
    group = @_getGroupFor feature
    @log "Adding feature #{feature.properties?.name} to group '#{group.name}'..."
    layer = @map._getLeafletLayer feature
    group.addLayer layer

  _getGroupFor: (feature) ->
    for groupId in @__groupsIds
      group = @__groups[groupId]
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
    # TODO
    group.refresh()

  hasGroup: (group) ->
    @_getGroupId(group) in @__groupsIds

window.Meppit.GroupsManager = GroupsManager
