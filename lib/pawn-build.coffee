{CompositeDisposable} = require 'atom'
{MessagePanelView, PlainMessageView, LineMessageView} = require 'atom-message-panel'
path = require 'path'
child_process = require 'child_process'

module.exports = PawnBuild =
  messages: null
  subscriptions: null

  # configuration options
  config:
    # path to pawncc executable
    pawnExecutablePath:
      title: 'Path to pawncc executable'
      type: 'string'
      default: 'C:\\pawn\\pawncc.exe'

    # list of pawncc options (passed before filename)
    pawnOptions:
      title: 'Pawn options'
      type: 'array'
      default: ['-d1', '-(', '-;']
      items:
        type: 'string'

    # should jump to error?
    shouldJumpToError:
      title: 'Jump to first error?'
      type: 'boolean'
      default: false

  activate: (state) ->
    # activate package
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'pawn-build:build': => @build()

  deactivate: ->
    # deactivate package
    @messages?.detatch()
    @subscriptions.dispose()
    @pawnBuildView.destroy()

  serialize: -> undefined

  createOutputPanel: ->
    # create output panel (or return if already exists)
    unless @messages?
      @messages = new MessagePanelView
        title: 'Pawn output'
    @messages.attach()
    @messages.clear()
    return @messages

  build: ->
    # get current editor
    editor = atom.workspace.getActiveTextEditor()

    # get path of currently open file
    filepath = editor?.getPath()

    # only continue if file is a .pwn file
    return unless filepath? and path.extname(filepath) == '.pwn'

    # also save the current file, so the current buffer is included
    editor.save()

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
        # jump to the first error line
        if atom.config.get('build-pawn.shouldJumpToError')
          match = data.match(/\(([1-9][0-9]*)\)/)
          if match?
            row = parseInt(match[1]) - 1
            if row < editor.getLineCount()
              editor.setCursorBufferPosition [row,0]

        # show output of pawncc
        lines = data.split('\n')
        for line in lines
          output.add new PlainMessageView
            message: line
      else
        # show error message if pawncc returned no output (unknown error)
        output.add new PlainMessageView
          message: 'Could not run pawncc: Unknown error (' + exitCode + ')'
