define ['../dist/meppit-map', '../lib/leaflet', '../lib/leaflet.draw'],
    (Meppit_, L) ->
  'use strict'

  describe 'EditorManager', ->

    beforeEach ->
      @mapStub = sinon.createStubInstance Meppit.Map
      @editor = new Meppit.EditorManager @mapStub, drawControl: false

    afterEach ->
      @mapStub.destroy()
      @mapStub = null
      @editor = null

    describe '#_initToolbars', ->
      it 'is created if map has the option "drawControl"', ->
        editor = new Meppit.EditorManager @mapStub, drawControl: true
        expect(@mapStub._addLeafletControl.calledOnce).to.be.true

      it 'is not created if map hasn\'t the option "drawControl"', ->
        editor = new Meppit.EditorManager @mapStub, drawControl: false
        expect(@mapStub._addLeafletControl.notCalled).to.be.true

    describe '#edit', ->
      it 'enables the path edit mode', ->
        fakeLayer = editing: enable: sinon.spy()
        @mapStub._getLeafletLayers.returns [fakeLayer]
        @editor.edit 1
        expect(fakeLayer.editing.enable.calledOnce).to.be.true

      it 'enables the marker edit mode', ->
        fakeLayer = dragging: enable: sinon.spy()
        @mapStub._getLeafletLayers.returns [fakeLayer]
        @editor.edit 1
        expect(fakeLayer.dragging.enable.calledOnce).to.be.true

      it 'does nothing if try to edit the layer already been edited', ->
        fakeLayer = editing: enable: sinon.spy()
        @mapStub._getLeafletLayers.returns [fakeLayer]
        @editor.edit 1
        @editor.edit 1
        expect(fakeLayer.editing.enable.calledOnce).to.be.true

      it 'loads new GeoJSON then enable the layer edit mode', ->
        fakeLayer = editing: enable: sinon.spy()
        @mapStub._getLeafletLayers.onFirstCall().returns [undefined]
        @mapStub._getLeafletLayers.onSecondCall().returns [fakeLayer]
        @mapStub.load.yields [@geoJsonPoint]
        @editor.edit @geoJsonPoint
        expect(fakeLayer.editing.enable.calledOnce).to.be.true
        expect(@mapStub.load.calledWith @geoJsonPoint).to.be.true
        expect(@mapStub.load.calledOnce).to.be.true

    describe '#done', ->
      it 'calls the callback passed to #edit', ->
        @mapStub._getLeafletLayers.returns [
          editing:
            enable: ->
            disable: ->
          toGeoJSON: -> 'GeoJSON'
        ]
        callback = sinon.spy()
        @editor.edit 1, callback
        @editor.done()
        expect(callback.calledWith 'GeoJSON').to.be.true
        expect(callback.calledOnce).to.be.true

      it 'disables the edit mode', ->
        disableSpy = sinon.spy()
        @mapStub._getLeafletLayers.returns [
          editing:
            enable: ->
            disable: disableSpy
          toGeoJSON: -> 'GeoJSON'
        ]
        callback = sinon.spy()
        @editor.edit 1, callback
        @editor.done()
        expect(disableSpy.calledOnce).to.be.true

      it 'disables dragging', ->
        disableSpy = sinon.spy()
        @mapStub._getLeafletLayers.returns [
          dragging:
            enable: ->
            disable: disableSpy
          toGeoJSON: -> 'GeoJSON'
        ]
        callback = sinon.spy()
        @editor.edit 1, callback
        @editor.done()
        expect(disableSpy.calledOnce).to.be.true

    describe '#cancel', ->
      it 'disables the edit mode', ->
        disableSpy = sinon.spy()
        @mapStub._getLeafletLayers.returns [
          editing:
            enable: ->
            disable: disableSpy
          toGeoJSON: -> 'GeoJSON'
        ]
        callback = sinon.spy()
        @editor.edit 1, callback
        @editor.cancel()
        expect(disableSpy.calledOnce).to.be.true

      it 'reverts the layer', ->
        disableSpy = sinon.spy()
        layer =
          editing:
            enable: ->
            disable: disableSpy
          toGeoJSON: -> 'GeoJSON'
        @mapStub._getLeafletLayers.returns [layer]
        callback = sinon.spy()
        revertSpy = sinon.spy @editor, '_revertLayer'
        @editor.edit 1, callback
        @editor.cancel()
        expect(disableSpy.calledOnce).to.be.true
        expect(revertSpy.calledWith layer).to.be.true
        expect(revertSpy.calledOnce).to.be.true

    describe '#draw', ->
      beforeEach ->
        @map = new Meppit.Map()
        @editor = new Meppit.EditorManager @map, drawControl: false

      afterEach ->
        @map.destroy()
        @map = null
        @editor = null

      it 'sets map.editing to true', ->
        expect(@map.editing).to.be.false
        @editor.draw
          "type": "Feature",
          "geometry":
              "type": "Point"
              "coordinates": []
        expect(@map.editing).to.be.true

      it 'accepts point GeoJSON', (done) ->
        @editor.draw {
          "type": "Feature",
          "geometry":
              "type": "Point"
              "coordinates": []
          }, (feature) =>
            expect(feature.geometry.type).to.equal 'Point'
            done()
        expect(@editor._drawing).not.to.be.undefined
        simulate @map.element, 'mousemove'
        simulate @map.element, 'click'

      it 'accepts polygon GeoJSON', (done) ->
        @editor.draw {
          "type": "Feature",
          "geometry":
              "type": "Polygon"
              "coordinates": []
          }, (feature) =>
            expect(feature.geometry.type).to.equal 'Polygon'
            done()
        simulate @map.element, 'mousemove'
        @editor._drawing.addVertex L.latLng(0, 0)
        @editor._drawing.addVertex L.latLng(10, 0)
        @editor._drawing.addVertex L.latLng(5, 5)
        @editor._drawing.addVertex L.latLng(0, 0)
        @editor._drawing._markers[0].fire 'click'

      it 'accepts linestring GeoJSON', (done) ->
        @editor.draw {
          "type": "Feature",
          "geometry":
              "type": "LineString"
              "coordinates": []
          }, (feature) =>
            expect(feature.geometry.type).to.equal 'LineString'
            done()
        simulate @map.element, 'mousemove'
        @editor._drawing.addVertex L.latLng(0, 0)
        @editor._drawing.addVertex L.latLng(10, 0)
        @editor._drawing._markers[1].fire 'click'

      it 'accepts geometry type', (done) ->
        @editor.draw 'Point', (feature) =>
            expect(feature.geometry.type).to.equal 'Point'
            done()
        simulate @map.element, 'mousemove'
        simulate @map.element, 'click'

      it 'callback is optional', () ->
        @editor.draw 'Point'
        simulate @map.element, 'mousemove'
        simulate @map.element, 'click'

      it 'preserves feature properties', (done) ->
        properties =
          "id": 42
          "foo": 'bar',
          "spam": 'eggs'
        @editor.draw {
          "type": "Feature",
          "geometry":
              "type": "Point"
              "coordinates": []
          "properties": properties
          }, (feature) =>
            expect(feature.properties).to.eql properties
            done()
        simulate @map.element, 'mousemove'
        simulate @map.element, 'click'

    describe '#_backupLayer', ->
      it 'accepts L.Marker', ->
        layer = new L.Marker [50.5, 30.5]
        spy = sinon.spy(layer, 'getLatLng')
        expect(@editor._uneditedLayerProps[L.Util.stamp layer]).not.to.exist
        @editor._backupLayer layer
        expect(@editor._uneditedLayerProps[L.Util.stamp layer]).to.exist
        expect(spy.calledOnce).to.be.true

      it 'accepts L.Polyline', ->
        layer = new L.Polyline [[45, -23], [46, -22]]
        spy = sinon.spy(layer, 'getLatLngs')
        expect(@editor._uneditedLayerProps[L.Util.stamp layer]).not.to.exist
        @editor._backupLayer layer
        expect(@editor._uneditedLayerProps[L.Util.stamp layer]).to.exist
        expect(spy.calledOnce).to.be.true

      it 'accepts L.Polygon', ->
        layer = new L.Polygon [[[45, -23], [46, -22], [45, -23]]]
        spy = sinon.spy(layer, 'getLatLngs')
        expect(@editor._uneditedLayerProps[L.Util.stamp layer]).not.to.exist
        @editor._backupLayer layer
        expect(@editor._uneditedLayerProps[L.Util.stamp layer]).to.exist
        expect(spy.calledOnce).to.be.true

    describe '#_restoreLayer', ->
      it 'accepts L.Marker', ->
        layer = new L.Marker [50.5, 30.5]
        orig = layer.toGeoJSON()
        @editor._backupLayer layer
        layer.setLatLng [60, 70]
        expect(layer.toGeoJSON()).to.not.be.eql orig
        @editor._revertLayer layer
        expect(layer.toGeoJSON()).to.be.eql orig

      it 'accepts L.Polyline', ->
        layer = new L.Polyline [[45, -23], [46, -22]]
        orig = layer.toGeoJSON()
        @editor._backupLayer layer
        layer.setLatLngs [[65, -23], [66, -22]]
        expect(layer.toGeoJSON()).to.not.be.eql orig
        @editor._revertLayer layer
        expect(layer.toGeoJSON()).to.be.eql orig

      it 'accepts L.Polygon', ->
        layer = new L.Polygon [[[45, -23], [46, -22], [45, -23]]]
        orig = layer.toGeoJSON()
        @editor._backupLayer layer
        layer.setLatLngs [[65, -23], [66, -22], [65, -23]]
        expect(layer.toGeoJSON()).to.not.be.eql orig
        @editor._revertLayer layer
        expect(layer.toGeoJSON()).to.be.eql orig
