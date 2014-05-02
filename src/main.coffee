window.Meppit ?= {}
window.Meppit.VERSION = '<%= pkg.version %>'

isArray = Meppit.isArray = (data) ->
  Object.prototype.toString.call(data) is '[object Array]'

isNumber = Meppit.isNumber = (data) ->
  typeof data is 'number'

isString = Meppit.isString = (data) ->
  typeof data is 'string'

interpolate = Meppit.interpolate = (tpl, obj) ->
  # http://javascript.crockford.com/remedial.html
  tpl.replace /#{([^#{}]*)}/g, (a, b) ->
    r = obj[b]
    if isString(r) or isNumber(r) then r else a

getHash = Meppit.getHash = (data) ->
  hash = 0
  if data.length > 0
    for i  in [0 .. data.length - 1]
      char = data.charCodeAt i
      hash = ((hash << 5) - hash) + char
      hash |= 0  # Convert to 32bit integer
  '_' + hash

getDate = Meppit.getDate = (date) ->
  months = ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December']
  date ?= new Date()
  day = date.getDate()
  month = date.getMonth() + 1
  yy = date.getYear()
  year = if yy < 1000 then yy + 1900 else yy

  "#{months[month]} #{day} #{year}"

_log = Meppit.log = ->
  args = ["[#{getDate()}]"].concat Array.prototype.slice.call(arguments)
  console?.log args.join(' ') if not window.MEPPIT_SILENCE

_warn = Meppit.warn = ->
  args = ["[#{getDate()}]"].concat Array.prototype.slice.call(arguments)
  console?.warn args.join(' ') if not window.MEPPIT_SILENCE

reverseCoordinates = Meppit.reverseCoordinates = (data) ->
  return data if isNumber(data)
  return (reverseCoordinates(i) for i in data) if isArray(data) and
                                                 isArray(data[0])
  return data.reverse() if isArray(data) and isNumber(data[0])
  if data.type is 'Feature'
    data.geometry.coordinates = reverseCoordinates data.geometry.coordinates
  else if data.type is 'FeatureCollection'
    data.features = (reverseCoordinates(feature) for feature in data.features)
  return data

requestJSON = Meppit.requestJSON = (url, callback) ->
  req = if window.XMLHttpRequest  # Mozilla, Safari, ...
    new XMLHttpRequest()
  else if window.ActiveXObject  # IE 8 and older
    new ActiveXObject "Microsoft.XMLHTTP"
  @_requests ?= []
  @_requests.push req
  req.onreadystatechange = ->
    if req.readyState is 4
      if req.status is 200
        callback JSON.parse(req.responseText)
      else
        callback null
  req.open 'GET', url, true
  req.send()


counter = 0
class BaseClass
  VERSION: '<%= pkg.version %>'

  constructor: ->
    @cid = counter++

  log: ->
    args = ["Log: #{@constructor.name}##{@.cid} -"].concat(
        Array.prototype.slice.call(arguments))
    _log.apply this, args

  warn: ->
    args = ["Warn: #{@constructor.name}##{@.cid} -"].concat(
        Array.prototype.slice.call(arguments))
    _warn.apply this, args

  getOption: (key) ->
    @options?[key] ? @defaultOptions?[key]

  setOption: (key, value) ->
    @options ?= {}
    @options[key] = value

Meppit.BaseClass = BaseClass


define? [], -> window.Meppit
