defmodule ZiglerTest.Integration.Strategies.AllocatorsTest do
  use ExUnit.Case, async: true
  use Zigler

  ~Z"""
  /// nif: alloctest/1
  fn alloctest(env: ?*e.ErlNifEnv, length: i64) e.ErlNifTerm {
    var usize_length = @intCast(usize, length);
    var slice = beam.allocator.alloc(u8, usize_length) catch {
      return beam.raise_enomem(env);
    };
    defer beam.allocator.free(slice);
    // fill the slice with letters
    for (slice) | _char, i | {
      slice[i] = 97 + @intCast(u8, i);
    }
    return e.enif_make_atom_len(env, slice.ptr, slice.len);
  }

  /// nif: realloctest/1
  fn realloctest(env: ?*e.ErlNifEnv, length: i64) e.ErlNifTerm {
    var usize_length = @intCast(usize, length);
    var slice = beam.allocator.alloc(u8, usize_length) catch {
      return beam.raise_enomem(env);
    };
    defer beam.allocator.free(slice);

    var slice2 = beam.allocator.realloc(slice, usize_length * 2) catch {
      return beam.raise_enomem(env);
    };
    // fill the slice with letters
    for (slice2) | _char, i | {
      slice2[i] = 97 + @intCast(u8, i);
    }
    return e.enif_make_atom_len(env, slice2.ptr, slice2.len);
  }
  """

  test "elixir basic allocator works" do
    assert :ab == alloctest(2)
    assert :abc == alloctest(3)

    assert :abcd == realloctest(2)
    assert :abcdef == realloctest(3)
  end

  # proves that you can do something crazy, like keep memory around in global
  # var state.  don't do this in real code.  There are probably better ways of
  # safely doing this with a zig nif (for example, resources).

  ~Z"""
  var global_slice : []u8 = undefined;

  /// nif: allocate/1
  fn allocate(env: ?*e.ErlNifEnv, length: i64) bool {

    var usize_length = @intCast(usize, length);

    global_slice = beam.allocator.alloc(u8, usize_length) catch {
      // don't do this in real life!
      unreachable;
    };
    // NB: don't defer a free here (don't do this in real life!!!)

    // fill the slice with letters
    for (global_slice) | _char, i | {
      global_slice[i] = 97 + @intCast(u8, i);
    }

    return true;
  }

  /// nif: fetch/0
  fn fetch(env: ?*e.ErlNifEnv) e.ErlNifTerm {
    return e.enif_make_atom_len(env, global_slice.ptr, global_slice.len);
  }
  """

  test "elixir persistent memory works" do
    assert true == allocate(2)
    assert :ab == fetch()
  end
end
