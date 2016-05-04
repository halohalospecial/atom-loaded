{Emitter, CompositeDisposable} = require 'atom'
path = require 'path'
fuzzaldrin = require 'fuzzaldrin'

class LoadedView extends HTMLElement
  init: ->
    @classList.add 'loaded-view'
    containerView = document.createElement 'div'
    @editorView = document.createElement 'atom-text-editor'
    @editorView.classList.add 'atom-text-editor', 'loaded', 'autocomplete-active'
    containerView.appendChild @editorView
    @appendChild containerView
    @editor = @editorView.getModel()
    # Not using @editor.setMini(true) so that the suggestions will be displayed outside the modal panel.

    # Set editor grammar to "Location".
    grammarPath = path.join __dirname, '../grammars/location.cson'
    grammar = atom.grammars.readGrammarSync grammarPath
    @editor.setGrammar grammar

    @panel = atom.workspace.addModalPanel item: this, visible: false

    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor.loaded',
      'blur':  => @hide()
      'loaded:cancel':  => @hide() # escape
      'loaded:autocomplete': => @autocomplete() # tab
      'loaded:open': => @open() # enter
      'loaded:open-or-create': => @openOrCreate() # shift-enter
      'loaded:backspace': => @backspace() # backspace

    # Get reference to `AutocompleteManager` from the `autocomplete-plus` package.
    autocompletePackage = atom.packages.getActivePackage 'autocomplete-plus'
    @autocompleteManager = autocompletePackage.mainModule.getAutocompleteManager()

    # Override `filterSuggestions` function to allow matching characters which are not in the first position.
    @autocompleteManager.filterSuggestions = @filterSuggestions.bind @autocompleteManager

  onOpen: (fn) -> @emitter.on 'open', fn
  onOpenOrCreate: (fn) -> @emitter.on 'open-or-create', fn
  onDidChangeLocation: (fn) -> @emitter.on 'did-change-location', fn

  # Modified from https://github.com/atom/autocomplete-plus/blob/7cca9b663a29d60e3257cb6c446c752a3fc01352/lib/autocomplete-manager.coffee.
  # Allows matching characters which are not in the first position.  (Example: "b" will match "lib")
  filterSuggestions: (suggestions, {prefix}) ->
    results = []
    for suggestion, i in suggestions
      # sortScore mostly preserves in the original sorting. The function is
      # chosen such that suggestions with a very high match score can break out.
      suggestion.sortScore = Math.max(-i / 10 + 3, 0) + 1
      suggestion.score = null

      text = (suggestion.snippet or suggestion.text)
      suggestionPrefix = suggestion.replacementPrefix ? prefix
      prefixIsEmpty = not suggestionPrefix or suggestionPrefix is ' '
      #firstCharIsMatch = not prefixIsEmpty and suggestionPrefix[0].toLowerCase() is text[0].toLowerCase()

      if prefixIsEmpty
        results.push(suggestion)
      #if firstCharIsMatch and (score = fuzzaldrin.score(text, suggestionPrefix)) > 0
      if (score = fuzzaldrin.score(text, suggestionPrefix)) > 0
        suggestion.score = score * suggestion.sortScore
        results.push(suggestion)

    results.sort(@reverseSortOnScoreComparator)
    results

  destroy: ->
    @emitter.dispose()
    @subscriptions.dispose()
    @panel.destroy()
    @remove()

  show: (text) ->
    # Override the autocomplete configuration.
    @originalAutoConfirmSingleSuggestionEnabled = @autocompleteManager.autoConfirmSingleSuggestionEnabled
    @originalBackspaceTriggersAutocomplete = @autocompleteManager.backspaceTriggersAutocomplete
    @autocompleteManager.autoConfirmSingleSuggestionEnabled = false
    @autocompleteManager.backspaceTriggersAutocomplete = true

    # Hack to enable autocomplete in our mini editor:
    @originalTextEditor = atom.workspace.getActiveTextEditor()
    @autocompleteManager.updateCurrentEditor @editor

    @panel.show()
    @editorView.focus()
    @editor.selectAll()

    @editorOnDidStopChangingDisposable = @editor.onDidStopChanging =>
      @emitter.emit 'did-change-location', @editor.getText()

    @editor.insertText(text)

    @shown = true
    # Force the suggestions to appear.
    @showSuggestions()

  hide: ->
    @shown = false
    @editorOnDidStopChangingDisposable.dispose()
    atom.commands.dispatch @editorView, 'autocomplete-plus:cancel'
    # Revert to the original autocomplete configuration.
    @autocompleteManager.autoConfirmSingleSuggestionEnabled = @originalAutoConfirmSingleSuggestionEnabled
    @autocompleteManager.backspaceTriggersAutocomplete = @originalBackspaceTriggersAutocomplete
    @panel.hide()
    # Reactivate the previous pane.
    atom.workspace.getActivePane().activate()
    # Hack to return the autocomplete functionality to the previous text editor:
    if @originalTextEditor
      @autocompleteManager.updateCurrentEditor @originalTextEditor

  autocomplete: ->
    atom.commands.dispatch @editorView, 'autocomplete-plus:confirm'
    @showSuggestions()

  showSuggestions: ->
    setTimeout =>
      if @shown
        atom.commands.dispatch @editorView, 'autocomplete-plus:activate', activatedManually: true
    , 1

  open: ->
    # Select primary suggestion, if any.
    atom.commands.dispatch @editorView, 'autocomplete-plus:confirm'
    @hide()
    @emitter.emit 'open', @editor.getText()

  openOrCreate: ->
    @hide()
    @emitter.emit 'open-or-create', @editor.getText()

  # If preceeding character is a separator, delete preceeding fragment.  Otherwise, delete preceeding character.
  backspace: ->
    position = @editor.getCursorBufferPosition()
    preceedingPosition = position.traverse [0, -1]
    preceedingChar = @editor.getTextInBufferRange [preceedingPosition, position]
    if preceedingChar is path.sep
      @editor.transact =>
        @editor.backspace()
        @editor.backwardsScanInBufferRange new RegExp(path.sep), [@editor.getCursorBufferPosition(), [0, 0]], ({range, stop}) =>
          @editor.selectToBufferPosition range.end
          @editor.delete()
          stop()
      @showSuggestions()
    else
      @editor.backspace()

  renderInvalidFragmentRange: (range) ->
    @invalidFragmentMarker?.destroy()
    if range? && not range.isEmpty()
      @invalidFragmentMarker = @editor.markBufferRange range, invalidate: 'never', persistent: false
      @editor.decorateMarker @invalidFragmentMarker, type: 'highlight', class: 'invalid-fragment'

module.exports =
  document.registerElement 'loaded-view',
    extends: 'div'
    prototype: LoadedView.prototype
