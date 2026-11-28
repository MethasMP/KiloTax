const fs = require('node:fs');
const path = require('node:path');
const sharp = require(require.resolve('sharp', {paths: [process.cwd(), path.join(require('node:os').homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules')]}));
const out = path.resolve('assets/brand/folio');
fs.mkdirSync(out, {recursive:true});
const orange = '#E74716', ink = '#351329';
// Three folded planes, with consistent six-unit channels at the two folds.
const planes = `<path d="M43 9Q43 5 48 7L103 27Q109 29 109 35V91L87 99V47L43 31Z"/><path d="M26 40Q26 36 31 38L76 54Q81 56 81 61V106L59 114V73L26 61Z"/><path d="M9 71Q9 67 14 69L48 81Q53 83 53 88V121L13 106Q9 104 9 100Z"/>`;
const svg = (body, size=128) => `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 128 128">${body}</svg>`;
const mark = color => `<g fill="${color}">${planes}</g>`;
const master = svg(`<rect width="128" height="128" fill="${orange}"/><g transform="translate(18 12) scale(.76)">${mark('#FFFFFF')}</g>`,1024);
const files = {'folio-mark.svg':svg(mark(orange)), 'folio-mono.svg':svg(mark(ink)), 'folio-app-icon.svg':master};
for(const [name,data] of Object.entries(files)) fs.writeFileSync(path.join(out,name),data);
(async()=>{
 await sharp(Buffer.from(master)).png().toFile('assets/icon_master.png');
 const ios='ios/Runner/Assets.xcassets/AppIcon.appiconset';
 const contents=JSON.parse(fs.readFileSync(path.join(ios,'Contents.json')));
 const sizes=new Map(contents.images.filter(i=>i.filename).map(i=>[i.filename,Math.round(parseFloat(i.size)*parseFloat(i.scale))]));
 for(const [name,size] of sizes) await sharp(Buffer.from(master)).resize(size,size).removeAlpha().png().toFile(path.join(ios,name));
 for(const [density,size] of Object.entries({mdpi:48,hdpi:72,xhdpi:96,xxhdpi:144,xxxhdpi:192})){
   const tile=svg(`<rect width="128" height="128" rx="28" fill="${orange}"/><g transform="translate(18 12) scale(.76)">${mark('#FFFFFF')}</g>`,1024);
   await sharp(Buffer.from(tile)).resize(size,size).png().toFile(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`);
 }
 // Native launch artwork uses a transparent mark on the app's warm canvas.
 const launchDir='ios/Runner/Assets.xcassets/LaunchImage.imageset';
 for(const scale of [1,2,3]) {
   const filename=scale===1?'LaunchImage.png':`LaunchImage@${scale}x.png`;
   await sharp(Buffer.from(svg(mark(orange),80*scale))).png().toFile(path.join(launchDir,filename));
 }
 const androidPaths=[...planes.matchAll(/d="([^"]+)"/g)].map(m=>`<path android:fillColor="${orange}" android:pathData="${m[1]}"/>`).join('');
 fs.writeFileSync('android/app/src/main/res/drawable/folio_splash.xml',`<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="80dp" android:height="80dp" android:viewportWidth="128" android:viewportHeight="128">${androidPaths}</vector>`);
 // Android 12 masks the central two-thirds of its splash icon.
 fs.writeFileSync('android/app/src/main/res/drawable/folio_splash_system.xml',`<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="288dp" android:height="288dp" android:viewportWidth="384" android:viewportHeight="384"><group android:translateX="128" android:translateY="128">${androidPaths}</group></vector>`);
 const whitePaths=androidPaths.replaceAll(orange,'#FFFFFF');
 fs.writeFileSync('android/app/src/main/res/drawable/ic_stat_kiloclaim.xml',`<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="128" android:viewportHeight="128">${whitePaths}</vector>`);
 fs.writeFileSync('android/app/src/main/res/drawable/folio_launcher_foreground.xml',`<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="192" android:viewportHeight="192"><group android:translateX="32" android:translateY="32">${whitePaths}</group></vector>`);
 const preview=`<svg xmlns="http://www.w3.org/2000/svg" width="960" height="360" viewBox="0 0 960 360"><rect width="960" height="360" fill="#FAF9F6"/><svg x="64" y="76" width="142" height="142" viewBox="0 0 128 128">${mark(orange)}</svg><text x="230" y="176" fill="${ink}" font-family="Inter,Helvetica,Arial,sans-serif" font-size="76" font-weight="700" letter-spacing="-3">KiloClaim</text><svg x="720" y="88" width="128" height="128" viewBox="0 0 128 128"><rect width="128" height="128" rx="28" fill="${orange}"/><g transform="translate(18 12) scale(.76)">${mark('#FFFFFF')}</g></svg><text x="74" y="286" fill="#52525B" font-family="Helvetica,Arial,sans-serif" font-size="18">FOLIO / Refined identity</text></svg>`;
 fs.writeFileSync(path.join(out,'folio-preview.svg'),preview);
 await sharp(Buffer.from(preview)).png().toFile(path.join(out,'folio-preview.png'));
 console.log(`Folio assets + ${sizes.size} iOS and 5 Android icons exported.`);
})();
