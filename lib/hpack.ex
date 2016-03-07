defmodule HPack do
  @moduledoc """
    Implementation of the [HPack](https://http2.github.io/http2-spec/compression.html) protocol, a compression format for efficiently representing HTTP header fields, to be used in HTTP/2.
  """

  use Bitwise
  alias HPack.Huffman

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
  @spec decode(String.t, pid) :: [{String.t, String.t}]
  def decode(hbf, table) do
    parse(hbf, [], table)
  end

  defp parse(<< >>, headers, _), do: Enum.reverse(headers)

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 1 |        Index (7+)         |
  # +---+---------------------------+
  #  Figure 5: Indexed Header Field
  defp parse(<< 1::1, rest::bitstring >>, headers, table) do
    { index, rest } = parse_int7(rest)
    parse(rest, [HPack.Table.lookup(index, table) | headers], table)
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
  defp parse(<< 0::1, 1::1, 0::6, rest::binary>>, headers, table) do
    { name, rest } = parse_string(rest)
    { value, more_headers } = parse_string(rest)
    HPack.Table.add({name, value}, table)
    parse(more_headers, [{name, value} | headers], table)
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
  defp parse(<< 0::1, 1::1, rest::bitstring >>, headers, table) do
    { index, rest } = parse_int6(rest)
    { value, more_headers } = parse_string(rest)
    { header, _ } = HPack.Table.lookup(index, table)
    HPack.Table.add({header, value}, table)
    parse(more_headers, [ {header, value} | headers], table)
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
  defp parse(<< 0::4, rest::bitstring >>, headers, table) do
    { index, rest } = parse_int4(rest)
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
  defp parse(<< 0::4, 0::4, rest::binary >>, headers, table) do
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
  defp parse(<< 0::3, 1::1, 0::4, rest::binary >>, headers, table) do
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
  defp parse(<< 0::3, 1::1, rest::bitstring >>, headers, table) do
    { index, rest } = parse_int4(rest)
    { value, more_headers } = parse_string(rest)
    { header, _ } = HPack.Table.lookup(index, table)
    parse(more_headers, [{ header, value } | headers], table)
  end

  #   0   1   2   3   4   5   6   7
  # +---+---+---+---+---+---+---+---+
  # | 0 | 0 | 1 |   Max size (5+)   |
  # +---+---------------------------+
  # Figure 12: Maximum Dynamic Table Size Change
  defp parse(<< 0::2, 1::1, rest::bitstring >>, headers, table) do
    {size, rest} = parse_int5(rest)
    HPack.Table.resize(size, table)
    parse(rest, headers, table)
  end

  defp parse_string(<< 0::1, rest::bitstring >>) do
    { length, rest } = parse_int7(rest)
    << value::binary - size(length), rest::binary >> = rest
    { value, rest }
  end
  defp parse_string(<< 1::1, rest::bitstring >>) do
    { length, rest } = parse_int7(rest)
    << value::binary - size(length), rest::binary >> = rest
    { Huffman.decode(value), rest }
  end

  defp parse_int4(<< 0b1111::4, rest::binary >>), do: parse_big_int(rest, 15, 0)
  defp parse_int4(<< int::4, rest::binary >>), do: { int, rest }

  defp parse_int5(<< 0b11111::5, rest::binary >>), do: parse_big_int(rest, 31, 0)
  defp parse_int5(<< int::5, rest::binary >>), do: { int, rest }

  defp parse_int6(<< 0b111111::6, rest::binary >>), do: parse_big_int(rest, 63, 0)
  defp parse_int6(<< int::6, rest::binary >>), do: { int, rest }

  defp parse_int7(<< 0b1111111::7, rest::binary >>), do: parse_big_int(rest, 127, 0)
  defp parse_int7(<< int::7, rest::binary >>), do: { int, rest }

  defp parse_big_int(<< 0::1, value::7, rest::binary >>, int, m), do: { int + (value <<< m), rest }
  defp parse_big_int(<< 1::1, value::7, rest::binary >>, int, m), do: parse_big_int(rest, int + (value <<< m), m + 7)
end
