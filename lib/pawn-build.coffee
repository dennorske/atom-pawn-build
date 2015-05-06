{CompositeDisposable} = require 'atom'
{MessagePanelView, PlainMessageView, LineMessageView} = require 'atom-message-panel'
path = require 'path'
child_process = require 'child_process'

module.exports = PawnBuild =
  messages: null
  subscriptions: null

  config:
    pawnExecutablePath:
      title: 'Path to pawncc executable'
      type: 'string'
      default: 'C:\\pawn\\pawncc.exe'
    pawnOptions:
      title: 'Pawn options'
      type: 'array'
      default: ['-d1', '-(', '-;']
      items:
        type: 'string'

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'pawn-build:build': => @build()

  deactivate: ->
    @messages?.detatch()
    @subscriptions.dispose()
    @pawnBuildView.destroy()

  serialize: -> undefined

  createOutputPanel: ->
    unless @messages?
      @messages = new MessagePanelView
        title: 'Pawn output'
    @messages.attach()
    @messages.clear()
    return @messages

  build: ->
    filepath = atom.workspace.getActiveTextEditor()?.getPath()

    # ignore command if current file is not saved, or is not a .pwn file
    return unless filepath? and path.extname(filepath) == '.pwn'

    # prepare command
    cmd = atom.config.get('pawn-build.pawnExecutablePath')

    # prepare arguments
    args = atom.config.get('pawn-build.pawnOptions')
    args.push path.basename filepath

    # run pawn
    process = child_process.spawn cmd, args,
      cwd: path.dirname filepath

    procout = []
    hasError = false

    process.stdout.on 'data', (data) ->
      procout.push data.toString()

    process.stderr.on 'data', (data) ->
      procout.push data.toString()

    process.on 'error', (error) =>
      hasError = true
      output = @createOutputPanel()
      output.add new PlainMessageView
        message: 'Could not run pawncc: ' + error.message

    process.on 'close', (exitCode, signal) =>
      return if hasError

      data = procout.join('')
      output = @createOutputPanel()

      if data
        lines = data.split('\n')
        for line in lines
          output.add new PlainMessageView
            message: line
      else
        output.add new PlainMessageView
          message: 'Could not run pawncc: Unknown error (' + exitCode + ')'
