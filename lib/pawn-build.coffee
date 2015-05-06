{CompositeDisposable} = require 'atom'
{MessagePanelView, PlainMessageView, LineMessageView} = require 'atom-message-panel'
path = require 'path'
child_process = require 'child_process'

module.exports = PawnBuild =
  messages: null
  subscriptions: null

  # Configuration options
  config:
    # Path to pawncc executable
    pawnExecutablePath:
      title: 'Path to pawncc executable'
      type: 'string'
      default: 'C:\\pawn\\pawncc.exe'

    # List of pawncc options (passed before filename)
    pawnOptions:
      title: 'Pawn options'
      type: 'array'
      default: ['-d1', '-(', '-;']
      items:
        type: 'string'

  activate: (state) ->
    # Activate package
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'pawn-build:build': => @build()

  deactivate: ->
    # Deactivate package
    @messages?.detatch()
    @subscriptions.dispose()
    @pawnBuildView.destroy()

  serialize: -> undefined

  createOutputPanel: ->
    # Create output panel (or return if already exists)
    unless @messages?
      @messages = new MessagePanelView
        title: 'Pawn output'
    @messages.attach()
    @messages.clear()
    return @messages

  build: ->
    # get path of currently open file
    filepath = atom.workspace.getActiveTextEditor()?.getPath()


    # only continue if file is a .pwn file
    return unless filepath? and path.extname(filepath) == '.pwn'
    #also save it, so the unsaved buffer is included
    atom.workspace.getActiveTextEditor().save()

    # prepare command and arguments from package settigns
    cmd = atom.config.get('pawn-build.pawnExecutablePath')
    args = atom.config.get('pawn-build.pawnOptions')
    args.push path.basename filepath

    # run pawncc command
    process = child_process.spawn cmd, args,
      cwd: path.dirname filepath # run in the current file's directory

    procout = []       # store output from pawncc
    hasError = false   # store error status

    # read output from pawncc
    process.stdout.on 'data', (data) ->
      procout.push data.toString()
    process.stderr.on 'data', (data) ->
      procout.push data.toString()

    process.on 'error', (error) =>
      # show message if pawncc failed to run (for instance due to invalid path)
      hasError = true
      output = @createOutputPanel()
      output.add new PlainMessageView
        message: 'Could not run pawncc: ' + error.message

    process.on 'close', (exitCode, signal) =>
      return if hasError

      data = procout.join('')
      output = @createOutputPanel()

      if data
        #Jump to the first error line
        editor = atom.workspace.getActiveTextEditor()
        invalidLine = editor.getLineCount()
        row = data.match(/\(([1-9][0-9]*)\)/)[1]
        if row? and not row
          editor.setCursorBufferPosition([row-1,0])

        # show output of pawncc
        lines = data.split('\n')
        for line in lines
          output.add new PlainMessageView
            message: line
      else
        # show error message if pawncc returned no output (unknown error)
        output.add new PlainMessageView
          message: 'Could not run pawncc: Unknown error (' + exitCode + ')'
