defmodule HPackTest do
  use ExUnit.Case

  alias HPack.Table

  doctest HPack

  setup do
    {:ok, table} = Table.start_link 1000
    {:ok, table: table}
  end

  test "decode from static table", %{table: table} do
    assert hd(HPack.decode(<< 0x82 >>, table)) == { ":method", "GET" }
  end

  test "decode big number (Index5+)", %{table: table} do
    Table.resize(1_000_000_000, table) # make it big enough
    1..1337 |> Enum.map(fn(i) -> Table.add({"h-#{i}", "v-#{i}"}, table) end)

    # Maximum Dynamic Table Size Change header to 1337
    hbf = << 0b00111111, 0b10011010, 0b00001010 >>
    headers = HPack.decode(hbf, table)

    assert Table.size(table) <= 1337
    assert headers == []
  end

  test "encode big number (Index7+)", %{table: table} do
    super_long_value = "very long long value Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat, vel illum dolore eu feugiat nulla facilisis at vero eros et accumsan et iusto odio dignissim qui blandit praesent luptatum zzril delenit augue duis dolore te feugait nulla facilisi. Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam,"
    hbf = HPack.encode [{"short-key", super_long_value}], table

    {:ok, decode_table} = Table.start_link(1000)

    assert HPack.decode(hbf, decode_table) == [{"short-key", super_long_value}]
  end
end
