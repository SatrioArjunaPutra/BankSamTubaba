// Usage: node tool/extract_reference_font.cjs "path/to/Bank Sampah UI.html"
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const source = fs.readFileSync(process.argv[2], 'utf8');
const manifest = (html) => JSON.parse(html.match(/<script type="__bundler\/manifest">([\s\S]*?)<\/script>/)[1]);
const unpack = (entry) => entry.compressed ? zlib.gunzipSync(Buffer.from(entry.data, 'base64')) : Buffer.from(entry.data, 'base64');
const app = unpack(Object.values(manifest(source))[8]).toString('utf8');
const font = manifest(app)['5050b033-5a2b-4681-a53e-69154606d9f2'];
if (font.mime !== 'font/woff2') throw new Error('Expected embedded Plus Jakarta Sans Latin font');
const target = path.resolve(__dirname, '../assets/fonts');
fs.mkdirSync(target, { recursive: true });
fs.writeFileSync(path.join(target, 'PlusJakartaSans-Latin.woff2'), unpack(font));
fs.writeFileSync(path.join(target, 'LICENSE.txt'), source.match(/<!--([\s\S]*?)-->/)[1].trim() + '\n');
console.log('Extracted Plus Jakarta Sans Latin and original license.');
