import {cp,mkdir,stat} from 'node:fs/promises';
for(const file of ['index.html','index.js','index.wasm','index.pck']) {
 if((await stat(new URL('../web/'+file,import.meta.url))).size===0) throw new Error('Empty Web export: '+file);
}
await mkdir(new URL('../dist/',import.meta.url),{recursive:true});
await cp(new URL('../web/',import.meta.url),new URL('../dist/',import.meta.url),{recursive:true});
console.log('Godot Web release copied to dist');
