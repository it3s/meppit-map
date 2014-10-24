define ['../dist/meppit-map', '../lib/leaflet'],
    (Meppit, L) ->
  'use strict'

  describe 'Groups', ->
    beforeEach ->
      @geoJsonPoint =
        "type": "Feature",
        "geometry":
          "type": "Point"
          "coordinates": [45, -23]
      @geoJsonPolygon =
        "type": "Feature",
        "geometry":
          "type": "Polygon"
          "coordinates": [[[45, -23], [46, -22], [45, -23]]]
      @map = new Meppit.Map()
      @groups = new Meppit.GroupsManager(@map)
      @groupA =
        id: 0
        name: 'LayerA'
        position: 0
        fillColor: '#ff0000'
        strokeColor: '#0000ff'
        rule:
          operator: 'in'
          property: 'tags'
          value: ['a']

    afterEach ->
      @map.destroy()
      @map = null
      @groups = null

    describe 'initialization', ->
      it 'should load groups from options param', ->
        groups = [@groupA]
        sinon.spy Meppit.GroupsManager.prototype, 'loadGroups'
        manager = new Meppit.GroupsManager @map, groups: groups
        expect(manager.loadGroups.calledOnce).to.be.true
        expect(manager.loadGroups.calledWith groups).to.be.true
        Meppit.GroupsManager.prototype.loadGroups.restore()
