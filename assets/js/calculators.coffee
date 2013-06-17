# Functions destined to process data from mouse events
# These are internal method

calculators = (->
  #
  # Method to be called before calculating any displacement
  #
  _setState = (data = {})->
    # passing a lot of data, for not having to look it
    # up inside the handler
    @_state = $.extend(true, @_state, data)

    # we figure out the angle of rotation with the
    # output of @el.css('transform')
    # CAUTION: this won't work if there is any scaling on
    # the el
    matrix = @$el.css('transform')
    tab = matrix.substr(7, matrix.length-8).split(', ')
    cos = parseFloat tab[0]
    sin = parseFloat tab[1]

    sign =  sin / Math.abs(sin) || 1
    angleRad = sign * Math.acos(cos)
    angleDeg = angleRad * 360 /(2 * Math.PI)

    @_state.angle =
      rad: angleRad
      deg: angleDeg
      cos: cos
      sin: sin

    # WARNING!!! problems in IE9 when trying to get bounding
    # client rect when the element is not in the dom yet!
    box = @el.getBoundingClientRect()
    w = @$el.width()
    h = @$el.height()
    # we precalculate the value of cos and sin
    @_state.angle.cos = Math.cos(@_state.angle.rad)
    @_state.angle.sin = Math.sin(@_state.angle.rad)
    # TODO: Find a consistent way of finding out where the
    # zonard is (css positions + transform state ?)
    #
    # the initial position of @el
    @_state.elPosition =
      left : parseInt @$el.css('left')[...-2]
      top  : parseInt @$el.css('top')[...-2]
    # WILL CAUSE A HUGE MESS IF THE WORKSPACE HAS
    # A TRANSFORM ROTATE

    # = workspaceOffset??
    @_state.workspaceOffset = @$workspace.offset()

    @_state.elOffset =
      left: @_state.workspaceOffset.left + @_state.elPosition.left
      top : @_state.workspaceOffset.top   + @_state.elPosition.top
    # example of position bound based on the box that bounds
    # the rotateContainer
    @_state.positionBounds =
      ox: -Infinity
      oy: -Infinity
      x: Infinity
      y: Infinity
    @_state.elDimension =
      width: w
      height: h
    # we calculate the coordinates of the center of the rotation container
    @_state.rotatedCenter =
      x: @_state.elOffset.left + (w / 2) * @_state.angle.cos - (h / 2) * @_state.angle.sin
      y: @_state.elOffset.top + (w / 2) * @_state.angle.sin + (h / 2) * @_state.angle.cos
    @_state.elCenter =
      x: @_state.elOffset.left + w / 2
      y: @_state.elOffset.top  + h / 2

    # if we are dealing with a handle, we need to set the bases, and we need
    # to calculate the minimum and maximum  top left of the el - TODO
    @_state.coef = @coefs[@_state.card] if @_state.card?
    @_state.sizeBounds =
      wMin: 20
      wMax: Infinity
      hMin: 20
      hMax: Infinity

    @getBox()

  _calculateMove = (event)->
    state = event.data
    bounds = @_state.positionBounds
    vector =
      x: event.pageX - @_state.origin.x
      y: event.pageY - @_state.origin.y
    box =
      left: vector.x + @_state.elPosition.left
      top: vector.y + @_state.elPosition.top

    # displacement constraint
    if box.left < bounds.ox
      box.left = bounds.ox
    else if box.left > bounds.x
      box.left = bounds.x
    if box.top < bounds.oy
      box.top = bounds.oy
    else if box.top > bounds.y
      box.top = bounds.y

    box.width  = @_state.elDimension.width
    box.height = @_state.elDimension.height
    box.rotate = @_state.angle.deg
    # issues here if we want a constrain on move...
    box.centerX = @_state.rotatedCenter.x - @_state.workspaceOffset.left + vector.x
    box.centerY = @_state.rotatedCenter.y - @_state.workspaceOffset.top + vector.y

    box

  #
  # Rotation of the rotationContainer
  #
  _calculateRotate = (event)->
    # v is the vector from the center of the content to
    # the pointer of the mouse
    mouse =
      x: event.pageX
      y: event.pageY
    vector = V.vector(mouse, @_state.rotatedCenter)
    # vn is v normalized
    normalized = V.normalized vector
    # "sign" is the sign of v.x
    sign = V.signedDir vector, 'x'
    # @_state.angle is the angle between v and the vector (0,-1)
    @_state.angle.rad = (Math.asin(normalized.y) + Math.PI / 2) * sign
    @_state.angle.deg = @_state.angle.rad * 360 / (2 * Math.PI)

    @_state.angle.cos = Math.cos(@_state.angle.rad)
    @_state.angle.sin = Math.sin(@_state.angle.rad)

    # "original" M
    originalM =
      x: @_state.rotatedCenter.x - @_state.elDimension.width / 2
      y: @_state.rotatedCenter.y - @_state.elDimension.height / 2

    # we now have to figure out the new position of the (0,0)
    # of the zonard:
    cM =
      x: @_state.elOffset.left - @_state.elCenter.x
      y: @_state.elOffset.top - @_state.elCenter.y

    cN =
      x: cM.x * @_state.angle.cos - cM.y * @_state.angle.sin
      y: cM.x * @_state.angle.sin + cM.y * @_state.angle.cos

    mN =
      x: cN.x - cM.x
      y: cN.y - cM.y

    # preparing and changing css
    box =
      left: originalM.x + mN.x - @_state.workspaceOffset.left
      top: originalM.y  + mN.y - @_state.workspaceOffset.top
      rotate: @_state.angle.deg
      width: @_state.elDimension.width
      height: @_state.elDimension.height

    box.centerX = box.left + (box.width / 2) * @_state.angle.cos - (box.height / 2) * @_state.angle.sin
    box.centerY = box.top  + (box.width / 2) * @_state.angle.sin + (box.height / 2) * @_state.angle.cos

    box

  _calculateResize = (event)->
    coef = @_state.coef
    # B0 makes reference to the base of the workspace
    # B1 makes reference to the rotated base (local base of the
    # rotation container

    mouseB0 =
      x: event.pageX - @_state.origin.x
      y: event.pageY - @_state.origin.y

    mouseB1 =
      x:  mouseB0.x * @_state.angle.cos + mouseB0.y * @_state.angle.sin
      y: -mouseB0.x * @_state.angle.sin + mouseB0.y * @_state.angle.cos

    # new dimensions of the el
    dim =
      w: coef[2] * mouseB1.x + @_state.elDimension.width
      h: coef[3] * mouseB1.y + @_state.elDimension.height

    bounds = @_state.sizeBounds
    # constrain is a couple of boolean that decide if we need to
    # change the top and left style
    constrain =
      x: 1
      y: 1
    if dim.w < bounds.wMin
      dim.w = bounds.wMin
      constrain.x = 0
    else if dim.w > bounds.wMax
      dim.w = bounds.wMax
      constrain.x = 0
    if dim.h < bounds.hMin
      dim.h = bounds.hMin
      constrain.y = 0
    else if dim.h > bounds.hMax
      dim.h = bounds.hMax
      constrain.y = 0

    # vector on which we need to project
    #  x: coef[0]
    #  y: coef[1]
    #  so our local vector projected on proj is
    projectionB1 =
      x: mouseB1.x * coef[0]
      y: mouseB1.y * coef[1]

    #translated in the base of the screen, it gives us
    projectionB0 =
      x: @_state.angle.cos * projectionB1.x - @_state.angle.sin * projectionB1.y
      y: @_state.angle.sin * projectionB1.x + @_state.angle.cos * projectionB1.y

    box = rotate: @_state.angle.deg
    if constrain.x
      box.left  = projectionB0.x + @_state.elPosition.left
      box.width = dim.w
    else
      box.left  = @_state.elPosition.left
      box.width = @_state.elDimension.width

    if constrain.y
      box.top    = projectionB0.y + @_state.elPosition.top
      box.height = dim.h
    else
      box.top  = @_state.elPosition.top
      box.height = @_state.elDimension.height

    box.centerX = box.left + (box.width / 2) * @_state.angle.cos - (box.height / 2) * @_state.angle.sin
    box.centerY = box.top  + (box.width / 2) * @_state.angle.sin + (box.height / 2) * @_state.angle.cos

    box

  _calculateCentralDrag = (event)->
    # B0 makes reference to the base of the workspace
    # B1 makes reference to the rotated base (local base of the
    # rotation container

    mouseB0 =
      x: event.pageX - @_state.origin.x
      y: event.pageY - @_state.origin.y

    mouseB1 =
      x:  mouseB0.x * @_state.angle.cos + mouseB0.y * @_state.angle.sin
      y: -mouseB0.x * @_state.angle.sin + mouseB0.y * @_state.angle.cos

    box = @getBox()
    box.mouseLocal = mouseB1
    box

  (proto)->
    proto._setState = _setState
    proto._calculateMove = _calculateMove
    proto._calculateRotate = _calculateRotate
    proto._calculateResize = _calculateResize
    proto._calculateCentralDrag = _calculateCentralDrag

)()