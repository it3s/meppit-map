define ['../dist/meppit-map', '../lib/leaflet'],
    (Meppit, L) ->
  'use strict'

  describe 'Group', ->
    beforeEach ->
      @map = leafletMap:
        hasLayer: sinon.stub()
        removeLayer: sinon.stub()
        addLayer: sinon.stub()
      @layerA = {id: 'A'}
      @layerB = {id: 'B'}
      @map.leafletMap.hasLayer.withArgs(@layerA).returns(true)
      @map.leafletMap.hasLayer.withArgs(@layerB).returns(false)

    describe 'Initialization', ->
      it 'sets data values', ->
        group = new Meppit.Group null,
          name: 'Name'
          id: 42
          position: 666
          strokeColor: '#123456'
          fillColor: '#654321'
          rule: 'rule'
          visible: false
          notUsed: 'this is field an extra value not used'
        expect(group.name).to.be.eq 'Name'
        expect(group.id).to.be.eq 42
        expect(group.position).to.be.eq 666
        expect(group.strokeColor).to.be.eq '#123456'
        expect(group.fillColor).to.be.eq '#654321'
        expect(group.rule).to.be.eq 'rule'
        expect(group.visible).to.be.false
        expect(group.notUsed).to.be.undefined

      it 'sets default values if some values was not passed', ->
        group = new Meppit.Group null,
          name: 'Name'
          id: 42
          rule: 'rule'
        expect(group.position).to.be.eq group.POSITION
        expect(group.strokeColor).to.be.eq group.STROKECOLOR
        expect(group.fillColor).to.be.eq group.FILLCOLOR
        expect(group.visible).to.be.true

      it 'respects the visibility from options', ->
        group = new Meppit.Group null, visible: false
        expect(group.visible).to.be.false
        group = new Meppit.Group null, visible: true
        expect(group.visible).to.be.true

    describe 'visibility', ->
      describe '#hide', ->
        it 'hides all layers added to group', ->
          group = new Meppit.Group @map, visible: true
          group.addLayer @layerA
          group.addLayer @layerB
          expect(group.hide()).to.be.eql group
          expect(@map.leafletMap.removeLayer.withArgs(@layerA).calledOnce).to.be.true
          expect(@map.leafletMap.removeLayer.withArgs(@layerB).called).to.be.false

      describe '#show', ->
        it 'shows all layers added to group', ->
          group = new Meppit.Group @map, visible: true
          group.addLayer @layerA
          group.addLayer @layerB
          expect(group.show()).to.be.eql group
          expect(@map.leafletMap.addLayer.withArgs(@layerA).called).to.be.false
          expect(@map.leafletMap.addLayer.withArgs(@layerB).calledOnce).to.be.true

    describe 'layer manipulation', ->
      describe '#getLayers', ->
        it 'returns all layers', ->
          group = new Meppit.Group @map, visible: true
          group.addLayer @layerA
          group.addLayer @layerB
          expect(group.getLayers().length).to.be.equal 2

      describe '#addLayer', ->
        it 'hides layer if group is not visible', ->
          group = new Meppit.Group @map, visible: false
          expect(group.addLayer @layerA).to.be.eql group
          expect(@map.leafletMap.removeLayer.withArgs(@layerA).called).to.be.true

        it 'doesnt hide layer if group is visible', ->
          group = new Meppit.Group @map, visible: true
          group.addLayer @layerA
          expect(@map.leafletMap.removeLayer.withArgs(@layerA).called).to.be.false

        it 'sets group style to layer', ->
          group = new Meppit.Group @map, visible: true
          @layerA.setStyle = sinon.spy()
          group.addLayer @layerA
          expect(@layerA.setStyle.withArgs(group.__style).called).to.be.true

  describe 'GroupsManager', ->
    beforeEach ->
      @geoJsonPoint =
        "type": "Feature",
        "geometry":
          "type": "Point"
          "coordinates": [45, -23]
        "properties":
          "tags": ["a", "b"]
      @geoJsonPolygon =
        "type": "Feature",
        "geometry":
          "type": "Polygon"
          "coordinates": [[[45, -23], [46, -22], [45, -23]]]
        "properties":
          "tags": ["b", "c"]
      @layerA = {id: 'A', feature: @geoJsonPoint}
      @layerB = {id: 'B', feature: @geoJsonPolygon}
      @map = new Meppit.Map()
      @groupA =
        id: 0
        name: 'LayerA'
        visible: true
        position: 0
        fillColor: '#ff0000'
        strokeColor: '#0000ff'
        rule:
          operator: 'has'
          property: 'tags'
          value: ['a']
      @groupB =
        id: 1
        name: 'LayerB'
        visible: false
        position: 1
        fillColor: '#ff0000'
        strokeColor: '#0000ff'
        rule:
          operator: 'has'
          property: 'tags'
          value: ['b']

    afterEach ->
      @map.destroy()
      @map = null

    describe 'initialization', ->
      it 'loads groups from options param', ->
        groups = [@groupA]
        sinon.spy Meppit.GroupsManager.prototype, 'loadGroups'
        groupsMgr = new Meppit.GroupsManager @map, groups: groups
        expect(groupsMgr.loadGroups.calledOnce).to.be.true
        expect(groupsMgr.loadGroups.calledWith groups).to.be.true
        Meppit.GroupsManager.prototype.loadGroups.restore()

    describe '#count', ->
      it 'returns the number of groups', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA]
        expect(groupsMgr.count()).to.be.eq 1
        groupsMgr.addGroup @groupB
        expect(groupsMgr.count()).to.be.eq 2
        groupsMgr.removeGroup @groupA
        expect(groupsMgr.count()).to.be.eq 1

    describe '#loadGroups', ->
      it 'loads a list of groups', ->
        groupsMgr = new Meppit.GroupsManager @map
        expect(groupsMgr.count()).to.be.eq 0
        expect(groupsMgr.getGroup @groupA.id).to.be.undefined
        expect(groupsMgr.loadGroups [@groupB, @groupA]).to.be.eql groupsMgr
        expect(groupsMgr.count()).to.be.eq 2
        expect(groupsMgr.getGroup(@groupA.id)).to.be.instanceOf Meppit.Group

    describe '#addGroup', ->
      it 'loads a group', ->
        groupsMgr = new Meppit.GroupsManager @map
        expect(groupsMgr.count()).to.be.eq 0
        expect(groupsMgr.getGroup @groupA.id).to.be.undefined
        expect(groupsMgr.addGroup @groupA).to.be.eql groupsMgr
        expect(groupsMgr.count()).to.be.eq 1
        expect(groupsMgr.getGroup(@groupA.id)).to.be.instanceOf Meppit.Group

      it 'populates the group', ->
        groupsMgr = new Meppit.GroupsManager @map
        layer = new L.Marker()
        layer.feature = @geoJsonPoint
        groupsMgr.addLayer layer
        expect(groupsMgr.__defaultGroup.hasLayer layer).to.be.true
        groupsMgr.addGroup @groupA
        expect(groupsMgr.getGroup(@groupA).hasLayer layer).to.be.true
        expect(groupsMgr.__defaultGroup.hasLayer layer).to.be.false

    describe '#removeGroup', ->
      it 'removes a group', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA]
        expect(groupsMgr.count()).to.be.eq 1
        expect(groupsMgr.getGroup(@groupA.id)).to.be.instanceOf Meppit.Group
        expect(groupsMgr.removeGroup @groupA).to.be.eql groupsMgr
        expect(groupsMgr.count()).to.be.eq 0
        expect(groupsMgr.getGroup @groupA.id).to.be.undefined

    describe '#getGroup', ->
      it 'accepts id as param', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA]
        expect(groupsMgr.getGroup(@groupA.id)).to.be.instanceOf Meppit.Group
        expect(groupsMgr.getGroup(@groupA.id).id).to.be.eq @groupA.id

      it 'accepts data object as param', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA]
        expect(groupsMgr.getGroup(@groupA)).to.be.instanceOf Meppit.Group
        expect(groupsMgr.getGroup(@groupA).id).to.be.eq @groupA.id

      it 'accepts a group object as param', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA]
        group = groupsMgr.getGroup @groupA
        expect(groupsMgr.getGroup(group)).to.be.instanceOf Meppit.Group
        expect(groupsMgr.getGroup(group).id).to.be.eq @groupA.id

    describe '#getGroups', ->
      it 'returns all groups, including the default group', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA, @groupB]
        expect(groupsMgr.getGroups().length).to.be.eq 3  # get default group too
        expect(groupsMgr.getGroups()[0]).to.be.instanceOf Meppit.Group
        expect(groupsMgr.getGroups()[0].id).to.be.eq 0
        expect(groupsMgr.getGroups()[1]).to.be.instanceOf Meppit.Group
        expect(groupsMgr.getGroups()[1].id).to.be.eq 1

    describe '#hasGroup', ->
      it 'verifies if the group manager has a specific group', ->
        groupsMgr = new Meppit.GroupsManager @map
        expect(groupsMgr.hasGroup @groupA).to.be.false
        groupsMgr.addGroup @groupA
        expect(groupsMgr.hasGroup @groupA).to.be.true

    describe '#addLayer', ->
      it 'adds a layer to the correct group', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA, @groupB]
        expect(groupsMgr.getGroup(@groupA).hasLayer(@layerA)).to.be.false
        expect(groupsMgr.addLayer @layerA).to.be.eql groupsMgr
        expect(groupsMgr.getGroup(@groupA).hasLayer(@layerA)).to.be.true

    describe '#addFeature', ->
      it 'adds a feature to the correct group', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA, @groupB]
        expect(groupsMgr.getGroup(@groupA).count()).to.be.eq 0
        @map.load @geoJsonPoint
        expect(groupsMgr.addFeature @geoJsonPoint).to.be.eql groupsMgr
        expect(groupsMgr.getGroup(@groupA).count()).to.be.eq 1

    describe '#show', ->
      it 'shows the group layers', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA, @groupB]
        expect(groupsMgr.getGroup(@groupB).visible).to.be.false
        expect(groupsMgr.show 1).to.be.eql groupsMgr
        expect(groupsMgr.getGroup(@groupB).visible).to.be.true

    describe '#hide', ->
      it 'hides the group layers', ->
        groupsMgr = new Meppit.GroupsManager @map, groups: [@groupA, @groupB]
        expect(groupsMgr.getGroup(@groupA).visible).to.be.true
        expect(groupsMgr.hide 0).to.be.eql groupsMgr
        expect(groupsMgr.getGroup(@groupA).visible).to.be.false
