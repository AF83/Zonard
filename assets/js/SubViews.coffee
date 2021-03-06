# global subcontainer to which rotations will be applied
# el
#   display
#     content
#     borders
#   handlerContainer
#     tracker
#     rotateHandle
#     dragbars
#     handles

# prefix to put before any of the class names of the subviews
classPrefix = 'zonard-'

# display container that holds the content and the borders of the
# content
class DisplayContainerView extends Backbone.View
  className: -> "#{classPrefix}displayContainer"

  initialize: ->
    @borders = for card, i in Cards[..3]
      new BorderView card: card
    @visibility = on

  # @chainable
  render: ->
    @$el.append border.render().el for border in @borders
    @

  remove: ->
    for border in @borders
      border.remove()
    super()
    @

# the content that we display
class ContentView extends Backbone.View
  className: -> "#{classPrefix}content"


# the borders are the line that are displayed around the content
# @params options {object}
# @params options.card {srting}
class BorderView extends Backbone.View
  constructor: (options)->
    @card = options.card
    super options

  className: -> "#{classPrefix}border ord-#{@card}"


# @params options {object}
# @params options.centralHandle {bool}
class HandlerContainerView extends Backbone.View
  className: -> "#{classPrefix}handlerContainer"

  # @params options {object}
  # @params options.centralHandle {bool} (optional)
  initialize: (options = {})->
    @dragbars = for card, i in Cards[..3]
      new DragbarView card: card
    @handles = for card, i in Cards
      new HandleView card: card
    @rotateHandle = new RotateHandleView
    @tracker = new TrackerView
    if options.centralHandle
      @centralHandle = new CentralHandle

  # @chainable
  render: ->
    @$el.append(
      @tracker.render().el
      dragbar.render().el for dragbar in @dragbars
      handle.render().el for handle in @handles
      @rotateHandle.render().el
      @centralHandle.render().el if @centralHandle?
    )
    @

  remove: ->
    for bar in @dragbars
      bar.remove()
    for handle in @handles
      handle.remove()
    @rotateHandle?.remove()
    @tracker?.remove()
    @centralHandle?.remove()
    super()

class SelectionView extends Backbone.View
  events:
    mousedown: 'start'

  # @params options {object}
  # @params options.card {srting}
  initialize: (options)->
    @card = options.card
    @indexCard = _.indexOf(ordCards, @card)
    @$el.css cursor: @card + '-resize'

  start: (event)->
    return unless event.which is 1
    event.preventDefault()
    origin =
      x: event.pageX
      y: event.pageY
    @trigger 'drag:start', {origin: origin, card: @card}

  assignCursor: (angle)=>
    permut = (@indexCard + Math.floor((angle + Math.PI / 8) / (Math.PI / 4))) % 8
    permut += 8 if permut < 0
    currentCard = ordCards[permut]
    @el.style.cursor = "#{currentCard}-resize"

# create the dragbars
class DragbarView extends SelectionView
  constructor: (options)->
    @card = options.card
    super options

  className: -> "#{classPrefix}dragbar ord-#{@card}"


# create the handles
class HandleView extends SelectionView
  constructor: (options)->
    @card = options.card
    super options

  className: -> "#{classPrefix}handle ord-#{@card}"


# the special handler responsible for the rotation
class RotateHandleView extends Backbone.View
  className: -> "#{classPrefix}handleRotation"

  events:
    mousedown: 'start'

  start: (event)->
    return unless event.which is 1
    event.preventDefault()
    @trigger 'drag:start'


class CentralHandle extends Backbone.View
  className: -> "#{classPrefix}handle central"

  events:
    mousedown: 'start'

  start: (event)->
    return unless event.which is 1
    event.preventDefault()
    origin =
      x: event.pageX
      y: event.pageY
    @trigger 'drag:start', origin: origin


#This element is here to receive mouse events (clicks)
class TrackerView extends Backbone.View
  className: -> "#{classPrefix}tracker"

  events:
    mousedown : 'start'
    mouseup: _.debounce(((e)->
      if @doubleclicked
        @doubleclicked = no
      else
        @focus e
    ), 250)
    dblclick: (e)->
      @doubleclicked = yes
      @dblClick e

  focus: (event)->
    @trigger 'focus'

  dblClick: (event)->
    @trigger 'dblclick'
    @focus event

  start: (event)->
    return unless event.which is 1
    event.preventDefault()
    origin =
      x: event.pageX
      y: event.pageY
    @trigger 'drag:start', origin: origin
