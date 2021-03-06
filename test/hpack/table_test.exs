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
    assert header == Table.lookup(62, table)
  end

  test "adds to dynamic table at the beginning", %{table: table} do
    second_header = {"some-header-2", "some-value-2"}
    Table.add({"some-header", "some-value"}, table)
    Table.add(second_header, table)
    assert second_header == Table.lookup(62, table)
  end

  test "evict entries on table size change", %{table: table} do
    header = {"some-header", "some-value"}
    Table.add(header, table)
    Table.resize(0, table) # evict all entries in dynamic table
    assert :none == Table.lookup(62, table)
  end

  test "evict oldest entries when size > table size", %{table: table} do
    Table.resize(60, table)

    third_header = {"some-header-3", "some-value-3"}
    Table.add({"some-header", "some-value"}, table)
    Table.add({"some-header-2", "some-value-2"}, table)
    Table.add(third_header, table)

    assert third_header == Table.lookup(62, table)
    assert :none == Table.lookup(63, table)
  end

  test "find a key with corresponding value from static table", %{table: table} do
    assert Table.find(":method", "GET", table) == { :fullindex, 2 }
  end

  test "find a key without corresponding value from static table", %{table: table} do
    assert Table.find("etag", "1e2345678", table) == { :keyindex, 34 }
  end

  test "return :none when key not found in table", %{table: table} do
    assert Table.find("x-something", "some-value", table) == { :none }
  end

  test "find a key with corresponding value from dynamic table", %{table: table} do
    Table.add({"x-something", "some-value"}, table)
    assert Table.find("x-something", "some-value", table) == { :fullindex, 62 }
  end

end
