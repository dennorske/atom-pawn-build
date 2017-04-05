/* eslint-env node */
/* globals atom:false */

const { CompositeDisposable } = require('atom');
const { MessagePanelView, PlainMessageView } = require('atom-message-panel');
const path = require('path');
const child_process = require('child_process');

module.exports = {
  messages: null,
  subscriptions: null,

  // configuration options
  config: {
    // path to pawncc executable
    pawnExecutablePath: {
      title: 'Path to pawncc executable',
      type: 'string',
      default: 'C:\\pawn\\pawncc.exe',
    },

    // list of pawncc options (passed before filename)
    pawnOptions: {
      title: 'Pawn options',
      type: 'array',
      default: ['-d1', '-(', '-;'],
      items: {
        type: 'string',
      },
    },

    // should jump to error?
    shouldJumpToError: {
      title: 'Jump to first error?',
      type: 'boolean',
      default: false,
    },
  },

  activate(state) {
    // activate package
    this.subscriptions = new CompositeDisposable();
    this.subscriptions.add(atom.commands.add('atom-workspace', {
      'pawn-build:build': () => this.build(),
    }));
  },

  deactivate() {
    // deactivate package
    if(this.messages != null)
      this.messages.detatch();
    this.subscriptions.dispose();
    this.pawnBuildView.destroy();
  },

  serialize() { },

  createOutputPanel() {
    // create output panel (or return if already exists)
    if(this.message == null) {
      this.messages = new MessagePanelView({
        title: 'Pawn output',
      });
    }

    this.messages.attach();
    this.messages.clear();
    return this.messages;
  },

  build() {
    // get current editor
    const editor = atom.workspace.getActiveTextEditor();

    // get path of currently open file
    const filepath = editor != null ? editor.getPath() : null;

    // only continue if file is a .pwn file
    if(filepath == null || path.extname(filepath) !== '.pwn')
      return;

    // also save the current file, so the current buffer is included
    editor.save();

    // prepare command and arguments from package settigns
    const cmd = atom.config.get('pawn-build.pawnExecutablePath');
    const args = atom.config.get('pawn-build.pawnOptions');
    args.push(path.basename, filepath);

    // run pawncc command
    const process = child_process.spawn(cmd, args, {
      cwd: path.dirname(filepath), // run in the current file's directory
    });

    const procout = [];      // store output from pawncc
    let hasError = false;  // store error status

    // read output from pawncc
    process.stdout.on('data', (data) =>
      procout.push(data.toString())
    );
    process.stderr.on('data', (data) =>
      procout.push(data.toString())
    );

    process.on('error', (error) => {
      // show message if pawncc failed to run (for instance due to invalid path)
      hasError = true;
      const output = this.createOutputPanel();
      output.add(new PlainMessageView({
        message: 'Could not run pawncc: ' + error.message,
      }));
    });

    process.on('close', (exitCode, signal) => {
      if(hasError) return;

      const data = procout.join('');
      const output = this.createOutputPanel();

      if(data) {
        // jump to the first error line
        if(atom.config.get('build-pawn.shouldJumpToError')) {
          const match = data.match(/\(([1-9][0-9]*)\)/);
          if(match != null) {
            const row = parseInt(match[1]) - 1;
            if(row < editor.getLineCount())
              editor.setCursorBufferPosition([row, 0]);
          }
        }

        // show output of pawncc
        const lines = data.split('\n');
        for(let line of lines) {
          output.add(new PlainMessageView({
            message: line,
          }));
        }
      } else {
        // show error message if pawncc returned no output (unknown error)
        output.add(new PlainMessageView({
          message: 'Could not run pawncc: Unknown error (' + exitCode + ')',
        }));
      }
    });
  },
};
