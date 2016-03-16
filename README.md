# loaded
[Atom](http://atom.io/) package

Open files and directories à la Emacs ido-mode.  Can also create new files and directories if they don't exist.  Integrated `autocomplete-plus` via tons of hacks.

![open](https://github.com/halohalospecial/atom-loaded/blob/master/images/open.gif?raw=true)

### Usage

Bind `loaded:show` like this:

```
'atom-workspace':
  'cmd-o': 'loaded:show'
```

`loaded:show` opens a panel where you can type in the path to a file or directory.  If the path does not exist, the invalid fragment will be highlighted.

### Keybindings

`loaded:autocomplete`: Autocomplete using the highlighted suggestion.

`loaded:open`: If the path points to a file, open the file.  If the path points to a directory, add the directory as a project in Tree View.  Autocomplete first if there's a highlighted suggestion.

`loaded:open-or-create`: If the path does not exist, create the necessary files and directories before calling `loaded:open`.

![open-or-create](https://github.com/halohalospecial/atom-loaded/blob/master/images/open-or-create.gif?raw=true)

`loaded:backspace`: Delete the character preceeding the cursor.  If it is a path separator (e.g. /, \\), also delete the preceeding fragment until the previous separator.

![backspace](https://github.com/halohalospecial/atom-loaded/blob/master/images/backspace.gif?raw=true)

`loaded:cancel`: Close panel.

Default keybindings:
```
'atom-text-editor.loaded.autocomplete-active':
  'tab': 'loaded:autocomplete'
  'enter': 'loaded:open'
  'shift-enter': 'loaded:open-or-create'
  'backspace': 'loaded:backspace'
  'escape': 'loaded:cancel'
```
