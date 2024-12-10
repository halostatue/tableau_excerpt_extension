# HTML &amp; Styling Guide

TableauExcerptExtension replaces HTML tags containing specific attributes with
rendered social profile links based on site extension configuration and content
frontmatter. The generated HTML is semantic and has configurable semantic CSS
class names for ease in styling.

## Social Block Structure

The social block is built around the description [list (`dl`)][dl],
[term (`dt`)][dt], and [details (`dd`)][dd] elements. Given
`<dl social-block></dl>` TableauExcerptExtension replaces it with a full
description list from the resolved social platform accounts.

- `<dl class="social-block">`
- For each platform:
  - `<dt class="social-platform-label social-platform-{platform}">` with the
    platform label
  - For each account:
    - `<dd class="social-links social-platform-{platform}">` with `<a>` tags for
      each account
      - `<a class="social-link social-platform-{platform}">` with the default
        link text for the account

[dl]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dl
[dt]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dt
[dd]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dd

```html
<dl class="social-block">
  <dt class="social-platform-label social-platform-github">GitHub</dt>
  <dd class="social-links social-platform-github">
    <a
      href="https://github.com/username"
      rel="noopener noreferrer nofollow"
      class="social-link social-platform-github"
    >
      username
    </a>
    <a
      href="https://github.com/work-account"
      rel="noopener noreferrer nofollow"
      class="social-link social-platform-github"
    >
      work-account
    </a>
  </dd>
  <dt class="social-platform-label social-platform-mastodon">Mastodon</dt>
  <dd class="social-links social-platform-mastodon">
    <a
      href="https://mastodon.social/@user"
      rel="noopener noreferrer nofollow"
      class="social-link social-platform-mastodon"
    >
      @user@mastodon.social
    </a>
  </dd>
</dl>
```

**Notes**:

- Child elements or text nodes present in `<dl social-block></dl>` are
  discarded.

- Except for `rel` and `class`, all attributes on `<dl social-block></dl>` are
  passed through to the resulting `<dl>` structure unmodified.

- `class` attribute values are passed through, but `social-block` is added to
  the list of class attributes. `<dl social-block class="me"></dl>` would result
  in `<dl … class="me social-block"></dl>`.

- `rel` attributes are removed, but applied to _each_ account's `<a>` element,
  along with `noreferrer`, `noopener`, and `nofollow`.
  `<dl social-block rel="me"></dl>` would result in each account looking like
  `<a rel="me noopener noreferrer nofollow" …>…</a>`.

## Social Link Structure

The social link is an inline tag built around the [anchor (`<a>`)][a] element.

```html
<a
  href="https://github.com/username"
  rel="noopener noreferrer nofollow"
  class="social-link social-platform-github"
>
  Custom Link Text
</a>
```

**Notes**:

- Child elements or text nodes present in `<a social-{platform}></a>` will be
  preserved as the child elements of the replaced `<a>` element. If there are no
  child nodes, the account's default link text will be used.

- Except for `href`, `rel`, and `class`, all attributes on social links are
  passed through to the resulting `<a>` element unmodified.

- `class` attribute values are passed through, but `social-link` and
  `social-platform-{platform}` is added to the list of class attributes.
  `<a social-link-github class="me"></a>` would result in
  `<a class="me social-link social-platform" …>…</a>`.

- `rel` attributes are passed through, but `noreferrer`, `noopener`, and
  `nofollow` will be added so that `<a social-link-github rel="me"></a>` would
  result in `<a rel="me noopener noreferrer nofollow" …>…</a>`.

- `href` attributes will be discarded and replaced with the computed account
  URL.

[a]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/a

## CSS Classes

The CSS prefix for each of the CSS classes is configurable site-wide with the
extension's `:css_prefix` configuration option, which defaults to `social`.
Given the general opinion on most social networks these days, it might be more
accurate to change the prefix

```elixir
config :tableau, TableauExcerptExtension,
  css_prefix: "antisocial"
```

| CSS class                                    | Tags                 |
| -------------------------------------------- | -------------------- |
| `social-block`                               | `<dl>`               |
| `social-platform-label`                      | `<dt>`               |
| `social-links`                               | `<dd>`               |
| `social-link`                                | `<a>`                |
| <code>social-platform-<em>{name}</em></code> | `<dt>`,`<dd>`, `<a>` |

Each platform gets is own CSS class:

- `social-platform-github`
- `social-platform-mastodon`
- `social-platform-stack-overflow`
- `social-platform-reddit`

