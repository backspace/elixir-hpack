defmodule HPack do
  @moduledoc """
    Implementation of the [HPack](https://http2.github.io/http2-spec/compression.html) protocol, a compression format for efficiently representing HTTP header fields, to be used in HTTP/2.
  """

  # def transcode(hbf)
  # def encode([{key, value} | headers ], table)
  # def encode([{key, value} | [] ], table)

  @doc """
  Decodes a `header block fragment` as specified in RFC 7541.

  Returns the decoded headers as a List.

  ## Examples

    iex> {:ok, table} = HPack.Table.start_link(1000)
    iex> HPack.decode(<< 0x82 >>, table)
    [{":method", "GET"}]

  """
  @spec decode(String.t, pid) :: List
  def decode(hbf, table) do
    parse(hbf, [], table)
  end

  defp parse(<< >>, headers, _), do: Enum.reverse(headers)

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 1 |        Index (7+)         |
  # +---+---------------------------+
  #  Figure 5: Indexed Header Field
  defp parse(<<1::size(1), index :: size(7), rest :: binary>>, headers, table) do
    parse(rest, [HPack.Table.lookup(index, table) | headers], table)
  end

  #  0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 1 |      Index (6+)       |
  # +---+---+-----------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 6: Literal Header Field with Incremental Indexing — Indexed Name
  defp parse(<< 0::size(1), 1::size(1), index::size(6), rest :: binary>>, headers, table) when index > 0 do
    { value, more_headers } = parse_string(rest)
    { header, _ } = HPack.Table.lookup(index, table)
    HPack.Table.add({header, value}, table)
    parse(more_headers, [ {header, value} | headers], table)
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 1 |           0           |
  # +---+---+-----------------------+
  # | H |     Name Length (7+)      |
  # +---+---------------------------+
  # |  Name String (Length octets)  |
  # +---+---------------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 7: Literal Header Field with Incremental Indexing — New Name
  defp parse(<< 0::size(1), 1::size(1), 0::size(6), rest :: binary>>, headers, table) do
    { name, rest } = parse_string(rest)
    { value, more_headers } = parse_string(rest)
    HPack.Table.add({name, value}, table)
    parse(more_headers, [{name, value} | headers], table)
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 0 | 0 |  Index (4+)   |
  # +---+---+-----------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 8: Literal Header Field without Indexing — Indexed Name
  defp parse(<< 0::size(4), index::size(4), rest :: binary >>, headers, table) do
    { value, more_headers } = parse_string(rest)
    { header, _ } = HPack.Table.lookup(index, table)
    parse(more_headers, [{ header, value } | headers], table)
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 0 | 0 |       0       |
  # +---+---+-----------------------+
  # | H |     Name Length (7+)      |
  # +---+---------------------------+
  # |  Name String (Length octets)  |
  # +---+---------------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 9: Literal Header Field without Indexing — New Name
  defp parse(<< 0::size(4), 0::size(4), rest::binary >>, headers, table) do
    { name, rest } = parse_string(rest)
    { value, more_headers } = parse_string(rest)
    parse(more_headers, [{name, value} | headers], table)
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 0 | 1 |       0       |
  # +---+---+-----------------------+
  # | H |     Name Length (7+)      |
  # +---+---------------------------+
  # |  Name String (Length octets)  |
  # +---+---------------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 11: Literal Header Field Never Indexed — New Name
  defp parse(<< 0::size(3), 1::size(1), 0::size(4), rest :: binary >>, headers, table) do
    { name, rest } = parse_string(rest)
    { value, more_headers } = parse_string(rest)
    parse(more_headers, [{name, value} | headers], table)
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 0 | 1 |  Index (4+)   |
  # +---+---+-----------------------+
  # | H |     Value Length (7+)     |
  # +---+---------------------------+
  # | Value String (Length octets)  |
  # +-------------------------------+
  # Figure 10: Literal Header Field Never Indexed — Indexed Name
  defp parse(<< 0::size(3), 1::size(1), index::size(4), rest::binary >>, headers, table) do
    { value, more_headers } = parse_string(rest)
    { header, _ } = HPack.Table.lookup(index, table)
    parse(more_headers, [{ header, value } | headers], table)
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 1 |   Max size (5+)   |
  # +---+---------------------------+
  # Figure 12: Maximum Dynamic Table Size Change
  defp parse(<< 0::size(2), 1::size(1), size::size(5), rest::binary >>, headers, table) do
    HPack.Table.resize(size, table)
    parse(rest, headers, table)
  end

  defp parse_string(<< 0::1, length::7, value::binary - size(length), rest::binary >>), do: { value, rest }
  defp parse_string(<< 1::1, length::7, value::binary - size(length), rest::binary >>), do: { HPack.Huffman.decode(value), rest }

end
