url = require 'url'
fs = require 'fs-plus'
{$} = require 'atom-space-pen-views'
debug = require './debuglog'

AsciidoctorPreviewView = null
renderer = null

createAsciidoctorPreviewView = (state) ->
  AsciidoctorPreviewView ?= require './asciidoctor-preview-view'
  new AsciidoctorPreviewView(state)

isAsciidoctorPreviewView = (object) ->
  AsciidoctorPreviewView ?= require './asciidoctor-preview-view'
  object instanceof AsciidoctorPreviewView

atom.deserializers.add
  name: 'AsciidoctorPreviewView'
  deserialize: (state) ->
    createAsciidoctorPreviewView(state) if state.constructor is Object

module.exports =
  config:
    command:
      title: 'Command'
      description: 'You can use {{{tempHTMLPath}}}, {{{baseDirPath}}}, {{{filePath}}}'
      type: 'string'
      default: "asciidoctor --safe-mode unsafe -a lang=ja -b html5 -d book -r asciidoctor-diagram --base-dir {{{baseDirPath}}} -o {{{tempHTMLPath}}} {{{filePath}}}"
      order: 40
    path:
      title: 'PATH'
      description: 'for commands that you use'
      type: 'string'
      default: '/usr/local/bin/'
      order: 41
    grammars:
      title: 'Grammars'
      type: 'array'
      default: [
        'source.asciidoc'
        'text.plain'
        'text.plain.null-grammar'
      ]
      order: 42
    renderOnSaveOnly:
      title: 'Update on save'
      description: 'Update preveiw on save'
      type: 'boolean'
      default: false
      order: 50


  activate: (state) ->
    atom.commands.add 'atom-workspace',
      'asciidoctor-preview:toggle': => @toggle()

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'asciidoctor-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createAsciidoctorPreviewView(editorId: pathname.substring(1))
      else
        createAsciidoctorPreviewView(filePath: pathname)


  toggle: ->
    console.log 'AsciidoctorPreview was toggled!'
    if isAsciidoctorPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = @checkFile()
    return unless editor?

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "asciidoctor-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (asciidoctorPreviewView) ->
      if isAsciidoctorPreviewView(asciidoctorPreviewView)
        previousActivePane.activate()

  checkFile: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    grammars = atom.config.get('asciidoctor-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars
    editor
