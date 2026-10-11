import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import ts from 'typescript';
// Run the real configuration function under the Pages and custom-domain bases.
const configSource=readFileSync('src/config.ts','utf8');
for (const base of ['/ritualone/','/']) {
 const code=ts.transpileModule(configSource.replace('import.meta.env.BASE_URL',JSON.stringify(base)).replaceAll('import.meta.env.VITE_SUPABASE_URL',"''").replaceAll('import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY',"''"),{compilerOptions:{module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}}).outputText;
 const config=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
 assert.equal(config.authRedirect('https://raghav95nanda.github.io'),'https://raghav95nanda.github.io'+base);
 assert(config.supabaseConfig.key.startsWith('sb_publishable_'));
}
const app=readFileSync('src/App.tsx','utf8');
assert(!app.includes('/api/config'));
assert(app.includes('redirectTo:authRedirect(window.location.origin)'));
assert(app.includes('emailRedirectTo:authRedirect(window.location.origin)'));
assert(!app.includes('src="/ritual-one'));
if (existsSync('docs/index.html')) {
 const html=readFileSync('docs/index.html','utf8');
 for(const [,url] of html.matchAll(/(?:src|href)="(\/[^\"]+)"/g)) {
  assert(url.startsWith('/ritualone/'),url);
  assert(existsSync('docs/'+url.slice('/ritualone/'.length)),url);
 }
 assert(existsSync('docs/.nojekyll'));
}
console.log('Pages base paths, assets, direct Supabase configuration and auth redirect checks passed.');
