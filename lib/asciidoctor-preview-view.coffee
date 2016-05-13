fs                    = require 'fs'
{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, $$$, ScrollView}  = require 'atom-space-pen-views'
path                  = require 'path'
os                    = require 'os'
renderer              = require './renderer'

module.exports =
class AtomHtmlPreviewView extends ScrollView
  atom.deserializers.add(this)

  editorSub           : null
  onDidChangeTitle    : -> new Disposable()
  onDidChangeModified : -> new Disposable()

  @deserialize: (state) ->
    new AtomHtmlPreviewView(state)

  @content: ->
    @div class: 'asciidoctor-preview native-key-bindings', tabindex: -1, =>
      style = 'z-index: 2; padding: 2em;'
      @div class: 'show-error', style: style, 'Previewing AsciiDoc Failed'
      @div class: 'show-loading', style: style, "Loading AsciiDoc\u2026"

  constructor: ({@editorId, filePath}) ->
    super
    @disposables = new CompositeDisposable
    @emitter = new Emitter
    if @editorId?
      @resolveEditor(@editorId)
      @tmpPath = @getPath() # after resolveEditor
    else
      if atom.workspace?
        @subscribeToFilePath(filePath)
      else
        # @subscribe atom.packages.once 'activated', =>
        atom.packages.onDidActivatePackage =>
          @subscribeToFilePath(filePath)

    # Disable pointer-events while resizing
    handles = $("atom-pane-resize-handle")
    handles.on 'mousedown', => @onStartedResize()

  attached: ->

    return if @isAttached
    @isAttached = true
    console.log "attached"
    if @editorId?
      @resolveEditor(@editorId)
    else
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateAll =>
          @subscribeToFilePath(@filePath)

  # subscribeToFilePath: (filePath) ->
  #   @file = new File(filePath)
  #   @emitter.emit 'did-change-title'
  #   @handleEvents()
  #   @renderAsciidoc()

  onStartedResize: ->
    @css 'pointer-events': 'none'
    document.addEventListener 'mouseup', @onStoppedResizing.bind this

  onStoppedResizing: ->
    @css 'pointer-events': 'all'
    document.removeEventListener 'mouseup', @onStoppedResizing

  serialize: ->
    deserializer : 'AsciidoctorPreviewView'
    filePath     : @getPath()
    editorId     : @editorId

  destroy: ->
    # @unsubscribe()
    if editorSub?
      @editorSub.dispose()

  subscribeToFilePath: (filePath) ->
    console.log "subscribeToFilePath"
    @trigger 'title-changed'
    @handleEvents()
    @renderHTML()

  resolveEditor: (editorId) ->
    console.log "resolveEditor"
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @trigger 'title-changed' if @editor?
        @handleEvents()
        @renderHTML()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        atom.workspace?.paneForItem(this)?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      # @subscribe atom.packages.once 'activated', =>
      atom.packages.onDidActivatePackage =>
        resolve()
        @renderHTML()

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: =>
    contextMenuClientX = 0
    contextMenuClientY = 0

    @on 'contextmenu', (event) ->
      contextMenuClientY = event.clientY
      contextMenuClientX = event.clientX

    atom.commands.add @element,
      'asciidoctor-preview:open-devtools': =>
        @webview.openDevTools()
      'asciidoctor-preview:inspect': =>
        @webview.inspectElement(contextMenuClientX, contextMenuClientY)
      'asciidoctor-preview:print': =>
        @webview.print()


    changeHandler = =>
      @renderHTML()
      pane = atom.workspace.paneForItem?(this) ? atom.workspace.paneForURI(@getURI())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    @editorSub = new CompositeDisposable

    if @editor?
      @disposables.add @editor.onDidChangePath => @emitter.emit 'did-change-title'
      @disposables.add @editor.getBuffer().onDidSave =>
        changeHandler() if atom.config.get 'asciidoctor-preview.renderOnSaveOnly'
      @disposables.add @editor.getBuffer().onDidReload =>
        changeHandler() if atom.config.get 'asciidoctor-preview.renderOnSaveOnly'

  renderHTML: ->
    @showLoading()
    if @editor?
      if not atom.config.get("asciidoctor-preview.triggerOnSave") && @editor.getPath()?
        @save(@renderHTMLCode)
      else
        @renderHTMLCode()

  save: (callback) ->
    console.log "save called"
    # Temp file path
    outPath = path.resolve path.join(os.tmpdir(), @editor.getTitle() + ".html")
    out = ""
    fileEnding = @editor.getTitle().split(".").pop()

    if atom.config.get("asciidoctor-preview.enableMathJax")
      out += """
      <script type="text/x-mathjax-config">
      MathJax.Hub.Config({
      tex2jax: {inlineMath: [['\\\\f$','\\\\f$']]},
      menuSettings: {zoom: 'Click'}
      });
      </script>
      <script type="text/javascript"
      src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
      </script>
      """

    if atom.config.get("asciidoctor-preview.preserveWhiteSpaces") and fileEnding in atom.config.get("asciidoctor-preview.fileEndings")
      # Enclose in <pre> statement to preserve whitespaces
      out += """
      <style type="text/css">
      body { white-space: pre; }
      </style>
      """
    else
      # Add base tag; allow relative links to work despite being loaded
      # as the src of an webview
      out += "<base href=\"" + @getPath() + "\">"

    out += @editor.getText()

    @tmpPath = outPath
    fs.writeFile outPath, out, =>
      try
        @renderHTMLCode()
      catch error
        @showError error

  renderHTMLCode: () ->
    text = @editor.getText()
    renderer.toHTML text, @getPath(), (error, tempHTMLPath) =>
      console.log "Callback renderer.toDOMFragment error:#{error}, tempHTMLPath:#{tempHTMLPath}"
      if error
        @showError(error)
      else
        @emitter.emit 'did-change-asciidoc'
        @originalTrigger('asciidoctor-preview:asciidoc-changed')
        unless @webview?
          webview = document.createElement("webview")
          # Fix from @kwaak (https://github.com/webBoxio/asciidoctor-preview/issues/1/#issuecomment-49639162)
          # Allows for the use of relative resources (scripts, styles)
          webview.setAttribute("sandbox", "allow-scripts allow-same-origin")
          webview.setAttribute("class", "webview")
          @webview = webview
          @append $ webview

        @webview.src = tempHTMLPath
        try
          @find('.show-error').hide()
          @find('.show-loading').hide()
          @find('.webview').show()
          @webview.reload()

        catch error
          null

        # @trigger('asciidoctor-preview:html-changed')
        atom.commands.dispatch 'asciidoctor-preview', 'html-changed'

  getTitle: ->
    if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "HTML Preview"

  getURI: ->
    "asciidoctor-preview://editor/#{@editorId}"

  getPath: ->
    if @editor?
      @editor.getPath()

  showError: (result) ->
    failureMessage = result?.message
    @find('.webview').hide()
    @find('.show-loading').hide()
    @find('.show-error')
    .html $$$ ->
      @h2 'Previewing AsciiDoc Failed'
      @h3 failureMessage if failureMessage?
    .show()

  showLoading: ->
    @find('.webview').hide()
    @find('.show-error').hide()
    @find('.show-loading').show()
