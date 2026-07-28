// Copia l'unico index.html del repo (radice) dentro www/, così l'app iOS
// e il sito pubblicato su GitHub Pages restano sempre lo stesso file:
// nessuna versione separata da tenere allineata a mano.
const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', '..', 'index.html');
const destDir = path.join(__dirname, '..', 'www');
const dest = path.join(destDir, 'index.html');

if (!fs.existsSync(destDir)) fs.mkdirSync(destDir, { recursive: true });
fs.copyFileSync(src, dest);
console.log(`Copiato ${src} -> ${dest}`);
