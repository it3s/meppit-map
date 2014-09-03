define ['../dist/meppit-map', '../lib/leaflet', '../lib/leaflet.draw',
    '../lib/TileLayer.GeoJSON', '../lib/leaflet-geoip', '../lib/easy-button'],
    (Meppit, L) ->
  'use strict'

  describe 'Map', ->
    createFeatureCollection = (features) ->
      "type": "FeatureCollection",
      "features": features

    beforeEach ->
      # define the GeoJSON objects eache time to avoid problems if a
      # test modifies them
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


      @options =
        element: 'map-container'
        foo: 'bar'
      @map = new Meppit.Map @options

    afterEach ->
      @map.destroy()
      @map = null

    describe 'initialization', ->
      it 'has version number', ->
        expect(@map).to.have.property 'VERSION'

      it 'has leaflet map instance', ->
        expect(@map).to.have.property 'leafletMap'
        expect(@map.leafletMap).to.be.instanceof L.Map

      it 'has GeoJSON support if enableGeoJsonTile is true', ->
        map = new Meppit.Map enableGeoJsonTile: true
        expect(map).to.have.property '_geoJsonManager'
        expect(map._geoJsonManager).to.be.instanceof L.GeoJSON
        map.destroy()

      it 'has GeoJSON support if enableGeoJsonTile is false', ->
        map = new Meppit.Map enableGeoJsonTile: false
        expect(map).to.have.property '_geoJsonManager'
        expect(map._geoJsonManager).to.be.instanceof L.GeoJSON
        map.destroy()

      it 'has GeoJSON Tile support if enableGeoJsonTile is true', ->
        map = new Meppit.Map enableGeoJsonTile: true
        expect(map).to.have.property '__geoJsonTileLayer'
        map.destroy()

      it 'has no GeoJSON Tile support if enableGeoJsonTile is false', ->
        map = new Meppit.Map enableGeoJsonTile: false
        expect(map).not.to.have.property '__geoJsonTileLayer'
        map.destroy()

      it 'has tiles for map', ->
        expect(@map).to.have.property 'tileProviders'
        expect(@map.tileProviders).to.have.property 'map'

      it 'has tiles for satellite', ->
        expect(@map).to.have.property 'tileProviders'
        expect(@map.tileProviders).to.have.property 'satellite'

    describe 'options', ->
      it 'has default options', ->
        expect(@map).to.have.property 'defaultOptions'

      it 'has options', ->
        expect(@map.getOption 'foo').to.equal @options.foo

      it 'accepts new options vlaues', ->
        newValue = 'baz'
        expect(newValue).to.not.equal @options.foo
        expect(@map.getOption 'foo').to.equal @options.foo
        @map.setOption 'foo', newValue
        expect(@map.getOption 'foo').to.equal newValue

      it 'should have some required options', ->
        leafletMapOptions = @map.__getLeafletMapOptions()
        expect(leafletMapOptions).to.have.property 'center'
        expect(leafletMapOptions).to.have.property 'zoom'

    describe '#refresh', ->
      it 'calls _onResize', ->
        spy = sinon.spy(@map.leafletMap, '_onResize')
        @map.refresh()
        expect(spy.calledOnce).to.be.true

    describe '#toGeoJSON', ->
      it 'keeps the features properties', ->
        @geoJsonPoint.properties = { "foo": "bar" }
        expect(@map.load @geoJsonPoint).to.eql @map
        expect(@map.toGeoJSON().features[0].properties).to.eql { "foo": "bar" }

    describe '#toSimpleGeoJSON', ->
      it 'removes the features properties', ->
        @geoJsonPoint.properties = { "foo": "bar" }
        expect(@map.load @geoJsonPoint).to.eql @map
        expect(@map.toSimpleGeoJSON().features[0].properties).to.eql {}

    describe '#load', ->
      it 'loads GeoJSON feature', ->
        expect(@map.load @geoJsonPoint).to.eql @map
        expect(@map.toGeoJSON()).to.eql createFeatureCollection(
                                              [@geoJsonPoint])

      it 'avoids loadings a GeoJSON feature already loaded', ->
        @map.load @geoJsonPoint
        @map.load @geoJsonPoint
        expect(@map.toGeoJSON()).to.eql createFeatureCollection(
                                              [@geoJsonPoint])

      it 'avoids loadings a GeoJSON feature collection already loaded', ->
        featureCollection = createFeatureCollection [@geoJsonPoint]
        @map.load featureCollection
        @map.load featureCollection
        expect(@map.toGeoJSON()).to.eql createFeatureCollection(
                                              [@geoJsonPoint])

      it 'loads GeoJSON feature collection', ->
        featureCollection = createFeatureCollection [@geoJsonPoint]
        @map.load featureCollection
        expect(@map.toGeoJSON()).to.eql featureCollection

      it 'loads via ajax', (done) ->
        featureCollection = createFeatureCollection [@geoJsonPoint]
        server = sinon.fakeServer.create()
        server.xhr.useFilters = true
        server.xhr.addFilter (method, url) -> not url.match(/url\/to/)
        server.respondWith 'GET', 'url/to/GeoJSON',
            [200, "Content-Type": "application/json", JSON.stringify(
                featureCollection)]
        @map.load 'url/to/GeoJSON', =>
          expect(@map.toGeoJSON()).to.eql featureCollection
          done()
        server.respond()
        server.restore()

      it 'loads via ajax failed', (done) ->
        featureCollection = createFeatureCollection []
        server = sinon.fakeServer.create()
        server.xhr.useFilters = true
        server.xhr.addFilter (method, url) -> not url.match(/url\/to/)
        server.respondWith 'GET', 'url/to/GeoJSON',
            [500, 'Content-Type": "application/json', '']
        @map.load 'url/to/GeoJSON', =>
          expect(@map.toGeoJSON()).to.eql featureCollection
          done()
        server.respond()
        server.restore()

      it 'loads via ajax receiving the id as argument', (done) ->
        server = sinon.fakeServer.create()
        server.xhr.useFilters = true
        server.xhr.addFilter (method, url) -> not url.match(/url\/to/)
        server.respondWith 'GET', 'url/to/GeoJSON/42',
            [200, "Content-Type": "application/json", JSON.stringify(
                @geoJsonPoint)]
        @map.setOption 'featureURL', 'url/to/GeoJSON/#{id}'
        @map.load 42, =>
          expect(@map.toGeoJSON()).to.eql createFeatureCollection(
              [@geoJsonPoint])
          done()
        server.respond()
        server.restore()

      it 'loads via ajax receiving an array of ids as argument', (done) ->
        server = sinon.fakeServer.create()
        server.xhr.useFilters = true
        server.xhr.addFilter (method, url) -> not url.match(/url\/to/)
        server.respondWith 'GET', 'url/to/GeoJSON/42',
            [200, "Content-Type": "application/json", JSON.stringify(
                @geoJsonPoint)]
        server.respondWith 'GET', 'url/to/GeoJSON/43',
            [200, "Content-Type": "application/json", JSON.stringify(
                @geoJsonPolygon)]
        @map.setOption 'featureURL', 'url/to/GeoJSON/#{id}'
        @map.load [42, 43], (resp) =>
          expected = createFeatureCollection(
              [@geoJsonPoint, @geoJsonPolygon])
          expect(resp).to.eql expected
          expect(@map.toGeoJSON()).to.eql expected
          done()
        server.respond()
        server.restore()

    describe '#show', ->
      it 'loads and fit GeoJSON feature collection', (done) ->
        @geoJsonPoint.properties = id: 42
        @geoJsonPolygon.properties = id: 43
        geoJsonCollection = createFeatureCollection [
            @geoJsonPoint, @geoJsonPolygon]
        expect(@map.show geoJsonCollection, (geojson) =>
          expect(@map.toGeoJSON()).to.eql geoJsonCollection
          layerLatLng = @map._getLeafletLayer(42).getLatLng()
          layerBounds = @map._getLeafletLayer(43).getBounds()
          expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.true
          expect(@map.leafletMap.getBounds().contains layerBounds).to.be.true
          done()
        ).to.eql @map

    describe '#get', ->
      it 'returns the GeoJSON to given id', ->
        @geoJsonPoint.properties = id: 42
        @geoJsonPolygon.properties = id: 43
        geoJsonCollection = createFeatureCollection [
            @geoJsonPoint, @geoJsonPolygon]
        @map.load geoJsonCollection
        expect(@map.get 42).to.eql @geoJsonPoint
        expect(@map.get 43).to.eql @geoJsonPolygon
        expect(@map.get 44).not.to.exist

    describe '#clear', ->
      it 'removes all elements from map', ->
        @map.load @geoJsonPoint
        expect(@map.clear()).to.eql @map
        expect(@map.toGeoJSON()).to.eql createFeatureCollection([])
        expect(@map.leafletLayers).to.eql {}

    describe '#openPopup', ->
      it 'delegates to popup manager', ->
        popup = @map._ensurePopupManager()
        stub = sinon.stub popup, 'open'
        expect(@map.openPopup 'data').to.eql @map
        expect(stub.withArgs('data').calledOnce).to.be.true

      it 'does nothing if "enablePopup" option is false', ->
        popup = @map._ensurePopupManager()
        stub = sinon.stub popup, 'open'
        @map.setOption 'enablePopup', false
        @map.openPopup 'data'
        expect(stub.called).to.be.false

      it 'should get editor manager from Meppit namespace', ->
        popup = @map._ensurePopupManager()
        expect(popup).to.be.instanceof Meppit.PopupManager

    describe '#closePopup', ->
      it 'delegates to popup manager', ->
        popup = @map._ensurePopupManager()
        stub = sinon.stub popup, 'close'
        expect(@map.closePopup()).to.eql @map
        expect(stub.called).to.be.true

    describe '#getURL', ->
      it 'returns the feature URL', ->
        @map.setOption 'featureURL', '#{baseURL}features/#{id}'
        @geoJsonPoint.properties = id: 42
        stub = sinon.stub @map, '_getBaseURL', -> 'url/to/'
        expect(@map.getURL @geoJsonPoint).to.equal 'url/to/features/42'

      it 'gets the URL from properties if exist', ->
        @geoJsonPoint.properties = url: 'url/from/property'
        expect(@map.getURL @geoJsonPoint).to.equal 'url/from/property'

    describe '#_getBaseURL', ->
      it 'uses options', ->
        @map.setOption 'baseURL', 'http://options.url/'
        expect(@map._getBaseURL()).to.equal 'http://options.url/'

      it 'uses "base" element', ->
        base = document.createElement 'base'
        base.href = 'http://base.url/index.html'
        document.body.appendChild base
        expect(@map._getBaseURL()).to.equal 'http://base.url/'
        document.body.removeChild base

      it 'uses location', ->
        expect(@map._getBaseURL()).to.equal 'file:///'

    describe '#draw', ->
      it 'delegates to editor manager', ->
        editor = @map._ensureEditorManager()
        stub = sinon.stub editor, 'draw'
        expect(@map.draw 'data', 'callback').to.eql @map
        expect(stub.withArgs('data', 'callback').calledOnce).to.be.true

      it 'does nothing if "enableEditor" option is false', ->
        editor = @map._ensureEditorManager()
        stub = sinon.stub editor, 'draw'
        @map.setOption 'enableEditor', false
        @map.draw 'data', 'callback'
        expect(stub.called).to.be.false

    describe '#edit', ->
      it 'delegates to editor manager', ->
        editor = @map._ensureEditorManager()
        stub = sinon.stub editor, 'edit'
        @map.edit 'data', 'callback'
        expect(stub.withArgs('data', 'callback').calledOnce).to.be.true

      it 'should get editor manager from Meppit namespace', ->
        editor = @map._ensureEditorManager()
        expect(editor).to.be.instanceof Meppit.EditorManager

      it 'does nothing if "enableEditor" option is false', ->
        editor = @map._ensureEditorManager()
        stub = sinon.stub editor, 'edit'
        @map.setOption 'enableEditor', false
        @map.edit 'data', 'callback'
        expect(stub.called).to.be.false

    describe '#done', ->
      it 'delegates to editor manager', ->
        editor = @map._ensureEditorManager()
        stub = sinon.stub editor, 'done'
        expect(@map.done()).to.eql @map
        expect(stub.calledOnce).to.be.true

    describe '#cancel', ->
      it 'delegates to editor manager', ->
        editor = @map._ensureEditorManager()
        stub = sinon.stub editor, 'cancel'
        expect(@map.cancel()).to.eql @map
        expect(stub.calledOnce).to.be.true

    describe '#fit', ->
      it 'fits polygon bounds', ->
        @geoJsonPolygon.properties = id: 42
        @map.load @geoJsonPolygon
        layerBounds = @map._getLeafletLayer(42).getBounds()
        expect(@map.leafletMap.getBounds().contains layerBounds).to.be.false
        expect(@map.fit @geoJsonPolygon).to.eql @map
        expect(@map.leafletMap.getBounds().contains layerBounds).to.be.true

      it 'fits point', ->
        @geoJsonPoint.properties = id: 42
        @map.load @geoJsonPoint
        layerLatLng = @map._getLeafletLayer(42).getLatLng()
        expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.false
        @map.fit @geoJsonPoint
        expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.true

      it 'fits feature collection', ->
        @geoJsonPoint.properties = id: 42
        @geoJsonPolygon.properties = id: 43
        geoJsonCollection = createFeatureCollection [
            @geoJsonPoint, @geoJsonPolygon]
        @map.load geoJsonCollection
        layerLatLng = @map._getLeafletLayer(42).getLatLng()
        expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.false
        layerBounds = @map._getLeafletLayer(43).getBounds()
        expect(@map.leafletMap.getBounds().contains layerBounds).to.be.false
        @map.fit geoJsonCollection
        expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.true
        expect(@map.leafletMap.getBounds().contains layerBounds).to.be.true

      it 'ignores an empty argument', ->
        @map.fit()

    describe '#panTo', ->
      it 'pans to polygon', ->
        @geoJsonPolygon.properties = id: 42
        @map.load @geoJsonPolygon
        layerBounds = @map._getLeafletLayer(42).getBounds()
        expect(@map.leafletMap.getBounds().intersects layerBounds).to.be.false
        expect(@map.panTo @geoJsonPolygon).to.eql @map
        expect(@map.leafletMap.getBounds().intersects layerBounds).to.be.true

      it 'pans to point', ->
        @geoJsonPoint.properties = id: 42
        @map.load @geoJsonPoint
        layerLatLng = @map._getLeafletLayer(42).getLatLng()
        expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.false
        @map.panTo @geoJsonPoint
        expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.true

      it 'pans to feature collection', ->
        @geoJsonPoint.properties = id: 42
        @geoJsonPolygon.properties = id: 43
        geoJsonCollection = createFeatureCollection [
            @geoJsonPoint, @geoJsonPolygon]
        @map.load geoJsonCollection
        layerLatLng = @map._getLeafletLayer(42).getLatLng()
        expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.false
        layerBounds = @map._getLeafletLayer(43).getBounds()
        expect(@map.leafletMap.getBounds().intersects layerBounds).to.be.false
        @map.panTo geoJsonCollection
        expect(@map.leafletMap.getBounds().contains layerLatLng).to.be.true
        #expect(@map.leafletMap.getBounds().intersects layerBounds).to.be.true

      it 'ignores an empty argument', ->
        @map.panTo()


    describe '#selectTileProvider', ->
      it 'allows to change the tile provider', ->
        # TODO
        expect(@map.selectTileProvider 'map').to.eql @map

    describe '#remove', ->
      it 'accepts id', ->
        @geoJsonPoint.properties = id: 42
        @map.load @geoJsonPoint
        layer = @map._getLeafletLayer 42
        expect(layer).to.exist
        expect(layer._map).to.exist
        expect(@map.remove 42).to.eql @map
        expect(@map._getLeafletLayer 42).not.to.exist
        expect(layer._map).not.to.exist

      it 'accepts GeoJSON', ->
        @geoJsonPoint.properties = id: 42
        @map.load @geoJsonPoint
        layer = @map._getLeafletLayer 42
        expect(layer).to.exist
        expect(layer._map).to.exist
        @map.remove @geoJsonPoint
        expect(@map._getLeafletLayer 42).not.to.exist
        expect(layer._map).not.to.exist

      it 'accepts feature collection', ->
        @geoJsonPoint.properties = id: 42
        @geoJsonPolygon.properties = id: 43
        geoJsonCollection = createFeatureCollection [
            @geoJsonPoint, @geoJsonPolygon]
        @map.load geoJsonCollection
        @map.remove geoJsonCollection
        expect(@map._getLeafletLayer 42).not.to.exist
        expect(@map._getLeafletLayer 43).not.to.exist

    describe 'delegations', ->
      it 'delegates zoom methods', ->
        getZoom = sinon.stub @map.leafletMap, 'getZoom'
        @map.getZoom('arg1', 'arg2')
        expect(getZoom.withArgs('arg1', 'arg2').calledOnce).to.be.true

        setZoom = sinon.stub @map.leafletMap, 'setZoom'
        @map.setZoom('arg1', 'arg2')
        expect(setZoom.withArgs('arg1', 'arg2').calledOnce).to.be.true

        zoomIn = sinon.stub @map.leafletMap, 'zoomIn'
        @map.zoomIn('arg1', 'arg2')
        expect(zoomIn.withArgs('arg1', 'arg2').calledOnce).to.be.true

        zoomOut = sinon.stub @map.leafletMap, 'zoomOut'
        @map.zoomOut('arg1', 'arg2')
        expect(zoomOut.withArgs('arg1', 'arg2').calledOnce).to.be.true

      it 'delegates _addLeafletControl to addControl', ->
        addControl = sinon.stub @map.leafletMap, 'addControl'
        @map._addLeafletControl('arg1', 'arg2')
        expect(addControl.withArgs('arg1', 'arg2').calledOnce).to.be.true

    describe '#_getLeafletLayer', ->
      it 'returns the layer by id', ->
        expect(@map._getLeafletLayer 42).not.to.exist
        @geoJsonPoint.properties = id: 42
        @map.load @geoJsonPoint
        expect(@map._getLeafletLayer 42).to.exist

      it 'returns the layer by GeoJSON', ->
        expect(@map._getLeafletLayer @geoJsonPoint).not.to.exist
        @geoJsonPoint.properties = id: 42
        @map.load @geoJsonPoint
        expect(@map._getLeafletLayer @geoJsonPoint).to.exist

      it 'returns the layer by GeoJSON without id', ->
        expect(@map._getLeafletLayer @geoJsonPoint).not.to.exist
        @map.load @geoJsonPoint
        expect(@map._getLeafletLayer @geoJsonPoint).to.exist

      it 'ignores an empty argument', ->
        expect(@map._getLeafletLayer()).to.not.exist

    describe '#__defineLeafletDefaultImagePath', ->
      it 'sets L.Icon.Default.imagePath if undefined', ->
        imagePath = L.Icon.Default.imagePath
        L.Icon.Default.imagePath = undefined
        script = document.createElement 'script'
        script.src = '/path/to/meppit-map.js'
        document.head.appendChild script
        @map.__defineLeafletDefaultImagePath()
        expect(L.Icon.Default.imagePath).to.equal 'file:///path/to/images'
        document.head.removeChild script
        L.Icon.Default.imagePath = imagePath

      it 'does nothing if L.Icon.Default.imagePath is defined', ->
        imagePath = L.Icon.Default.imagePath
        @map.__defineLeafletDefaultImagePath()
        expect(L.Icon.Default.imagePath).to.equal imagePath
        L.Icon.Default.imagePath = imagePath

    describe '#addButton', ->
      it 'adds control', ->
        spy = sinon.spy(@map.leafletMap, 'addControl')
        @map.addButton 'id', 'fa-circle', (->), 'title', 'topleft'
        expect(spy.calledOnce).to.be.true

    describe '#removeButton', ->
      it 'removes control', ->
        spy = sinon.spy(@map.leafletMap, 'removeControl')
        @map.addButton 'id', 'fa-circle', (->), 'title', 'topleft'
        @map.removeButton 'id'
        expect(spy.calledOnce).to.be.true

    describe '#showButton/#hideButton', ->
      it 'makes control visible/invisible', ->
        @map.addButton 'id', 'fa-circle', (->), 'title', 'topleft'
        expect(@map.buttons['id']._container.style.display).to.equal ''
        @map.hideButton 'id'
        expect(@map.buttons['id']._container.style.display).to.equal 'none'
        @map.showButton 'id'
        expect(@map.buttons['id']._container.style.display).to.equal ''

    describe '#locate', ->
      beforeEach ->
        @sandbox = sinon.sandbox.create()
      afterEach ->
        @sandbox.restore()

      it 'binds success callback', ->
        spy = sinon.spy(@map.leafletMap, 'once')
        onSuccess = ->
        onError = ->
        @map.locate onSuccess, onError
        expect(spy.calledWith 'locationfound').to.be.true

      it 'binds error callback', ->
        spy = sinon.spy(@map.leafletMap, 'once')
        onSuccess = ->
        onError = ->
        @map.locate onSuccess, onError
        expect(spy.calledWith 'locationerror').to.be.true

      it 'calls success callback once on success', ->
        sinon.stub(@map.leafletMap, 'locate')
        onSuccess = sinon.spy()
        onError = ->
        @map.locate onSuccess, onError
        @map.leafletMap.fire 'locationfound'
        @map.leafletMap.fire 'locationfound'
        expect(onSuccess.called).to.be.true

      it 'calls error callback once on fail', ->
        @sandbox.stub(@map.leafletMap, 'locate')
        @sandbox.stub(L.GeoIP, 'getPosition')
        onSuccess = ->
        onError = sinon.spy()
        @map.locate onSuccess, onError
        @map.leafletMap.fire 'locationerror'
        @map.leafletMap.fire 'locationerror'
        expect(onError.calledOnce).to.be.true

      it 'unbinds error callback on success', ->
        @sandbox.stub(@map.leafletMap, 'locate')
        onSuccess = sinon.spy()
        onError = sinon.spy()
        @map.locate onSuccess, onError
        @map.leafletMap.fire 'locationfound'
        @map.leafletMap.fire 'locationerror'
        expect(onSuccess.called).to.be.true
        expect(onError.called).to.be.false

      it 'unbinds success callback on fail', ->
        @sandbox.stub(@map.leafletMap, 'locate')
        @sandbox.stub(L.GeoIP, 'getPosition')
        onSuccess = sinon.spy()
        onError = sinon.spy()
        @map.locate onSuccess, onError
        @map.leafletMap.fire 'locationerror'
        @map.leafletMap.fire 'locationfound'
        expect(onError.called).to.be.true
        expect(onSuccess.called).to.be.false

      it 'gets location from ip if geolocation fails', ->
        @sandbox.stub(@map.leafletMap, 'locate')
        @sandbox.stub(L.GeoIP, 'getPosition').returns(L.latLng(-23, 42))
        onSuccess = sinon.spy()
        onError = sinon.spy()
        @map.locate onSuccess, onError
        @map.leafletMap.fire 'locationerror'
        expect(onError.calledOnce).to.be.false
        expect(onSuccess.calledOnce).to.be.true
        expect(onSuccess.args[0][0].location.geometry.coordinates).to.deep.equal [42, -23]

  {}
