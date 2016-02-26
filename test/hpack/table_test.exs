defmodule HPack.TableTest do
  use ExUnit.Case, async: true

  alias HPack.Table
  doctest Table

  setup do
    {:ok, table} = Table.start_link 1_000
    {:ok, table: table}
  end

  test "lookp up from static table", %{table: table} do
    assert {":method", "GET"} = Table.lookup(2, table)
  end

  test "adding to dynamic table", %{table: table} do
    header = {"some-header", "some-value"}
    Table.add(header, table)
    assert header = Table.lookup(62, table)
  end

  test "evict entries on table size change", %{table: table} do
    header = {"some-header", "some-value"}
    Table.add(header, table)
    Table.size(0, table) # evict all entries in dynamic tab
    assert :none = Table.lookup(62, table)
  end

end
