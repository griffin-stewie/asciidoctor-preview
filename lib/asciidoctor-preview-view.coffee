path = require 'path'

{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'
Grim = require 'grim'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{File} = require 'pathwatcher'

renderer = require './renderer'
debug = require './debuglog'

module.exports =
class AsciidoctorPreviewView extends ScrollView
  @content: ->
    @div class: 'asciidoctor-preview native-key-bindings', tabindex: -1

  constructor: ({@editorId, @filePath}) ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    @scrollPotision = 0

  attached: ->
    return if @isAttached
    @isAttached = true

    if @editorId?
      @resolveEditor(@editorId)
    else
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateAll =>
          @subscribeToFilePath(@filePath)

  serialize: ->
    deserializer: 'AsciidoctorPreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @disposables.dispose()

  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  onDidChangeModified: (callback) ->
    # No op to suppress deprecation warning
    new Disposable

  onDidChangeAsciiDoc: (callback) ->
    @emitter.on 'did-change-asciidoc', callback

  on: (eventName) ->
    if eventName is 'asciidoctor-preview:asciidoc-changed'
      Grim.deprecate("Use AsciidoctorPreviewView::onDidChangeAsciiDoc instead of the 'asciidoctor-preview:asciidoc-changed' jQuery event")
    super

  subscribeToFilePath: (filePath) ->
    @file = new File(filePath)
    @emitter.emit 'did-change-title'
    @handleEvents()
    @renderAsciidoc()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @emitter.emit 'did-change-title' if @editor?
        @handleEvents()
        @renderAsciidoc()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateAll(resolve)

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @disposables.add atom.grammars.onDidAddGrammar =>
      debug.log "!!!!!!!!!!!!!!!!!!!!! onDidAddGrammar" if global.enableDebugOutput
      @debouncedRenderAsciidoc ?= _.debounce((=> @renderAsciidoc()), 250)
      @debouncedRenderAsciidoc()

    @disposables.add atom.grammars.onDidUpdateGrammar _.debounce((=> @renderAsciidoc()), 250)

    atom.commands.add @element,
      'core:move-up': =>
        @scrollUp()
      'core:move-down': =>
        @scrollDown()
      'core:save-as': (event) =>
        event.stopPropagation()
        @saveAs()
      'core:copy': (event) =>
        event.stopPropagation() if @copyToClipboard()
      'asciidoctor-preview:zoom-in': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel + .1)
      'asciidoctor-preview:zoom-out': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel - .1)
      'asciidoctor-preview:reset-zoom': =>
        @css('zoom', 1)

    changeHandler = =>
      @renderAsciidoc()

      # TODO: Remove paneForURI call when ::paneForItem is released
      pane = atom.workspace.paneForItem?(this) ? atom.workspace.paneForURI(@getURI())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @disposables.add @file.onDidChange(changeHandler)
    else if @editor?
      # @disposables.add @editor.getBuffer().onDidStopChanging =>
      #   changeHandler() if atom.config.get 'asciidoctor-preview.renderOnSaveOnly'
      @disposables.add @editor.onDidChangePath => @emitter.emit 'did-change-title'
      @disposables.add @editor.getBuffer().onDidSave =>
        changeHandler() if atom.config.get 'asciidoctor-preview.renderOnSaveOnly'
      @disposables.add @editor.getBuffer().onDidReload =>
        changeHandler() if atom.config.get 'asciidoctor-preview.renderOnSaveOnly'

    @disposables.add atom.config.onDidChange 'asciidoctor-preview.breakOnSingleNewline', changeHandler

  renderAsciidoc: ->
    @scrollPotision = @scrollTop()
    debug.log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! renderAsciidoc" if global.enableDebugOutput
    @showLoading()
    if @file?
      @file.read().then (contents) => @renderAsciiDocText(contents)
    else if @editor?
      @renderAsciiDocText(@editor.getText())

  renderAsciiDocText: (text) ->
    renderer.toDOMFragment text, @getPath(), (error, domFragment) =>
      debug.log "Callback renderer.toDOMFragment error:#{error}, domFragment:#{domFragment}"
      if error
        @showError(error)
      else
        @loading = false
        @empty()
        @append(domFragment)
        @scrollTop(@scrollPotision)
        @scrollPotision = 0
        @emitter.emit 'did-change-asciidoc'
        @originalTrigger('asciidoctor-preview:asciidoc-changed')

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Preview"
    else if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "AsciiDoc Preview"

  getIconName: ->
    "eye"

  getURI: ->
    if @file?
      "asciidoctor-preview://#{@getPath()}"
    else
      "asciidoctor-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  getGrammar: ->
    @editor?.getGrammar()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing AsciiDoc Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @loading = true
    @html $$$ ->
      @div class: 'asciidoc-spinner', 'Loading AsciiDoc\u2026'

  copyToClipboard: ->
    return false if @loading

    selection = window.getSelection()
    selectedText = selection.toString()
    selectedNode = selection.baseNode

    # Use default copy event handler if there is selected text inside this view
    return false if selectedText and selectedNode? and (@[0] is selectedNode or $.contains(@[0], selectedNode))

    atom.clipboard.write(@[0].innerHTML)
    true

  saveAs: ->
    return if @loading

    filePath = @getPath()
    if filePath
      filePath += '.html'
    else
      filePath = 'untitled.md.html'
      if projectPath = atom.project.getPath()
        filePath = path.join(projectPath, filePath)

    if htmlFilePath = atom.showSaveDialogSync(filePath)
      # Hack to prevent encoding issues
      # https://github.com/atom/asciidoctor-preview/issues/96
      html = @[0].innerHTML.split('').join('')

      fs.writeFileSync(htmlFilePath, html)
      atom.workspace.open(htmlFilePath)

  isEqual: (other) ->
    @[0] is other?[0] # Compare DOM elements
