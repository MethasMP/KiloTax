// Assemble actual Flutter widget renders into a one-shot review preview.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require(require.resolve('sharp', {paths: [process.cwd(), path.join(require('node:os').homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules')]}));
const directory = path.resolve('tool/design_audit/folio_motion_captures');
(async () => {
  const frames = [];
  for (let index=0;index<=20;index++) {
    frames.push(await sharp(path.join(directory,`frame_${index}.png`))
      .extract({left:16,top:24,width:240,height:80})
      .resize(720,240).ensureAlpha().raw().toBuffer());
  }
  await sharp(Buffer.concat(frames), {raw: {
    width:720,height:240*frames.length,channels:4,pageHeight:240,
  }}).gif({loop:1,delay:frames.map((_,i)=>i===frames.length-1?1600:40),dither:0})
    .toFile(path.join(directory,'folio-welcome-once.gif'));
  console.log('One-shot widget-render preview: '+path.join(directory,'folio-welcome-once.gif'));
})();
