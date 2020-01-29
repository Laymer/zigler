defmodule ZiglerTest.LongNifTest do
  use ExUnit.Case

  use Zigler, app: :zigler, resources: [:add_resource]

  ~Z"""
  const std = @import("std");

  const __add_cache__ = struct {
    env: beam.env,
    self: beam.pid,
    ref: beam.term,
    thread: *std.Thread,
    res: beam.term,
    left: i64,
    right: i64,
  };

  fn __add_packer__(cache_ret: **__add_cache__, env: beam.env, left: i64, right: i64) !void {
    var cache = try beam.allocator.create(__add_cache__);
    errdefer { beam.allocator.destroy(cache); }

    cache.env = env;
    cache.self = try beam.self(env);
    cache.ref = try beam.make_ref(env);
    cache.res = try beam.resource.create(i64, env, add_resource, undefined);

    cache.left = left;
    cache.right = right;

    cache.thread = try std.Thread.spawn(cache, __add_harness__);

    cache_ret.* = cache;
  }

  /// nif: add/2 long
  fn add(left: i64, right: i64) i64 {
    return left + right;
  }

  fn __add_harness__(cache: *__add_cache__) void {
    defer beam.allocator.destroy(cache);

    var result = add(cache.left, cache.right);

    beam.resource.update(i64, cache.env, add_resource, cache.res, result)
      catch |err| return;

    var res = e.enif_send(null, &cache.self, cache.env, cache.ref);
  }

  /// nif: __add_launch__/2
  fn __add_launch__(env: beam.env, left: i64, right: i64) beam.term {
    var cache: *__add_cache__ = undefined;

    __add_packer__(&cache, env, left, right) catch {
      return beam.raise(env, beam.make_atom(env, "error"[0..]));
    };

    return e.enif_make_tuple(env, 2, cache.ref, cache.res);
  }

  /// destructor: async_add_resource
  extern fn destroy_add_resource(env: beam.env, obj: ?*c_void) void {
    // nothing needs to happen since this object is a single int64
  }
  """

  # stage 8.  Decouple the fetch function.

  @tag :long
  test "we can trigger the function" do
    assert 47 == add(40, 7)
  end

end