defmodule ZiglerTest.Snapshot.FooterTest do
  use ExUnit.Case, async: true

  alias Zigler.{Module, Parser.Nif, Parser.Resource, Code}

  describe "the zigler compiler footer generates" do
    test "works for a single function" do

      [major, minor] = Code.nif_major_minor()

      assert """
      var __exported_nifs__ = [1] e.ErlNifFunc{
        e.ErlNifFunc{
          .name = c"foo",
          .arity = 0,
          .fptr = __foo_shim__,
          .flags = 0,
        },
      };

      const entry = e.ErlNifEntry{
        .major = #{major},
        .minor = #{minor},
        .name = c"Elixir.Foo",
        .num_of_funcs = 1,
        .funcs = &(__exported_nifs__[0]),
        .load = null,
        .reload = null,
        .upgrade = null,
        .unload = null,
        .vm_variant = c"beam.vanilla",
        .options = 1,
        .sizeof_ErlNifResourceTypeInit = 24,
        .min_erts = c"erts-#{:erlang.system_info(:version)}"
      };

      export fn nif_init() *const e.ErlNifEntry{
        return &entry;
      }
      """ == %Module{nifs: [%Nif{name: :foo, arity: 0}], file: "foo.exs", module: Foo, app: :zigler}
      |> Code.footer
      |> IO.iodata_to_binary
    end

    test "works for a function + a resource" do

      [major, minor] = Code.nif_major_minor()

      assert """
      var __exported_nifs__ = [1] e.ErlNifFunc{
        e.ErlNifFunc{
          .name = c"foo",
          .arity = 0,
          .fptr = __foo_shim__,
          .flags = 0,
        },
      };

      var __bar_resource__: beam.resource_type = undefined;

      fn __init_bar_resource__(env: beam.env) beam.resource_type {
        return e.enif_open_resource_type(
          env,
          null,
          c"bar",
          __destroy_bar__,
          @intToEnum(e.ErlNifResourceFlags, 3),
          null);
      }

      extern fn __destroy_bar__(env: beam.env, obj: ?*c_void) void {}

      fn __resource_type__(comptime T: type) beam.resource_type {
        switch (T) {
          bar => return __bar_resource__,
          else => unreachable
        }
      }

      const __resource__ = struct {
        fn create(comptime T: type, env: beam.env, value: T) !beam.term {
          return beam.resource.create(T, env, __resource_type__(T), value);
        }

        fn update(comptime T: type, env: beam.env, res: beam.term, value: T) !beam.term {
          return beam.resource.update(T, env, __resource_type__(T), res, value);
        }

        fn fetch(comptime T: type, env: beam.env, res: beam.term) !T {
          return beam.resource.fetch(T, env, __resource_type__(T), res);
        }

        fn release(comptime T: type, env: beam.env, res: beam.term) void {
          return beam.resource.release(T, env, __resource_type__(T), res);
        }
      };

      extern fn nif_load(env: beam.env, priv: [*c]?*c_void, load_info: beam.term) c_int {
        __bar_resource__ = __init_bar_resource__(env);
        return 0;
      }

      const entry = e.ErlNifEntry{
        .major = #{major},
        .minor = #{minor},
        .name = c"Elixir.Foo",
        .num_of_funcs = 1,
        .funcs = &(__exported_nifs__[0]),
        .load = nif_load,
        .reload = null,
        .upgrade = null,
        .unload = null,
        .vm_variant = c"beam.vanilla",
        .options = 1,
        .sizeof_ErlNifResourceTypeInit = 24,
        .min_erts = c"erts-#{:erlang.system_info(:version)}"
      };

      export fn nif_init() *const e.ErlNifEntry{
        return &entry;
      }
      """ == %Module{nifs: [%Nif{name: :foo, arity: 0}], resources: [%Resource{name: :bar}], file: "foo.exs", module: Foo, app: :zigler}
      |> Code.footer
      |> IO.iodata_to_binary
    end

    test "works for multiple functions" do

      [major, minor] = Code.nif_major_minor()

      assert """
      var __exported_nifs__ = [2] e.ErlNifFunc{
        e.ErlNifFunc{
          .name = c"foo",
          .arity = 0,
          .fptr = __foo_shim__,
          .flags = 0,
        },
        e.ErlNifFunc{
          .name = c"bar",
          .arity = 1,
          .fptr = __bar_shim__,
          .flags = 0,
        },
      };

      const entry = e.ErlNifEntry{
        .major = #{major},
        .minor = #{minor},
        .name = c"Elixir.Baz",
        .num_of_funcs = 2,
        .funcs = &(__exported_nifs__[0]),
        .load = null,
        .reload = null,
        .upgrade = null,
        .unload = null,
        .vm_variant = c"beam.vanilla",
        .options = 1,
        .sizeof_ErlNifResourceTypeInit = 24,
        .min_erts = c"erts-#{:erlang.system_info(:version)}"
      };

      export fn nif_init() *const e.ErlNifEntry{
        return &entry;
      }
      """ == %Module{nifs: [
               %Nif{name: :foo, arity: 0},
               %Nif{name: :bar, arity: 1}],
             file: "foo.exs", module: Baz, app: :zigler}
      |> Code.footer
      |> IO.iodata_to_binary
    end
  end
end
