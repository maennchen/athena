defmodule AthenaWeb.Frontend.Dashboard.TableLive do
  @moduledoc false

  use AthenaWeb, :live

  alias Athena.Inventory
  alias Athena.Inventory.Event
  alias Athena.Inventory.Item
  alias Athena.Inventory.ItemGroup
  alias Athena.Inventory.Location
  alias Athena.Inventory.StockEntry
  alias Phoenix.PubSub

  @impl Phoenix.LiveView
  def mount(%{"event" => event_id}, _session, socket) do
    event = Inventory.get_event!(event_id)

    PubSub.subscribe(Athena.PubSub, "event:updated:#{event_id}")
    PubSub.subscribe(Athena.PubSub, "location:event:#{event_id}")
    PubSub.subscribe(Athena.PubSub, "movement:event:#{event_id}")

    {:ok,
     socket
     |> assign(orientation: "landscape")
     |> update(event_id)
     |> assign_navigation(event)}
  end

  @impl Phoenix.LiveView
  def handle_info({action, %type{}, _extra}, socket)
      when action in [:created, :updated, :deleted] and
             type in [
               Athena.Inventory.Event,
               Athena.Inventory.Location,
               Athena.Inventory.Movement
             ] do
    {:noreply, update(socket, socket.assigns.event.id)}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "orientationchange",
        %{"orientation" => orientation},
        %Phoenix.LiveView.Socket{assigns: %{orientation: orientation}} = socket
      ),
      do: {:noreply, socket}

  def handle_event("orientationchange", %{"orientation" => orientation}, socket),
    do:
      {:noreply, assign(socket, orientation: orientation, table: transpose(socket.assigns.table))}

  defp update(socket, event_id) do
    %Event{locations: locations, item_groups: item_groups, stock_entries: stock_entries} =
      event =
      event_id
      |> Inventory.get_event!()
      |> Repo.preload(locations: [], item_groups: [items: []], stock_entries: [item: []])

    stock_entries_map = Map.new(stock_entries, &{{&1.location_id, &1.item_id}, &1})

    table = [
      List.flatten([
        :empty_header
        | for %ItemGroup{items: items} = item_group <- item_groups do
            [item_group | items]
          end
      ])
      | for location <- locations do
          List.flatten([
            location
            | for %ItemGroup{items: items} <- item_groups do
                [
                  :item_group_spacer
                  | for item <- items do
                      stock_entries_map[{location.id, item.id}]
                    end
                ]
              end
          ])
        end
    ]

    table =
      case socket.assigns.orientation do
        "landscape" -> table
        "portrait" -> transpose(table)
      end

    assign(socket, event: event, table: table)
  end

  defp transpose(table), do: table |> Enum.zip() |> Enum.map(&Tuple.to_list/1)
end