defmodule Examples.EventBroker do
  @moduledoc false

  def start_broker do
    with {:ok, broker_pid} <- EventBroker.start_link(),
         {:ok, registry_pid} <- EventBroker.Registry.start_link(broker_pid) do
      {:ok, %{broker: broker_pid, registry: registry_pid}}
    else
      _ -> :error
    end
  end

  def trivial_filter_spec do
    %EventBroker.Filters.Trivial{}
  end

  def this_module_filter_spec do
    %EventBroker.Filters.SourceModule{module: __MODULE__}
  end

  def example_message_a do
    %EventBroker.Event{
      source_module: __MODULE__,
      body: "example body"
    }
  end

  def example_message_b do
    %EventBroker.Event{
      source_module: Bad.Module,
      body: "example body"
    }
  end

  def subscribe_and_check do
    EventBroker.Registry.subscribe_me([
      trivial_filter_spec(),
      this_module_filter_spec(),
      trivial_filter_spec()
    ])

    EventBroker.event(example_message_a())
    EventBroker.event(example_message_b())

    {:ok, event} =
      receive do
        event = %EventBroker.Event{} ->
          {:ok, event}

        _ ->
          :error
      end

    EventBroker.Registry.unsubscribe_me([
      trivial_filter_spec(),
      this_module_filter_spec(),
      trivial_filter_spec()
    ])

    {:received, event}
  end

  def million_messages(num_filters) do
    filter_spec_list =
      for _ <- 1..num_filters do
        this_module_filter_spec()
      end

    EventBroker.Registry.subscribe_me(filter_spec_list)

    f = fn ->
      for _ <- 1..1_000_000 do
        EventBroker.event(example_message_a())

        {:ok, _} =
          receive do
            event = %EventBroker.Event{} ->
              {:ok, event}

            _ ->
              :error
          end
      end

      :success
    end

    result = :timer.tc(f)

    EventBroker.Registry.unsubscribe_me(filter_spec_list)

    result
  end
end
