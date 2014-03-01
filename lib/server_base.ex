defmodule ElixirUds.ServerBase do
  defmacro __using__(_opts) do
    quote do
      use GenServer.Behaviour

      # Public API
      def start_link(process_name, socket_path, initial_state \\ []) when is_atom(process_name) and is_bitstring(socket_path) and is_list(initial_state) do
        :gen_server.start_link({ :local, process_name }, __MODULE__, [socket_path, initial_state], [])
      end

      def get(process_ref, key) when is_tuple(process_ref) or is_atom(process_ref) or is_pid(process_ref) do
        :gen_server.call(process_ref, { :get, key })
      end
      def put(process_ref, key, value) when is_tuple(process_ref) or is_atom(process_ref) or is_pid(process_ref) do
        :gen_server.call(process_ref, { :put, key, value })
      end
      def del(process_ref, key) when is_tuple(process_ref) or is_atom(process_ref) or is_pid(process_ref) do
        :gen_server.call(process_ref, { :del, key })
      end

      # Callbacks
      def init([socket_path, initial_state]) do
        port = :erlang.open_port({ :spawn, './priv/uds.rb #{socket_path} #{System.get_pid}' }, [packet: 4])
        :erlang.process_flag(:trap_exit, true)
        { :ok, Dict.merge(initial_state, [port: port]) }
      end

      def handle_call({ :get, key }, _from, state) do
        case Dict.fetch(state, key) do
          { :ok, value } -> { :reply, value, state }
          :error         -> { :reply, nil  , state }
        end
      end
      def handle_call({ :put, key, value }, _from, state) do
        new_state = Dict.put(state, key, value)
        { :reply, :ok, new_state }
      end
      def handle_call({ :del, key }, _from, state) do
        new_state = Dict.delete(state, key)
        { :reply, :ok, new_state }
      end

      def handle_info({ port, { :data, data } }, state) do
        { new_data, new_state } = handle_data(data, state)
        send port, { self, { :command, new_data } }
        { :noreply, new_state }
      end
      def handle_info({ :EXIT, port, reason }, state) do
        { :stop, { :port_terminated, reason }, state }
      end

      def terminate({ :port_terminated, _reason }, _state) do
        :ok
      end
      def terminate(_reason, state) do
        { :ok, port } = Dict.fetch(state, :port)
        { :os_pid, os_pid } = :erlang.port_info(port, :os_pid)
        :erlang.port_close(port)
        System.cmd("kill #{os_pid}")
        :ok
      end

      # Overridable callback to process received data
      def handle_data(data, state) do
        {data, state}
      end

      defoverridable [handle_data: 2]
    end
  end
end
