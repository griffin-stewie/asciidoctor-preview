AsciidoctorPreviewView = require './asciidoctor-preview-view'
{CompositeDisposable} = require 'atom'

module.exports = AsciidoctorPreview =
  asciidoctorPreviewView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @asciidoctorPreviewView = new AsciidoctorPreviewView(state.asciidoctorPreviewViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @asciidoctorPreviewView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'asciidoctor-preview:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @asciidoctorPreviewView.destroy()

  serialize: ->
    asciidoctorPreviewViewState: @asciidoctorPreviewView.serialize()

  toggle: ->
    console.log 'AsciidoctorPreview was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
