import { defineConfig } from 'vitepress'
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'
import { mathjaxPlugin } from './mathjax-plugin'
import { juliaReplTransformer } from './julia-repl-transformer'
import footnote from "markdown-it-footnote";
import path from 'path'

const mathjax = mathjaxPlugin()

function getBaseRepository(base: string): string {
  if (!base || base === '/') return '/';
  const parts = base.split('/').filter(Boolean);
  return parts.length > 0 ? `/${parts[0]}/` : '/';
}

const baseTemp = {
  base: '/chairmarks.lilithhafner.com/dev/',// TODO: replace this in makedocs!
}

const navTemp = {
  nav: [{ text: 'Home', link: '/index' },
{ text: 'Why use Chairmarks?', link: '/why' },
{ text: 'Tutorial', link: '/tutorial' },
{ text: 'How To',  items: [
{text: 'migrate from BenchmarkTools', link: '/migration'},
{text: 'install Chairmarks ergonomically', link: '/autoload'},
{text: 'perform automated regression testing on a package', link: '/regressions'}
] },
{ text: 'Reference', link: '/reference' },
{ text: 'Explanations', link: '/explanations' }]
,
}

const nav = [
  ...navTemp.nav,
  {
    component: 'VersionPicker'
  }
]

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: '/chairmarks.lilithhafner.com/dev/',// TODO: replace this in makedocs!
  title: 'Chairmarks.jl',
  description: 'Documentation for Chairmarks.jl',
  lastUpdated: true,
  cleanUrls: true,
  outDir: '../1', // This is required for MarkdownVitepress to work correctly...
  head: [
    
    ['script', {src: `${getBaseRepository(baseTemp.base)}versions.js`}],
    // ['script', {src: '/versions.js'], for custom domains, I guess if deploy_url is available.
    ['script', {src: `${baseTemp.base}siteinfo.js`}],
    ['meta', { name: 'robots', content: 'noindex, nofollow' }],
  ],
  
  markdown: {
    codeTransformers: [juliaReplTransformer()],
    config(md) {
      md.use(tabsMarkdownPlugin);
      md.use(footnote);
      mathjax.markdownConfig(md);
    },
    theme: {
      light: "github-light",
      dark: "github-dark"
    },
  },
  vite: {
    plugins: [
      mathjax.vitePlugin,
    ],
    define: {
      __DEPLOY_ABSPATH__: JSON.stringify('/chairmarks.lilithhafner.com'),
    },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '../components')
      }
    },
    optimizeDeps: {
      exclude: [ 
        '@nolebase/vitepress-plugin-enhanced-readabilities/client',
        'vitepress',
        '@nolebase/ui',
      ], 
    }, 
    ssr: { 
      noExternal: [ 
        // If there are other packages that need to be processed by Vite, you can add them here.
        '@nolebase/vitepress-plugin-enhanced-readabilities',
        '@nolebase/ui',
      ], 
    },
  },
  themeConfig: {
    outline: 'deep',
    
    search: {
      provider: 'local',
      options: {
        detailedView: true
      }
    },
    nav,
    sidebar: [{ text: 'Home', link: '/index' },
{ text: 'Why use Chairmarks?', link: '/why' },
{ text: 'Tutorial', link: '/tutorial' },
{ text: 'How To', collapsed: false, items: [
{text: 'migrate from BenchmarkTools', link: '/migration'},
{text: 'install Chairmarks ergonomically', link: '/autoload'},
{text: 'perform automated regression testing on a package', link: '/regressions'}
] },
{ text: 'Reference', link: '/reference' },
{ text: 'Explanations', link: '/explanations' }]
,
    sidebarDrawer: false,
    editLink: { pattern: "https://https://github.com/LilithHafner/Chairmarks.jl/edit/main/docs/src/:path" },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/LilithHafner/Chairmarks.jl' }
    ],
    footer: {
      message: 'Made with <a href="https://luxdl.github.io/DocumenterVitepress.jl/dev/" target="_blank"><strong>DocumenterVitepress.jl</strong></a><br>',
      copyright: `© Copyright ${new Date().getUTCFullYear()}.`
    }
  }
})
