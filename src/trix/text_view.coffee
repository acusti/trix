class Trix.TextView
  constructor: (@element, @text) ->
    @element.setAttribute("contenteditable", "true")
    @element.setAttribute("autocorrect", "off")
    @element.setAttribute("spellcheck", "false")

  focus: ->
    @element.focus()

  render: ->
    selectedRange = @getSelectedRange()
    @element.innerHTML = ""
    @element.appendChild(element) for element in @createElementsForText()
    @setSelectedRange(selectedRange)

  createElementsForText: ->
    containers = []
    previousAttributes = {}

    @text.eachRun (run) ->
      parent = null
      container = createElement(run)

      if href = run.attributes.href
        if href is previousAttributes.href
          parent = containers[containers.length - 1]
        else
          link = createElement(tagName: "a", attributes: {href}, position: run.position)
          link.appendChild(container)
          container = link

      if parent
        parent.appendChild(container)
      else
        containers.push(container)

      previousAttributes = run.attributes

    # Add an extra newline if the text ends with one. Otherwise, the cursor won't move down.
    if @text.endsWith("\n")
     element = createElementsForString("\n", @text.getLength())[0]
     containers.push(element)

    containers

  getSelectedRange: ->
    return @lockedRange if @lockedRange

    selection = window.getSelection()
    return unless selection.rangeCount > 0

    range = selection.getRangeAt(0)
    return unless isWithin(@element, range.startContainer) and isWithin(@element, range.endContainer)

    startPosition = @findPositionFromContainerAtOffset(range.startContainer, range.startOffset)
    endPosition = @findPositionFromContainerAtOffset(range.endContainer, range.endOffset)
    [startPosition, endPosition]

  setSelectedRange: ([startPosition, endPosition]) ->
    return if @lockedRange
    return unless startPosition? and endPosition?

    range = document.createRange()
    [startContainer, startOffset] = @findContainerAndOffsetForPosition(startPosition)
    [endContainer, endOffset] = @findContainerAndOffsetForPosition(endPosition)

    try
      range.setStart(startContainer, startOffset)
      range.setEnd(endContainer, endOffset)
    catch err
      range.setStart(@element, 0)
      range.setEnd(@element, 0)

    selection = window.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)

  lockSelection: ->
    @lockedRange = @getSelectedRange()

  unlockSelection: ->
    if lockedRange = @lockedRange
      delete @lockedRange
      lockedRange

  findPositionFromContainerAtOffset: (container, offset) ->
    if container.nodeType is Node.TEXT_NODE
      container.trixPosition + offset
    else
      container.childNodes[offset]?.trixPosition ? offset

  findContainerAndOffsetForPosition: (position) ->
    return [@element, 0] if position < 1

    walker = createTreeWalker(@element)
    node = walker.currentNode

    while walker.nextNode()
      break if walker.currentNode.trixPosition > position
      node = walker.currentNode

    if node.nodeType is Node.TEXT_NODE
      [node, position - node.trixPosition]
    else
      offset = [node.parentNode.childNodes...].indexOf(node)
      [node.parentNode, offset]

  createElement = ({string, attributes, position, tagName}) ->
    element = document.createElement(tagName ? "span")

    if attributes
      if attributes.href and tagName is "a"
        element.setAttribute("href", attributes.href)

      element.style["font-weight"] = "bold" if attributes.bold
      element.style["font-style"] = "italic" if attributes.italic
      element.style["text-decoration"] = "underline" if attributes.underline
      element.style["background-color"] = "highlight" if attributes.selected

    if string
      for child in createElementsForString(string, position)
        element.appendChild(child)

    element

  createElementsForString = (string, position) ->
    elements = []

    for substring, index in string.split("\n")
      if index > 0
        node = document.createElement("br")
        node.trixPosition = position
        position += 1
        elements.push(node)

      if substring.length
        node = document.createTextNode(preserveSpaces(substring))
        node.trixPosition = position
        position += substring.length
        elements.push(node)

    elements

  preserveSpaces = (string) ->
    string
      # Replace two spaces with a space and a non-breaking space
      .replace(/\s{2}/g, " \u00a0")
      # Replace leading space with a non-breaking space
      .replace(/^\s{1}/, "\u00a0")
      # Replace trailing space with a non-breaking space
      .replace(/\s{1}$/, "\u00a0")

  isWithin = (ancestor, element) ->
    while element
      return true if element is ancestor
      element = element.parentNode
    false

  createTreeWalker = (element) ->
    whatToShow = NodeFilter.SHOW_ELEMENT + NodeFilter.SHOW_TEXT

    acceptNode = (node) ->
      if node.trixPosition?
        NodeFilter.FILTER_ACCEPT
      else
        NodeFilter.FILTER_SKIP

    document.createTreeWalker(element, whatToShow, {acceptNode})