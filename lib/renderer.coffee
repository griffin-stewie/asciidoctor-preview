path = require 'path'
_ = require 'underscore-plus'
cheerio = require 'cheerio'
fs = require 'fs-plus'
fsex = require 'fs-extra'
mustache = require 'mustache'
{$} = require 'atom-space-pen-views'
{Task} = require 'atom'
temp = require 'temp'
debug = require './debuglog'

# use the native highlights
pathWatcherDirectory = atom.packages.resolvePackagePath('markdown-preview')
Highlights = require path.join(pathWatcherDirectory, '..', 'highlights')
highlighter = null
{scopeForFenceName} = require './extension-helper'

{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)

tempFilePath = null
tempHTMLPath = null


exports.toDOMFragment = (text='', filePath, callback) ->
  debug.log "Renderer Executed"
  debug.log filePath
  @originalFilePath = filePath
  @exec = require('child_process').exec
  @callback = callback
  temp.track()
  temp.mkdir 'asciidoctor', (err, dirPath) ->
    debug.log err
    debug.log "テンプディレクトリ " + dirPath
    tempFilePath = path.join dirPath, path.basename(filePath)
    tempHTMLPath = path.join dirPath, "temp.html"
    fsex.copy filePath, tempFilePath, (err) ->
      debug.log tempFilePath
      debug.log tempHTMLPath
      runAsciidoctor(path.dirname(filePath), filePath, tempHTMLPath)

exports.toHTML = (text='', filePath, callback) ->
  debug.log "Renderer Executed"
  debug.log filePath
  @originalFilePath = filePath
  @exec = require('child_process').exec
  @callback = callback
  temp.track()
  temp.mkdir 'asciidoctor', (err, dirPath) ->
    debug.log err
    debug.log "テンプディレクトリ " + dirPath
    tempFilePath = path.join dirPath, path.basename(filePath)
    tempHTMLPath = path.join dirPath, "temp.html"
    fsex.copy filePath, tempFilePath, (err) ->
      debug.log tempFilePath
      debug.log tempHTMLPath
      runAsciidoctor(path.dirname(filePath), filePath, tempHTMLPath)

runAsciidoctor = (baseDirPath, filePath, tempHTMLPath) =>

  commandTemplate = atom.config.get 'asciidoctor-preview.command' ? "/usr/local/bin/asciidoctor --safe-mode unsafe -a lang=ja -b html5 -d book -r asciidoctor-diagram --base-dir {{{baseDirPath}}} -o {{{tempHTMLPath}}} {{{filePath}}}"
  debug.log commandTemplate
  command = mustache.render commandTemplate,
    baseDirPath: baseDirPath
    tempHTMLPath: tempHTMLPath
    filePath: filePath

  debug.log command
  # debug.log process.env
  # debug.log process.env.SHELL
  # Execute command

  pathForCommands = atom.config.get 'asciidoctor-preview.path' ? "/usr/local/bin"
  # debug.log pathForCommands


  @exec command, {"env": {"HOME": process.env.HOME, "PATH": pathForCommands}}, (error, stdout, stderr) =>
    debug.log "Script executed"
    console.log stdout
    console.log stderr
    console.log error

    if error?
      console.log "Script Something wrong"
      @callback(error)
      return
    else
      console.log "Script executed"

    string = fs.readFileSync(tempHTMLPath).toString()

    html = sanitize(string)
    html = resolveImagePaths(html, tempHTMLPath)
    html = removeFontsCSS(html)
    html = removeCSS(html)
    # html = tokenizeCodeBlocks(html)
    debug.log html
    fs.writeFileSync(tempHTMLPath, html)
    # template = document.createElement('template')
    #
    # template.innerHTML = html
    # domFragment = template.content.cloneNode(true)
    @callback(error, tempHTMLPath)



removeFontsCSS = (html) ->
  o = cheerio.load(html)
  # o('link').remove()
  o.html()

removeCSS = (html) ->
  o = cheerio.load(html)
  # o('style').remove()
  o.html()

sanitize = (html) ->
  o = cheerio.load(html)
  o('script').remove()
  attributesToRemove = [
    'onabort'
    'onblur'
    'onchange'
    'onclick'
    'ondbclick'
    'onerror'
    'onfocus'
    'onkeydown'
    'onkeypress'
    'onkeyup'
    'onload'
    'onmousedown'
    'onmousemove'
    'onmouseover'
    'onmouseout'
    'onmouseup'
    'onreset'
    'onresize'
    'onscroll'
    'onselect'
    'onsubmit'
    'onunload'
  ]
  o('*').removeAttr(attribute) for attribute in attributesToRemove
  o.html()

resolveImagePaths = (html, filePath) =>
  o = cheerio.load(html)
  for imgElement in o('img')
    img = o(imgElement)
    if src = img.attr('src')
      continue if src.match(/^(https?|atom):\/\//)
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          img.attr('src', atom.project.getDirectories()[0]?.resolve(src.substring(1)))
      else
        imgPath = path.resolve(path.dirname(filePath), src)
        if fs.existsSync(imgPath)
          img.attr('src', path.resolve(path.dirname(filePath), src))
        else
          img.attr('src', path.resolve(path.dirname(@originalFilePath), src))
  o.html()


tokenizeCodeBlocks = (htmlstr) ->
  o = cheerio.load(htmlstr)

  if fontFamily = atom.config.get('editor.fontFamily')
    o.find('code').css('font-family', fontFamily)

  for preElement in o("pre")
    codeBlock = o(preElement).children().first()
    continue unless codeBlock.length > 0

    fenceName = codeBlock.attr('class')?.replace(/^language-/, '') ? 'text'

    highlighter ?= new Highlights(registry: atom.grammars)
    highlightedHtml = highlighter.highlightSync
      fileContents: codeBlock.text()
      scopeName: scopeForFenceName(fenceName)

    highlightedBlock = o(highlightedHtml)
    highlightedBlock.removeClass('editor').addClass("lang-#{fenceName}")
    o(preElement).replaceWith(highlightedBlock)

  o.html()
