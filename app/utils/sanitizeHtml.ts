import sanitizeHtml from 'sanitize-html'

const ARTICLE_SANITIZE_OPTIONS: sanitizeHtml.IOptions = {
  allowedTags: [
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'p', 'span', 'b', 'strong', 'i', 'em', 'u', 's', 'strike', 'del',
    'code', 'pre', 'blockquote', 'hr', 'br',
    'ul', 'ol', 'li',
    'a', 'img',
    'table', 'thead', 'tbody', 'tr', 'th', 'td',
  ],
  allowedAttributes: {
    a: ['href', 'name', 'target', 'rel'],
    img: ['src', 'alt', 'title', 'width', 'height'],
    '*': ['class', 'dir'],
  },
  allowedSchemes: ['http', 'https', 'mailto'],
  allowedSchemesAppliedTo: ['href', 'src'],
  transformTags: {
    a: sanitizeHtml.simpleTransform('a', {
      rel: 'noopener noreferrer',
      target: '_blank',
    }),
  },
}

/**
 * Sanitizes rich-text HTML before rendering with v-html.
 * Strips script tags, iframes, inline event handlers, javascript: URIs, etc.
 */
export function sanitizeArticleHtml(dirtyHtml?: string | null): string {
  if (!dirtyHtml || typeof dirtyHtml !== 'string') return ''
  return sanitizeHtml(dirtyHtml, ARTICLE_SANITIZE_OPTIONS)
}
