define ['../dist/meppit-map', '../lib/leaflet', '../lib/leaflet.draw'],
    (Meppit, L) ->
  'use strict'

  describe 'Popup', ->
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
      @popup = new Meppit.PopupManager(@map)

    afterEach ->
      @map.destroy()
      @map = null
      @popup = null

    describe 'initialization', ->
      it 'has popup object', ->
        expect(@popup).to.have.property '_popup'
        expect(@popup._popup instanceof L.Popup).to.be.true

    describe '#open', ->
      it 'does nothing if no feature was passed', ->
        spy = sinon.spy @popup._popup, 'openOn'
        @popup.open()
        expect(spy.called).to.be.false

      it 'opens marker popup', ->
        @geoJsonPoint.properties = id: 42
        spy = sinon.spy @popup._popup, 'openOn'
        @map.load @geoJsonPoint
        @popup.open @geoJsonPoint
        expect(spy.calledOnce).to.be.true

      it 'does nothing if in edit mode', ->
        @map.editing = true
        spy = sinon.spy @popup._popup, 'openOn'
        @map.load @geoJsonPoint
        @popup.open @geoJsonPoint
        expect(spy.called).to.be.false

    describe '#close', ->
      it 'closes the popup', ->
        spy = sinon.spy @map.leafletMap, 'closePopup'
        @popup.close()
        expect(spy.calledOnce).to.be.true

    describe '#_getContent', ->
      it 'gets the content from "properties.popupContent"', ->
        @geoJsonPoint.properties = popupContent: 'Spam, Spam, Eggs'
        expect(@popup._getContent @geoJsonPoint).to.equal 'Spam, Spam, Eggs'

      it 'gets the content from options', ->
        @popup.setOption 'popupTemplate', 'Spam, Spam, Eggs'
        expect(@popup._getContent @geoJsonPoint).to.equal 'Spam, Spam, Eggs'

      it 'interpolates the feature properties', ->
        @popup.setOption 'popupTemplate', '#{url} #{name}'
        stub = sinon.stub @map, 'getURL', -> 'feature_url'
        @geoJsonPoint.properties = name: 'feature_name'
        expect(@popup._getContent @geoJsonPoint).to.equal(
            'feature_url feature_name')

      it 'returns empty string if no feature is passed', ->
        expect(@popup._getContent()).to.equal ''
