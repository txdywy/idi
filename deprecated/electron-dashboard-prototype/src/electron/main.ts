import { app, BrowserWindow } from 'electron';
import path from 'node:path';

const isDev = !app.isPackaged;

function createWindow() {
  const window = new BrowserWindow({
    width: 1320,
    height: 860,
    minWidth: 1040,
    minHeight: 720,
    title: 'idi',
    backgroundColor: '#090a0d',
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 18, y: 18 }
  });

  if (isDev) {
    window.loadURL('http://127.0.0.1:5173');
    return;
  }

  window.loadFile(path.join(__dirname, '../dist/index.html'));
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
