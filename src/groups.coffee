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
  constructor: (@data) ->
    @_initializeData()
    @__featureGroup = @_createLeafletFeatureGroup()

  getName: ->
    @data.name

  addLayer: (layer) ->
    @__featureGroup.addLayer layer

  match: (feature) ->
    eval_expr @rule, feature

  _initializeData: ->
    @name = @data.name
    @id = @data.id
    @rule = @data.rule

  _createLeafletFeatureGroup: ->
    L.featureGroup()


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

  addGroup: (group) ->
    return if @hasGroup group
    @log "Adding group '#{group.name}'..."
    @_createGroup group
    @_populateGroup group
    @_refreshGroup group
    this

  count: -> @__groupsIds.length

  addFeature: (feature) ->
    return if @count() is 0
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

  _createGroup: (group) ->
    groupId = @_getGroupId group
    @__groupsIds.push groupId
    @__groups[groupId] = new Group group

  _createDefaultGroup: ->
    @__defaultGroup = new Group name: 'Others'

  _populateGroup: (group) ->
    # TODO

  _refreshGroup: (group) ->
    # TODO

  hasGroup: (group) ->
    @_getGroupId(group) in @__groupsIds

window.Meppit.GroupsManager = GroupsManager