### Custom Properties

When building styling CSS, it is recommended to use custom properties for
theming purposes.

```css
:root {
  /* Block spacing */
  --social-block-margin: 1rem 0;
  --social-column-gap: 1rem;
  --social-link-gap: 0.25rem;
  --social-link-spacing: 1rem;

  /* Typography */
  --social-line-height: 1.6;
  --social-label-weight: 600;

  /* Colors */
  --social-link-color: #0066cc;
  --social-link-hover-color: #004499;
  --social-error-color: #cc0000;
  --social-border-color: #e0e0e0;

  /* Transitions */
  --social-transition: 0.2s ease;
}

.social-block {
  margin: var(--social-block-margin);
  line-height: var(--social-line-height);
  gap: 0 var(--social-column-gap);
}

.social-block dt {
  font-weight: var(--social-label-weight);
}

.social-links {
  gap: var(--social-link-gap);
}

.social-link {
  color: var(--social-link-color);
  transition: color var(--social-transition);
}

.social-link:hover {
  color: var(--social-link-hover-color);
}
```

### Styling Approaches

#### Basic Table Layout

A clean table-style layout using CSS Grid.

```css
.social-block {
  margin: 1rem 0;
  line-height: 1.6;
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 0 1rem;
  align-items: baseline;
}

.social-block dt {
  font-weight: 600;
  grid-column: 1;
  margin: 0;
}

.social-block dd {
  grid-column: 2;
  margin: 0;
}

.social-links {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.social-link {
  text-decoration: none;
  color: #0066cc;
  transition: color 0.2s ease;
}

.social-link:hover {
  color: #004499;
  text-decoration: underline;
}
```

#### Generous Table Layout

Extends the basic layout with more spacing and visual separators:

```css
/* Use the basic table layout above, then add: */

.social-block {
  margin: 1.5rem 0;
  gap: 0 1.5rem;
}

.social-links {
  gap: 0.5rem;
  padding: 0.25rem 0;
}

.social-block dt:not(:first-child) {
  margin-top: 1rem;
  padding-top: 0.5rem;
  border-top: 1px solid #e0e0e0;
}
```

#### Flow Layout

Horizontal layout where multiple accounts appear on the same line:

```css
/* Use the basic table layout above, then override: */

.social-block .social-links {
  flex-direction: row;
  flex-wrap: wrap;
  gap: 0.25rem 1rem;
}

.social-link {
  white-space: nowrap;
}
```

### Further Ideas

#### Icon-Based Links

Platform links could be prefixed with icons for each platform, either with
emoji:

```css
.social-platform-github .social-link::before {
  content: "🐙 ";
}
```

Inline SVG:

```css
.social-platform-github .social-link::before {
  content: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Cpath d='M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z'/%3E%3C/svg%3E");
  width: 16px;
  height: 16px;
  margin-right: 0.5rem;
}
```

Or external SVG:

```css
.social-platform-github .social-link::before {
  content: "";
  background-image: url("/icons/github.svg");
  background-size: 16px 16px;
  width: 16px;
  height: 16px;
  display: inline-block;
  margin-right: 0.5rem;
}
```

#### Button-Style Links

Style links as buttons:

```css
.social-link {
  display: inline-block;
  padding: 0.5rem 1rem;
  background: var(--button-bg, #f0f0f0);
  border: 1px solid var(--button-border, #ccc);
  border-radius: 4px;
  text-decoration: none;
  color: var(--button-text, #333);
  transition: all 0.2s ease;
}

.social-link:hover {
  background: var(--button-hover-bg, #e0e0e0);
  transform: translateY(-1px);
}
```

#### Platform-Specific Colors

Use brand colors for different platforms:

```css
.social-platform-github .social-link {
  color: #333;
  border-color: #333;
}

.social-platform-mastodon .social-link {
  color: #6364ff;
  border-color: #6364ff;
}

.social-platform-twitter .social-link {
  color: #1da1f2;
  border-color: #1da1f2;
}
```

#### Responsive Design

Make social blocks responsive:

```css
.social-block {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 0 1rem;
}

@media (max-width: 768px) {
  .social-block {
    grid-template-columns: 1fr;
    gap: 0.5rem 0;
  }

  .social-block dt,
  .social-block dd {
    grid-column: 1;
  }

  .social-block dt {
    font-size: 0.9rem;
    margin-bottom: 0.25rem;
  }
}
```
