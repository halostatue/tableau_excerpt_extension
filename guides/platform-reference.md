# Platform Reference

TableauExcerptExtension supports a number of different platforms out of the box,
and can support more with site extension configuration.

## Supported Platforms

| Platform       | Key                                 |
| -------------- | ----------------------------------- |
| Bluesky        | `bluesky`                           |
| Facebook       | `facebook`                          |
| GitHub         | `github`                            |
| Hacker News    | `hacker-news` (`hacker_news`)       |
| Instagram      | `instagram`                         |
| Keybase        | `keybase`                           |
| LinkedIn       | `linkedin`                          |
| Mastodon       | `mastodon`                          |
| Newsblur       | `newsblur`                          |
| PeerTube       | `peertube`                          |
| Pinterest      | `pinterest`                         |
| Pixelfed       | `pixelfed`                          |
| Reddit         | `reddit`                            |
| Stack Overflow | `stack-overflow` (`stack_overflow`) |
| Threads        | `threads`                           |
| TikTok         | `tiktok`                            |
| Tumblr         | `tumblr`                            |
| Twitter[^1]    | `twitter`                           |
| YouTube        | `youtube`                           |

> Pull requests for new platform support will be considered, but there are some
> platforms that will never be accepted.

[^1]: This is a deliberate choice.

## Platform Account Configuration

Platform accounts are configured in site configuration under the `:account` key
or in content frontmatter under the `social_accounts` key. Platform keys are
normalized from `snake_case` to `kebab-case` (e.g., `stack_overflow` becomes
`stack-overflow`).

Accounts may be specified for each platform with a string, an account map, or a
list of strings or account maps.

Account strings are parsed into account maps. For simple platforms, the username
string is used unmodified[^2] as the `username` value in an account map
(`%{"username" => "username"}`). More complex platforms may parse the string
into more complex account maps.

- Fediverse platforms all accept `user@instance.domain` usernames, parsing to
  `%{"username" => user, "instance"=> "instance.domain"}`. This is in line with
  how most Fediverse accounts are displayed.

- Stack Overflow accepts `12345/username`, parsing to
  `%{"id" => 12345, "username" => username}`. This is not a standard format for
  Stack Overflow, but the user IDs are only visible from a user's profile page
  URL and are required to build a proper profile page URL.

- Reddit accepts both subreddits (`r/subreddit`) and user profiles
  (`u/username`), parsing as `%{"type" => "subreddit", "name" => "subreddit"}`
  and `%{"type" => "user", "name" => "username"}`, respectively.

[^2]: Any leading `@` is removed from string values — `username` and `@username`
    are treated identically

All of these configurations are equivalent:

- `github: "username"`
- `github: ["username"]`
- `github: %{"username" => "username"}`
- `github: [%{"username" => "username"}]`

### Site Configuration

Accounts are configured site-wide with `:account` configuration key. This is a
keyword list or map of platforms to one or more configured accounts for that
platform.

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  accounts: [
    github: "elixir-lang"
  ]
```

### Frontmatter Configuration

Accounts may be configured in content frontmatter with the `social_accounts`
map.

```yaml
social_accounts:
  github: elixir-lang
```

Frontmatter account configuration by default _replaces_ site configuration for
platforms specified. The above example would replace any configured accounts
with `elixir-lang`. A platform may be disabled for a content page by setting the
value as `false` or `nil`.

```yaml
social_accounts:
  github: nil # Disable GitHub on this page
```

To specify accounts with those values, they must be specified as strings.

```yaml
social_accounts:
  github: "nil"
```

Accounts may be appended or prepending to the list of accounts by specifying
`{platform}[append]` or `{platform}[prepend]`. If an account is _already
present_ in the `platform` account list, it will be removed from the existing
list and appended or prepended in the order provided.

If we have a site configuration with `elixir-tools` and `elixir-lang` specified

```elixir
config :tableau, TableauExcerptExtension,
  accounts: %{github: ["elixir-tools", "elixir-lang"]}
```

Then using either `github[append]: [elixir-ecto, elixir-tools]` or
`github[prepend]: [elixir-lang, elixir-ecto]` will produce the account list
`[elixir-lang, elixir-ecto, elixir-tools]`. If the same account is present in
both `{platform}[append]` and `{platform}[prepend]`, the order is undefined.
Neither `{platform}[append]` nor `{platform}[prepend]` may be used with bare
`{platform}`.

### Frontmatter Directives

There are two special directives which may be specified in `social_accounts`,
`[include]` and `[order]` (which become `["include"]` and `["order"]`,
respectively).

#### Platform Filtering

The `[include]` directive limits the platforms that will be included for use in
the content. This is similar to specifying `{platform}: false` for each platform
to be excluded, but is more efficient.

If accounts are configured for `github`, `mastodon`, `stack-overflow`, and
`youtube` then the following will only include `github` and `mastodon` accounts:

```yaml
social_accounts:
  [include]: [github, mastodon]
