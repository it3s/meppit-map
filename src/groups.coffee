class GroupsManager extends Meppit.BaseClass
  defaultOptions:
    foo: 'bar'

  constructor: (@map, @options = {}) ->
    super
    @log 'Initializing Groups Manager...'
    @__groups = {}
    @loadGroups @options.groups ? @options.layers

  loadGroups: (groups) ->
    return if not groups?
    @addGroup group for group in groups
    this

  addGroup: (group) ->
    return if @hasGroup group
    @log "Adding Group '#{group.name}'..."
    @_createGroup group
    @_populateGroup group
    @_refreshGroup group
    this

  addFeature: (feature) ->
    # TODO

  _getGroupId: (group) ->
    # TODO: create an unique identifier if there is no `group.id`
    group.id

  _createGroup: (group) ->
    featureGroup = @_createLeafletFeatureGroups group
    @__groups[@_getGroupId group] =
      featureGroup: featureGroup
      groupData: group

  _populateGroup: (group) ->
    # TODO

  _refreshGroup: (group) ->
    # TODO

  hasGroup: (group) ->
    false #TODO

  _createLeafletFeatureGroups: (group) ->
    L.featureGroup()

window.Meppit.GroupsManager = GroupsManager
