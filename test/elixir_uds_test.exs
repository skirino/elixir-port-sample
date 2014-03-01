defmodule TestServer do
  use ElixirUds.ServerBase

  def handle_data(data, state) do
    { :string.to_upper(data), Dict.put(state, :set_in_override, true) }
  end
end

defmodule TestSup do
  use Supervisor.Behaviour

  def init([]) do
    tree = [worker(TestServer, [:elixir_uds_server, "/tmp/elixir_uds_test"])]
    supervise(tree, strategy: :one_for_one)
  end
end

defmodule ElixirUdsTest do
  use ExUnit.Case

  def with_supervised_server(f) do
    { :ok, pid } = :supervisor.start_link(TestSup, [])
    :timer.sleep(100)
    f.(pid)
    :supervisor.terminate_child(pid, TestServer)
    Process.exit(pid, :normal)
  end

  def count_ruby_processes do
    { n, _ } = Integer.parse System.cmd("ps aux | grep 'ruby.*priv\\/uds\.rb' | wc -l")
    n
  end

  test "server should start/stop with a Ruby process" do
    assert count_ruby_processes == 0
    with_supervised_server fn(pid) ->
      assert count_ruby_processes == 1
      :ok = :supervisor.terminate_child(pid, TestServer)
      assert count_ruby_processes == 0
    end
  end

  test "get/put/del" do
    with_supervised_server fn(_pid) ->
      assert TestServer.get(:elixir_uds_server, :hoge     ) == nil
      assert TestServer.put(:elixir_uds_server, :hoge, 100) == :ok
      assert TestServer.get(:elixir_uds_server, :hoge     ) == 100
      assert TestServer.del(:elixir_uds_server, :hoge     ) == :ok
      assert TestServer.get(:elixir_uds_server, :hoge     ) == nil
    end
  end

  def send_and_receive_by_ruby_client(msg) do
    assert TestServer.del(:elixir_uds_server, :set_in_override) == :ok
    client_received = String.rstrip System.cmd("./priv/test_client.rb /tmp/elixir_uds_test '#{msg}'")
    assert TestServer.get(:elixir_uds_server, :set_in_override) == true
    client_received
  end

  test "client should be able to read from and write to the Unix domain socket" do
    with_supervised_server fn(_pid) ->
      list = [
        "1",
        "hello",
        String.duplicate("0", 4096),
        String.duplicate("0", 4097),
      ]
      Enum.each list, fn(msg) ->
        assert send_and_receive_by_ruby_client(msg) == String.upcase(msg)
      end
    end
  end
end