```

The `[include]` directive affects both social block and social link tags.

#### Social Block Platform Ordering

The `[order]` directive specifies the order of platforms in social blocks. By
default, platforms are ordered alphabetically. The `[order]` directive specifies
an explicit order; platforms not present present will be ordered alphabetically
_after_ the named platforms.

If accounts are configured for `github`, `mastodon`, `stack-overflow`, and
`youtube` then the following will produce the order `mastodon`, `youtube`,
`github`, and `stack-overflow`.

```yaml
social_accounts:
  [order]: [mastodon, youtube]
```

## Custom Platforms

TableauExcerptExtension can be extended to support additional platforms in your
Tableau site by using the `:platforms` configuration key. For simple username
platforms, this is done with a configuration map.

```elixir
config :tableau, TableauExcerptExtension,
  platforms: %{
    "simple-platform" => %{
      label: "Simple Platform",
      url_template: "https://simple.example.com/{username}",
      default_link_text: "@{username}"
    }
  }
```

A platform configuration _must_ specify a `label` string value and either a
`url_template` string value or a `url_builder` MFA value. It _may_ specify a
`default_link_text` template string or MFA value.

```elixir
config :tableau, TableauExcerptExtension,
  platforms: %{
    "simple-platform" => %{
      label: "Simple Platform",
      url_builder: {MySite.SimplePlatformHandler, :url_builder, []},
      default_link_text: {MySite.SimplePlatformHandler, :default_link_text, []}
    }
  }
```

Both of these callbacks are 1-arity functions that accept an account map and
produce a wrapped result (`{:ok, binary()} | :error | {:error, binary()}`).

More complex platform support requires a custom platform handler, implementing
the `TableauExcerptExtension.Platform` behaviour.

### Templates and Field Substitution

The `url_template` (`url_template/0` callback) and `default_link_text`
(`default_link_text/0` callback) return template strings with `{field}` syntax
where the `field` corresponds to keys in the `t:account/0` map returned by
`parse_account/1`. Template fields which do not have a matching key will remain
unmodified.

If we assume an account map of `%{"username" => "someuser"}`, then
`https://example.com/{username}` becomes `https://example.com/someuser` and
`https://{instance}/{username}` becomes `https://{instance}/someuser`.

### Platform Behaviour

The platform behaviour is fully documented in the
[Platform](m:TableauExcerptExtension.Platform) module. The typical way of using a
handler is to specify it as the value of the platform key — but it may also be
set as the optional `:handler` key for a platform where optional callbacks in
the platform behaviour are only required for missing configuration keys.

```elixir
config :tableau, TableauExcerptExtension,
  platforms: %{
    "full-platform" => MySite.FullPlatformHandler,
    "partial-platform" => %{
      label: "Partial Platform",
      url_template: "https://partial.example.com/{type}/{username}",
      handler: MySite.PartialPlatformHandler,
    }
  }
```

In the example above, both handlers must implement the required callbacks.
`MySite.PartialPlatformHandler` only needs to implement either
`default_link_text/0` or `default_link_text/1`. `MySite.FullPlatformHandler`
must implement `label/0`, either `url_template/0` or `url_builder/1`, and either
`default_link_text/0` or `default_link_text/1`.

If support for a new Fediverse platform is required, it is recommended to use
the TableauExcerptExtension.Platform.Fediverse helpers where possible.

#### Platform Behaviour Callbacks

```elixir
defmodule MyApp.CustomPlatformHandler do
  use TableauExcerptExtension.Platform # ①

  @impl Platform
  def keys, do: ["username", "instance"] # ②

  @impl Platform
  def parse_account(account) when is_binary(account) do # ③
    case String.split(account, "@", parts: 2) do
      [user, instance] -> {:ok, %{"username" => user, "instance" => instance}}
      [user] -> {:ok, %{"username" => user, "instance" => "default.example.com"}}
    end
  end

  def parse_account(%{"username" => user, "instance" => instance}) do
    {:ok, %{"username" => user, "instance" => instance}}
  end

  def parse_account(_), do: {:error, "Invalid account format"}

  @impl Platform
  def filter_by_key(accounts, key) do # ③ 
    case Enum.find(accounts, &(&1["username"] == key)) do
      nil -> {:error, "No account found for username #{key}"}
      account -> {:ok, account}
    end
  end

  @impl Platform
  def label, do: "Custom Platform" # ④

  @impl Platform
  def url_template, do: "https://{instance}/{username}" # ⑤

  @impl Platform
  def default_link_text, do: "@{username}@{instance}" # ⑥
end
```

1. It is strongly recommended to `use TableauExcerptExtension.Platform` instead
   of `@behaviour TableauExcerptExtension.Platform`, because a default `name/0`
   implementation will be provided and an after compile pass will be made to
   ensure that only one of `url_template/0` or `url_builder/1` and only one of
   `default_link_text/0` or `default_link_text/1` is defined.

2. This is a required callback and returns string keys used in account maps for
   the platform.

3. These are required callbacks and **should** be implemented to process both
   string and map configuration, but platforms like Slack may only support map
   configuration. Partial lookups should be supported if there are multiple keys
   in the platform account map.

4. `label/0` is required only when there is no `label` field in the platform
   configuration.

5. `url_template/0` (or `url_builder/1`) is required when there is no
   `url_template` or `url_builder` field in the platform configuration.

6. `default_link_text/0` (or `default_link_text/1`) is required when there is no
   `default_link_text` field in the platform configuration.
