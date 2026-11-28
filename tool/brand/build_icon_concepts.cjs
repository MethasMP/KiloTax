// Editable vector concepts; does not replace shipping launcher assets.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require(require.resolve('sharp', { paths: [process.cwd(), path.join(require('node:os').homedir(), '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules')] }));
const out = path.resolve('assets/brand/explorations');
const ink = '#18181B', cream = '#FAF9F6', orange = '#EA580C';
const marks = [
  `<path d="M326 270V754 M694 270L432 512L694 754" fill="none" stroke="${cream}" stroke-width="98" stroke-linecap="round" stroke-linejoin="round"/><circle cx="694" cy="270" r="49" fill="${orange}"/>`,
  `<rect x="270" y="230" width="484" height="564" rx="66" fill="${cream}"/><path d="M442 794C442 676 668 654 668 546S378 482 378 370" fill="none" stroke="${ink}" stroke-width="96"/><path d="M374 312H548" stroke="${orange}" stroke-width="32" stroke-linecap="round"/>`,
  `<path d="M300 710V504Q300 434 370 434H580Q650 434 650 364V326" fill="none" stroke="${cream}" stroke-width="82" stroke-linecap="round" stroke-linejoin="round"/><circle cx="300" cy="710" r="42" fill="${orange}"/><circle cx="650" cy="286" r="128" fill="${cream}"/><path d="M592 284L635 327L714 238" fill="none" stroke="${ink}" stroke-width="39" stroke-linecap="round" stroke-linejoin="round"/>`,
];
const names=['01-k-route','02-route-record','03-reviewed-trip'];
const svg = (i,bg=ink,mark=marks[i]) => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="${bg}"/>${mark}</svg>`;
const icon = (i,x,y,size,bg=ink,mark=marks[i]) => `<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 1024 1024"><defs><clipPath id="clip-${i}-${x}-${y}-${size}"><rect width="1024" height="1024" rx="220"/></clipPath></defs><g clip-path="url(#clip-${i}-${x}-${y}-${size})"><rect width="1024" height="1024" fill="${bg}"/>${mark}</g></svg>`;
const txt=(x,y,t,size=18,color=ink,weight=400)=>`<text x="${x}" y="${y}" font-family="Helvetica,Arial,sans-serif" font-size="${size}" font-weight="${weight}" fill="${color}">${t}</text>`;
let board=`<svg xmlns="http://www.w3.org/2000/svg" width="1560" height="1420" viewBox="0 0 1560 1420"><rect width="1560" height="1420" fill="${cream}"/>`;
board+=txt(64,68,'KiloClaim / Icon directions',38,ink,700)+txt(64,104,'Vector concepts · same palette · compare the silhouette at actual launcher sizes',19,'#52525B');
const titles=['01  K / route','02  Route / record','03  Reviewed trip'];
const subs=['Brand initial with a route endpoint','A record shaped by the journey','A route ending in a reviewed record'];
for(let i=0;i<3;i++){
 const x=64+i*500;
 board+=txt(x,166,titles[i],25,ink,700)+txt(x,196,subs[i],17,'#52525B');
 board+=icon(i,x+62,226,320);
 board+=txt(x,586,i===0?'Recommended direction':'Alternative direction',18,i===0?'#C2410C':'#52525B',600);
 board+=txt(x,626,'60 px',14,'#71717A')+icon(i,x,644,60)+txt(x+102,626,'40 px',14,'#71717A')+icon(i,x+102,654,40)+txt(x+184,626,'29 px',14,'#71717A')+icon(i,x+184,660,29);
 // Deliberately schematic home-screen context, not an OS screenshot.
 board+=`<rect x="${x}" y="746" width="430" height="408" rx="30" fill="#D9D1C4"/>`;
 board+=txt(x+24,786,'HOME SCREEN / SIZE CONTEXT',13,'#52525B',600);
 const colors=['#8D9B8E','#A8A1B8','#B3977B','#718897','#969696','#B6A282'];
 for(let j=0;j<8;j++){
   const xx=x+30+(j%4)*98, yy=816+Math.floor(j/4)*112;
   if(j===2){board+=icon(i,xx,yy,60)+txt(xx+6,yy+82,'KiloClaim',13,ink,500);}
   else {board+=`<rect x="${xx}" y="${yy}" width="60" height="60" rx="14" fill="${colors[j%6]}"/><circle cx="${xx+30}" cy="${yy+30}" r="12" fill="#FFFFFF" opacity="0.7"/>`;}
 }
 board+=txt(x+24,1125,'Schematic context · 60 px icons',14,'#52525B');
}
const orangeMark=marks[0].replaceAll(orange,ink);
board+=txt(64,1220,'Colour check / same K mark',23,ink,700)+icon(0,64,1244,92)+icon(0,180,1244,92,'#C2410C',orangeMark)+txt(300,1280,'Obsidian is the primary recommendation.',19,ink,600)+txt(300,1310,'Orange is a visibility alternative; retain the same silhouette.',17,'#52525B');
board+=txt(64,1384,'Concept review only. Current iOS and Android launcher assets are unchanged.',15,'#71717A')+'</svg>';
(async()=>{
 fs.mkdirSync(out,{recursive:true});
 for(let i=0;i<3;i++){fs.writeFileSync(path.join(out,names[i]+'.svg'),svg(i));await sharp(Buffer.from(svg(i))).png().toFile(path.join(out,names[i]+'.png'));}
 fs.writeFileSync(path.join(out,'icon-comparison.svg'),board);
 await sharp(Buffer.from(board)).png().toFile(path.join(out,'icon-comparison.png'));
 console.log(out);
})();
