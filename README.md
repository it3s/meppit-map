# Meppit-Map 0.1.3

[![Build Status](https://travis-ci.org/it3s/meppit-map.svg)](https://travis-ci.org/it3s/meppit-map)

Javascript library for Meppit's map component.


## API

### Meppit.Map

#### Usage example

```javascript
// initialize the map on the "map_container" div with a given center and zoom
var map = new Meppit.Map({
  element: 'map_container',
  center: [48.858333, 2.294444],
  zoom: 13
});
```


#### Options

 Option | Type | Default | Description
--------|------|---------|-------------
element | `String` or `HTMLElement` | an unattached DIV element | The HTML element used to draw the map
zoom | `Number` | `14` | Initial map zoom
center | `Number[]` | `[-23.5, -46.6167]` | Initial geographical center of the map
tileProvider | `String` | `'map'` | The name of predefined tile provider the map will use
idPropertyName | `String` | `'id'` | The name of GeoJSON's features property containing the id
urlPropertyName | `String` | `'url'` | The name of GeoJSON's feature property containing the url
featureURL | `String` | `'#{baseURL}features/#{id}'` | The URL used to retrieve a feature GeoJSON
geojsonTileURL | `String` | `'#{baseURL}geoJSON/{z}/{x}/{y}'` | The URL used to retrieve features for a given tile coordinates
enableEditor | `Boolean` | `true` | Whether the features can be edited and drawn
enablePopup | `Boolean` | `true` | Whether a popup should be shown when a features is clicked
enableGeoJsonTile | `Boolean` | `false` | Whether features will be loaded automatically


#### Methods

 * `load( <GeoJSON> data, <Function> callback? )` returns `this`
 * `show( <GeoJSON> data, <Function> callback? )` returns `this`
 * `toGeoJSON()` returns a `GeoJSON FeatureCollection`
 * `get( <Number> id )` returns a `GeoJSON Feature` or `undefined`
 * `remove( <GeoJSON or Number> )` returns `this`
 * `edit( <GeoJSON Feature or Number> data, <Function> callback? )` returns `this`
 * `draw( <GeoJSON Feature> data, <Function> callback? )` returns `this`
 * `done()` returns `this`
 * `cancel() ` returns `this`
 * `openPopup( <GeoJSON or Number> data, <String> content )` returns `this`
 * `openPopupAt( <GeoJSON or Number> data, <String> content, <Number[]> latLng? )` returns `this`
 * `closePopup()` returns `this`
 * `fit( <GeoJSON or Number> data )` returns `this`
 * `panTo( <GeoJSON or Number> )` returns `this`
 * `selectTileProvider( <String> provider )` returns `this`
 * `clear()` returns `this`
 * `getZoom()` returns `Number`
 * `setZoom( <Number> zoom )` returns `this`
 * `zoomIn( <Number> delta? )` returns `this`
 * `zoomOut( <Number> delta? )` returns `this`
 * `getURL( <GeoJSON Feature> feature )` returns `String`
 * `refresh()` returns `this`
 * `location( <Function> onSuccess, <Function> onError )` returns `this`
 * `addButton( <String> id, <String> icon, <Function> callback, <String> title, <String> position? )` returns `this`
 * `removeButton( <String> id )` returns `this`
 * `showButton( <String> id )` returns `this`
 * `hideButton( <String> id )` returns `this`
 * `destroy()` returns `undefined`


## Contributing

Indent your code with 2 spaces, strip trailing whitespace and take care to maintain the existing coding style. Add unit tests for any new or changed functionality. Lint and test your code using grunt.

Also, please don't edit files in the _"dist"_ subdirectory as they are generated via grunt. You'll find source code in the _"src"_ subdirectory!

Steps to contribute:

1. [Fork it](https://github.com/it3s/meppit-map/fork)
2. Create your feature branch `git checkout -b my-new-feature`
3. Commit your changes `git commit -am 'Add some feature'`
4. Push to the branch `git push origin my-new-feature`
5. Create new Pull Request


We'll do our best to help you out with any contribution issues you may have.


### Installing Dependencies

To contribute you will have to install some development dependencies. This assume you already have [Node.js](http://nodejs.org) and [npm](http://www.npmjs.org) installed on your system.

```
$  sudo npm install -g grunt-cli
$  npm install
```

Finally, you will be ready to develop and contribute :)


### Testing

```
$ grunt test
```


### Building

```
$ grunt build
```


## License

MIT. See `LICENSE.txt` in this directory.
