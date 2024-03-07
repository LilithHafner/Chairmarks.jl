import { defineConfig } from 'vitepress'
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'
import mathjax3 from "markdown-it-mathjax3";
import footnote from "markdown-it-footnote";

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: '/',// TODO: replace this in makedocs!
  title: 'Chairmarks.jl',
  description: "A VitePress Site",
  lastUpdated: true,
  cleanUrls: true,
  outDir: '../final_site', // This is required for MarkdownVitepress to work correctly...
  
  ignoreDeadLinks: true,

  markdown: {
    math: true,
    config(md) {
      md.use(tabsMarkdownPlugin),
      md.use(mathjax3),
      md.use(footnote)
    },
    theme: {
      light: "github-light",
      dark: "github-dark"}
  },
  themeConfig: {
    outline: 'deep',
    
    search: {
      provider: 'local',
      options: {
        detailedView: true
      }
    },
    nav: [
{ text: 'Home', link: '/index' },
{ text: 'Why use Chairmarks?', link: '/why' },
{ text: 'Tutorial', link: '/tutorial' },
{ text: 'How To', collapsed: false, items: [
{ text: 'migrate from BenchmarkTools', link: '/migration' },
{ text: 'install Chairmarks ergonomically', link: '/autoload' },
{ text: 'perform automated regression testing on a package', link: '/regressions' }]
 },
{ text: 'Reference', link: '/reference' },
{ text: 'Explanations', link: '/explanations' }
]
,
    sidebar: [
{ text: 'Home', link: '/index' },
{ text: 'Why use Chairmarks?', link: '/why' },
{ text: 'Tutorial', link: '/tutorial' },
{ text: 'How To', collapsed: false, items: [
{ text: 'migrate from BenchmarkTools', link: '/migration' },
{ text: 'install Chairmarks ergonomically', link: '/autoload' },
{ text: 'perform automated regression testing on a package', link: '/regressions' }]
 },
{ text: 'Reference', link: '/reference' },
{ text: 'Explanations', link: '/explanations' }
]
,
    editLink: { pattern: "https://github.com/LilithHafner/Chairmarks.jl/edit/main/docs/src/:path" },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/LilithHafner/Chairmarks.jl' }
    ],
    footer: {
      message: 'Made with <a href="https://documenter.juliadocs.org/stable/" target="_blank"><strong>Documenter.jl</strong></a> & <a href="https://vitepress.dev" target="_blank"><strong>VitePress</strong></a> <br>',
      copyright: `© Copyright ${new Date().getUTCFullYear()}.`
    }
  }
})
