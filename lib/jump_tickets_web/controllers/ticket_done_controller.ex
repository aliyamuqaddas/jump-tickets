defmodule JumpTicketsWeb.TicketDoneController do
  use JumpTicketsWeb, :controller

  alias JumpTickets.Ticket
  alias JumpTickets.External.Notion
  alias JumpTickets.External.Notion.Parser
  alias JumpTickets.Ticket.DoneNotifier

  @doc """
  Handles a Notion webhook for when a ticket is marked as Done.

  Expects a JSON payload with the `page_id` key.
  """
  def notion_webhook(conn, %{"page_id" => page_id}) do
    with %Ticket{done: true} = ticket <- Notion.get_ticket_by_page_id(page_id),
         :ok <- DoneNotifier.notify_ticket_done(ticket) do
      json(conn, %{status: "ok", message: "Ticket done notification sent."})
    else
      %Ticket{done: false} ->
        json(conn, %{status: "ok", message: "Ticket not marked as done, skipping notification."})

      {:error, :empty_channel_id} ->
        # When channel ID is empty from the parsed URL
        conn
        |> put_status(400)
        |> json(%{status: "error", error: "Slack channel ID is empty or invalid"})

      {:error, :no_slack_channel} ->
        # When no Slack channel is provided
        conn
        |> put_status(400)
        |> json(%{status: "error", error: "No Slack channel provided for the ticket"})

      {:error, :invalid_slack_channel_url} ->
        # When Slack channel URL format is invalid
        conn
        |> put_status(400)
        |> json(%{status: "error", error: "Invalid Slack channel URL format"})

      error ->
        # Log the error for better debugging
        require Logger
        Logger.error("Error in TicketDoneController: #{inspect(error)}")

        conn
        |> put_status(500)
        |> json(%{status: "error", error: inspect(error)})
    end
  end
end
