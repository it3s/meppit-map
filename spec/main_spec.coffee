define ['../dist/meppit-map'], (Meppit) ->
  'use strict'

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

    @geoJsonPointReversed =
      "type": "Feature",
      "geometry":
        "type": "Point"
        "coordinates": [-23, 45]

    @geoJsonPolygon =
      "type": "Feature",
      "geometry":
        "type": "Polygon"
        "coordinates": [[[45, -23], [46, -22], [45, -23]]]

    @geoJsonPolygonReversed =
      "type": "Feature",
      "geometry":
        "type": "Polygon"
        "coordinates": [[[-23, 45], [-22, 46], [-23, 45]]]

  describe 'main namespace', ->
    it 'should be accessible', ->
      expect(window.Meppit).to.exist

    it 'has version number', ->
      expect(Meppit).to.have.property 'VERSION'

    it 'has map class', ->
      expect(Meppit).to.have.property 'Map'

  describe '#getHash', ->
   it 'returns a hash from string', ->
     expect(Meppit.getHash '').to.eql '_0'
     expect(Meppit.getHash 'Spam, Spam, Eggs, Spam').to.eql '_872948869'

  describe '#interpolate', ->
   it 'returns a interpolated string', ->
     expect(Meppit.interpolate 'before #{foo} after', foo: {}
       ).to.eql 'before #{foo} after'
     expect(Meppit.interpolate 'before #{foo} after', foo: 'bar'
       ).to.eql 'before bar after'

  describe '#isArray', ->
    it 'returns true to arrays', ->
      expect(Meppit.isArray []).to.be.true
      expect(Meppit.isArray new Array(1, 2, 3)).to.be.true

    it 'returns true to arrays from another context', ->
      iframe = document.createElement 'iframe'
      document.body.appendChild iframe
      xArray = window.frames[window.frames.length-1].Array
      expect(Meppit.isArray new xArray(1, 2, 3)).to.be.true

    it 'returns false to everything else', ->
      expect(Meppit.isArray {}).to.be.false
      expect(Meppit.isArray 3).to.be.false
      expect(Meppit.isArray '').to.be.false

  describe '#isString', ->
    it 'returns true to strings', ->
      expect(Meppit.isString '').to.be.true

    it 'returns false to everything else', ->
      expect(Meppit.isString []).to.be.false
      expect(Meppit.isString {}).to.be.false
      expect(Meppit.isString 3).to.be.false

  describe '#isNumber', ->
    it 'returns true to numbers', ->
      expect(Meppit.isNumber 3).to.be.true

    it 'returns false to everything else', ->
      expect(Meppit.isNumber []).to.be.false
      expect(Meppit.isNumber {}).to.be.false
      expect(Meppit.isNumber '').to.be.false

  describe '#reverseCoordinates', ->
    it 'reverse GeoJSON feature', ->
      Meppit.reverseCoordinates @geoJsonPointReversed
      expect(@geoJsonPointReversed).to.eql @geoJsonPoint

    it 'reverse GeoJSON complex feature', ->
      Meppit.reverseCoordinates @geoJsonPolygonReversed
      expect(@geoJsonPolygonReversed).to.eql @geoJsonPolygon

    it 'reverse GeoJSON feature collection', ->
      geoJsonCollectionReversed = createFeatureCollection(
          [@geoJsonPointReversed])
      Meppit.reverseCoordinates geoJsonCollectionReversed
      expect(geoJsonCollectionReversed).to.eql createFeatureCollection(
          [@geoJsonPoint])

  describe '#log', ->
    it 'calls console.log', ->
      stub = sinon.stub console, 'log', ->
      window.MEPPIT_SILENCE = false
      Meppit.log 'Spam'
      window.MEPPIT_SILENCE = true
      expect(stub.called).to.be.true
      stub.reset()

  describe '#warn', ->
    it 'calls console.warn', ->
      stub = sinon.stub window.console, 'warn', ->
      window.MEPPIT_SILENCE = false
      Meppit.warn 'Spam'
      window.MEPPIT_SILENCE = true
      expect(stub.called).to.be.true
      stub.reset()

  describe 'BaseClass', ->
    describe '#getOption', ->
      it 'gets value from options', ->
        base = new Meppit.BaseClass()
        base.options = foo: 'bar'
        expect(base.getOption 'foo').to.equal 'bar'

      it 'gets unknown value from default options', ->
        base = new Meppit.BaseClass()
        # we have no default options here
        expect(base.getOption 'foo').not.to.exist
        base.defaultOptions = foo: 'bar'
        expect(base.getOption 'foo').to.equal 'bar'

    describe '#setOption', ->


  {}
