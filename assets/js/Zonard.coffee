# polyfill:
# We check what the rotation transformation name is
# in the browser
@transformName = null
d = document.createElement('div')
for b in ['transform', 'webkitTransform', "MozTransform", 'msTransform', "OTransform"] when d.style[b]?
  @transformName = b
d = null
# Vector Helper
V =
  vector: (direction, center)->
    x: direction.x - center.x
    y: direction.y - center.y

  norm: (vector)->
    Math.sqrt vector.x * vector.x + vector.y * vector.y

  normalized: (vector)->
    norm = @norm vector
    x: vector.x / norm
    y: vector.y / norm

  signedDir: (vector, comp)->
    vector[comp] / Math.abs(vector[comp])

Cards = 'n,s,e,w,nw,ne,se,sw'.split ','
ordCards = 's,sw,w,nw,n,ne,e,se'.split ','

# Zonard
class @Zonard extends Backbone.View
  className: 'zonard'

  # @params options {object}
  # @params options.model {Block}
  # @params options.workspace {div element}
  # @params options.centralHandle {bool} (optional)
  initialize: ->
    @handlerContainer = new HandlerContainerView @options
    @displayContainer = new DisplayContainerView
    @visibility = on

    # set tranform-origin css property
    @$el.css  'transform-origin': 'left top'


    @workspace = @options.workspace
    @$workspace = $ @workspace

    # initialize _state object, that will hold informations
    # necessary to determines the block position and rotation
    @_state = {}

    angleDeg = @model.get 'rotate'
    angleRad = angleDeg * (2 * Math.PI) /360
    @_state.angle =
      rad: angleRad
      deg: angleDeg
      cos: Math.cos(angleRad)
      sin: Math.sin(angleRad)

    # Caution: can't call getClientBoundingRectangle in IE9 if element not
    # in the DOM
    # @_setState()
    handle.assignCursor(@_state.angle.rad) for i, handle of @handlerContainer.handles
    dragbar.assignCursor(@_state.angle.rad) for i, dragbar of @handlerContainer.dragbars

  listenFocus: ->
    @listenToOnce @handlerContainer.tracker, 'focus', =>
      @trigger 'focus'

  toggle: (visibility)->
    @displayContainer.toggle visibility
    @handlerContainer.toggle visibility
    @

  # @chainable
  listenToDragStart: ->
    for handle in @handlerContainer.handles
      @listenTo handle, 'drag:start', (data)=>
        @trigger 'start:resize'
        @_setState data
        @setTransform
          fn: (event)=>
            @_calculateResize(event)
          end: @_endResize
        @listenMouse()

    for dragbar in @handlerContainer.dragbars
      @listenTo dragbar, 'drag:start', (data)=>
        @trigger 'start:resize'
        @_setState data
        @setTransform
          fn: (event)=>
            @_calculateResize(event)
          end: @_endResize
        @listenMouse()

    @listenTo @handlerContainer.tracker, 'drag:start', (data)=>
      @trigger 'start:move'
      @_setState data
      @setTransform
        fn: (event)=>
          @_calculateMove(event)
        end: @_endMove
      @listenMouse()

    @listenTo @handlerContainer.rotateHandle, 'drag:start', (data)=>
      @trigger 'start:rotate'
      @_setState data
      @setTransform
        fn: (event)=>
          @_calculateRotate(event)
        end: @_endRotate
      @listenMouse()

    if @options.centralHandle
      @listenTo @handlerContainer.centralHandle, 'drag:start', (data)=>
        @trigger 'start:centralDrag'
        @_setState data
        @setTransform
          fn: (event)=>
            @_calculateCentralDrag(event)
          end: @_endCentralDrag
        @listenMouse()
    @

  listenMouse: ->
    @$workspace.on 'mousemove', @_transform.fn
    @$workspace.on 'mouseup', @_transform.end
    @$workspace.on 'mouseleave', @_transform.end

  releaseMouse: =>
    @$workspace
      .off('mousemove', @_transform.fn)
      .off('mouseup', @_transform.end)
      .off('mouseleave', @_transform.end)

  setTransform: (@_transform)->

  # Method to set the position and rotation of the zonard
  # the properties of box are optionals
  # box: {left: x, top: y, width: w, height:h, rotate, angle(degrès)}
  setBox: (box)->
    @$el.css transform: "rotate(#{box.rotate}deg)"
    @$el.css(box)

  # return position information stored in state
  getBox:=>
    # we return the main informations of position
    left    : @_state.elPosition.left
    top     : @_state.elPosition.top
    width   : @_state.elDimension.width
    height  : @_state.elDimension.height
    rotate  : @_state.angle.deg
    centerX : @_state.rotatedCenter.x - @_state.workspaceOffset.left
    centerY : @_state.rotatedCenter.y - @_state.workspaceOffset.top

  _endMove: =>
    @releaseMouse()
    @trigger 'end:move', @_setState()

  _endRotate:=>
    @releaseMouse()
    @trigger 'end:rotate', @_setState()

    handle.assignCursor(@_state.angle.rad) for i, handle of @handlerContainer.handles
    dragbar.assignCursor(@_state.angle.rad) for i, dragbar of @handlerContainer.dragbars

  # we build a coefficient table, wich indicates the modication
  # pattern corresponding to each cardinal
  # the 2 first are the direction on which to project in the
  # local base to obtain the top & left movement
  # the 2 last are for the width & height modification
  coefs:
    n  : [ 0,  1,  0, -1]
    s  : [ 0,  0,  0,  1]
    e  : [ 0,  0,  1,  0]
    w  : [ 1,  0, -1,  0]
    nw : [ 1,  1, -1, -1]
    ne : [ 0,  1,  1, -1]
    se : [ 0,  0,  1,  1]
    sw : [ 1,  0, -1,  1]

  _endResize: =>
    @releaseMouse()
    @trigger 'end:resize', @_setState()

  _endCentralDrag: =>
    @releaseMouse()
    @trigger 'end:centralDrag', @_setState()

  # @chainable
  render: ->
    @$el.append @displayContainer.render().el, @handlerContainer.render().el
    # initializes css from the model attributes
    props = 'left top width height rotate'.split ' '
    box = {}
    for prop in props
      box[prop] = @model.get(prop)
    @setBox(box)
    @


# we apply the calculator mixin
calculators Zonard.prototype
