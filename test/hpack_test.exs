defmodule HpackTest do
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

  test "decode big number (Index7+)", %{table: table} do
    Table.resize(1_000_000_000, table) #make it big enough
    1..1337 |> Enum.map(fn(i) -> Table.add({"h-#{i}", "v-#{i}"}, table) end)

    hbf = << 0b00111111, 0b10011010, 0b00001010 >>
    headers = HPack.decode(hbf, table)

    assert Table.size(table) <= 1337
    assert headers == []
  end

end
