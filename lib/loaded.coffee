{CompositeDisposable, Range} = require 'atom'
LoadedView = require './loaded-view'
fs = require 'fs'
path = require 'path'
untildify = require 'untildify'
mkdirp = require 'mkdirp'
touch = require 'touch'

module.exports = Loaded =
  # Provider for autocomplete-plus.
  provide: ->
    selector: '.text.location' # Custom grammar.
    inclusionPriority: 99 # Exclude other providers.
    excludeLowerPriority: true
    filterSuggestions: true
    getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix}) =>
      new Promise (resolve) =>
        resolve @getLocationSuggestions editor.getText()
    onDidInsertSuggestion: ({editor, triggerPosition, suggestion}) =>
      @view.showSuggestions()

  getLocationSuggestions: (text) ->
    location = @getNormalizedLocation text
    separatorIndex = location.lastIndexOf path.sep
    directory = location.slice 0, separatorIndex + 1
    partialName = location.slice separatorIndex + 1
    names = []
    if text isnt '~'
      if fs.existsSync directory
        stats = fs.lstatSync directory
        # If directory is a symbolic link, follow the link.
        if stats.isSymbolicLink()
          directory = fs.readlinkSync directory
          stats = fs.lstatSync directory
        if stats.isDirectory()
          names = fs.readdirSync directory
    for name in names
      stats = fs.lstatSync directory + path.sep + name
      # If name is a directory, append a separator (e.g. /, \).
      if stats.isDirectory()
        name = name + path.sep
      text: name
      replacementPrefix: partialName
      # rightLabel: if stats.isDirectory() then 'directory' else 'file'

  activate: (state) ->
    @view = new LoadedView()
    @view.init()
    @view.onOpen (location) => @open location
    @view.onOpenOrCreate (location) => @openOrCreate location
    @view.onDidChangeLocation (location) => @renderInvalidFragmentRange location
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'loaded:show': => @show()

  deactivate: ->
    @subscriptions.dispose()
    @view.destroy()

  serialize: ->

  show: ->
    userHome = @getUserHome()
    filePath = atom.workspace.getActiveTextEditor()?.buffer?.file?.path
    directory =
      if filePath
        location = @getNormalizedLocation filePath
        separatorIndex = location.lastIndexOf path.sep
        location.slice 0, separatorIndex + 1
      else
        if userHome
          userHome + '/'
        else
          ''
    # Replace userHome with "~" (except in Windows).
    if process.platform isnt 'win32' && directory.startsWith userHome
      directory = '~' + directory.slice userHome.length
    @view.show directory

  open: (location) ->
    normalizedLocation = @getNormalizedLocation location
    stats = fs.lstatSync normalizedLocation
    # If location is a symbolic link, follow the link.
    if stats.isSymbolicLink()
      normalizedLocation = fs.readlinkSync normalizedLocation
      stats = fs.lstatSync normalizedLocation
    # If location is a directory, add it as a project.
    if stats.isDirectory()
      atom.project.addPath normalizedLocation
      atom.commands.dispatch atom.views.getView(atom.workspace), 'tree-view:show'
    # Else, open as file.
    else
      atom.workspace.open normalizedLocation

  # If location does not exist, create necessary directories and file first.
  openOrCreate: (location) ->
    normalizedLocation = @getNormalizedLocation location
    if not fs.existsSync normalizedLocation
      directory = location.slice 0, (location.lastIndexOf path.sep) + 1
      normalizedDirectory = @getNormalizedLocation directory
      # If directory does not exist, create directory and any necessary subdirectories.
      if not fs.existsSync normalizedDirectory
        mkdirp.sync normalizedDirectory
      # If it is a file location, create empty file.
      if not location.endsWith path.sep
        touch.sync normalizedLocation
    @open location

  getNormalizedLocation: (location) ->
    path.normalize(untildify location)

  getUserHome: ->
    process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']

  renderInvalidFragmentRange: (location) ->
    invalidFragmentRange = null
    fragments = location.split path.sep
    for i in [fragments.length..1]
      partial = fragments.slice(0, i).join(path.sep)
      normalizedPartial = @getNormalizedLocation partial
      if fs.existsSync normalizedPartial
        invalidFragmentRangeStart =
          (stats = fs.lstatSync normalizedPartial
          # If directory is a symbolic link, follow the link.
          if stats.isSymbolicLink()
            normalizedPartial = fs.readlinkSync normalizedPartial
            stats = fs.lstatSync normalizedPartial
          proceedingChar = location.slice partial.length, partial.length + 1
          if stats.isDirectory() && proceedingChar is path.sep
            partial.length + 1
          else
            partial.length)
        invalidFragmentRange = new Range([0, invalidFragmentRangeStart], [0, location.length])
        break
    @view.renderInvalidFragmentRange invalidFragmentRange

# # # TODO: Still needs the first letter of a candidate before it can match (e.g. typing "b" will not match "lib", but "lb" will).
# # # TODO: If location is a directory, add as project and auto-select in tree view.
# # # TODO: Icons?
# # # TODO: Test in Windows.
