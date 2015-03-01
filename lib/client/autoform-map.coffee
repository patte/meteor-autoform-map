KEY_ENTER = 13

defaults =
  mapType: 'roadmap'
  defaultLat: 1
  defaultLng: 1
  geolocation: false
  searchBox: false
  autolocate: false
  zoom: 13
  geocode: false

AutoForm.addInputType 'map',
  template: 'afMap'
  valueOut: ->
    node = $(@context)
    
    lat: node.find('.js-lat').val()
    lng: node.find('.js-lng').val()
  contextAdjust: (ctx) ->
    ctx.loadingGeolocation = new ReactiveVar(false)
    ctx.loadingGeocode = new ReactiveVar(false)
    ctx
  valueConverters:
    string: (value) ->
      "#{value.lat},#{value.lng}"
    numberArray: (value) ->
      [value.lng, value.lat]

Template.afMap.rendered = ->
  @data.options = _.extend {}, defaults, @data.atts

  @data.marker = undefined
  @data.setMarker = (map, location, zoom=0) =>
    @$('.js-lat').val(location.lat())
    @$('.js-lng').val(location.lng())

    if @data.marker then @data.marker.setMap null
    @data.marker = new google.maps.Marker
      position: location
      map: map

    if zoom > 0
      @data.map.setZoom zoom

  GoogleMaps.init { libraries: 'places' }, () =>
    mapOptions =
      zoom: @data.options.zoom
      mapTypeId: google.maps.MapTypeId[@data.options.mapType]
      streetViewControl: false

    if @data.atts.googleMap
      _.extend mapOptions, @data.atts.googleMap

    @data.map = new google.maps.Map @find('.js-map'), mapOptions

    if @data.value
      location = if typeof @data.value == 'string' then @data.value.split ',' else [@data.value.lat, @data.value.lng]
      location = new google.maps.LatLng parseFloat(location[0]), parseFloat(location[1])
      @data.setMarker @data.map, location, @data.options.zoom
      @data.map.setCenter location
    else
      @data.map.setCenter new google.maps.LatLng @data.options.defaultLat, @data.options.defaultLng

    if @data.atts.searchBox
      input = @find('.js-search')

      @data.map.controls[google.maps.ControlPosition.TOP_LEFT].push input
      searchBox = new google.maps.places.SearchBox input

      google.maps.event.addListener searchBox, 'places_changed', =>
        location = searchBox.getPlaces()[0].geometry.location
        @data.setMarker @data.map, location
        @data.map.setCenter location

      $(input).removeClass('af-map-search-box-hidden')

    if @data.atts.autolocate and navigator.geolocation and not @data.value
      navigator.geolocation.getCurrentPosition (position) =>
        location = new google.maps.LatLng position.coords.latitude, position.coords.longitude
        @data.setMarker @data.map, location, @data.options.zoom
        @data.map.setCenter location

    if typeof @data.atts.rendered == 'function'
      @data.atts.rendered @data.map

    google.maps.event.addListener @data.map, 'click', (e) =>
      @data.setMarker @data.map, e.latLng

  @$('.js-map').closest('form').on 'reset', =>
    @data.marker.setMap null
    @data.map.setCenter new google.maps.LatLng @data.options.defaultLat, @data.options.defaultLng
    @data.map.setZoom @data.options.zoom

Template.afMap.helpers
  schemaKey: ->
    @atts['data-schema-key']
  width: ->
    if typeof @atts.width == 'string'
      @atts.width
    else if typeof @atts.width == 'number'
      @atts.width + 'px'
    else
      '100%'
  height: ->
    if typeof @atts.height == 'string'
      @atts.height
    else if typeof @atts.height == 'number'
      @atts.height + 'px'
    else
      '200px'
  loadingGeolocation: ->
    @loadingGeolocation.get()
  loadingGeocode: ->
    @loadingGeocode.get()

Template.afMap.events
	'keydown .js-search': (e) ->
		if e.keyCode == KEY_ENTER then e.preventDefault()

  'click .js-locate': (e, t) ->
    e.preventDefault()

    unless navigator.geolocation then return false

    @loadingGeolocation.set true
    navigator.geolocation.getCurrentPosition (position) =>
      location = new google.maps.LatLng position.coords.latitude, position.coords.longitude
      @setMarker @map, location, @options.zoom
      @map.setCenter location
      @loadingGeolocation.set false

  'click .js-geocode': (e, t) ->
    e.preventDefault()
    # FIXME
    formId = $(e.target).closest("form").attr('id')
    street = AutoForm.getFieldValue(formId, "address.street")
    zip = AutoForm.getFieldValue(formId, "address.zip")
    city = AutoForm.getFieldValue(formId, "address.city")
    #
    self = this
    @loadingGeocode.set true
    new google.maps.Geocoder().geocode
      address: "#{street}, #{zip} #{city}",
      (results, status) ->
        if status is google.maps.GeocoderStatus.OK and results[0] isnt undefined
          # sadly geometry.location isn't a google.maps.LatLng
          lat = results[0].geometry.location.lat()
          lng = results[0].geometry.location.lng()
          location = new google.maps.LatLng lat, lng
          self.setMarker self.map, location, self.options.zoom
          self.map.setCenter location
        else
          alert "Geocoding failed! #{status}"
        self.loadingGeocode.set false

