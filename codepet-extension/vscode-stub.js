module.exports = {
  Uri: { joinPath: () => ({ fsPath: '/' }), parse: (s) => ({ fsPath: s }) },
  Disposable: { from: () => ({ dispose() {} }) },
  EventEmitter: class { constructor(){ this.event = () => ({ dispose(){} }); } fire(){} dispose(){} },
  commands: { executeCommand: () => Promise.resolve() },
  window: { showInformationMessage:()=>Promise.resolve(), showWarningMessage:()=>Promise.resolve(), createOutputChannel: () => ({ appendLine(){}, show(){} }) },
  workspace: { getConfiguration: () => ({ get: () => undefined }) },
  env: { language: 'en' },
};
