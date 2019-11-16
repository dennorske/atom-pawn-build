/* eslint-env node */
/* globals atom:false */

const { CompositeDisposable } = require('atom');
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

    // use wine
    pawnUseWine: {
      title: 'Run in Wine (for Linux/OS X. Wine package required.)',
      type: 'boolean',
      default: false,
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

  createOutputPanel() {
    // create output panel (or return if already exists)
    if(this.messages != null) {
      this.messages.clear();
    } else {
      this.messages = new MessagePanelView({
        title: 'Pawn output',
      });
      this.messages.attach();
    }

    this.messages.clear();
    return this.messages;
  },

  build() {
    // get current editor
    const editor = atom.workspace.getActiveTextEditor();
    const startTime = Date.now() / 1000;
    // get path of currently open file
    const filepath = editor != null ? editor.getPath() : null;

    // only continue if file is a .pwn or .inc file
    if(filepath == null || path.extname(filepath) !== '.pwn' || path.extname(filepath) !== '.inc')
      return;

    // also save the current file, so the current buffer is includeda



    editor.save();


    // prepare command and arguments from package settigns
    let cmd = atom.config.get('pawn-build.pawnExecutablePath');
    let args = atom.config.get('pawn-build.pawnOptions');
    args.push(path.basename(filepath));

    // if "Use wine" is checked, then use "wine" as command instead (with the original
    // command as the "program path" given to wine)
    if(atom.config.get('pawn-build.pawnUseWine')) {
      args.unshift(cmd);
      cmd = 'wine';
    }

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
      this.messages.setTitle('Pawncc encountered error(s)');
      // show message if pawncc failed to run (for instance due to invalid path)
      hasError = true;
    });

    process.on('close', (exitCode, signal) => {
      if(hasError) return;
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
      }
    });
  },
};
