# HPack (RFC 7541) [![Build Status](https://travis-ci.org/nesQuick/elixir-hpack.svg?branch=master)](https://travis-ci.org/nesQuick/elixir-hpack)

Implementation of the [HPack](https://http2.github.io/http2-spec/compression.html) protocol, a compression format for efficiently representing HTTP header fields, to be used in HTTP/2.

## Disclosure

This implementation is heavily work in progress! :warning:

The following features needs to be implemented:
- encoding of
  - headers

Nice to have:
- transcoding for intermediaries

## Installation

:warning: not yet available in Hex :warning:

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

1. Add hpack to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:hpack, "~> 0.0.1"}]
  end
  ```

2. Ensure hpack is started before your application:

  ```elixir
  def application do
    [applications: [:hpack]]
  end
  ```
