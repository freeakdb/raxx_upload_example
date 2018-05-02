defmodule Upload.Service do
  @moduledoc false

  use Raxx.Server
  use Raxx.Logger

  require Logger

  alias Raxx.Request
  alias Upload.FileHandler

  # Handle request headers
  #
  # This callbacks receives a `Raxx.Request` struct which contains all the headers, path
  # info etc. `body: true` means that the request carries a body.
  #
  # In our case we're only interested in PUT requests containing the body, sent to
  # `/uploads/:name`.
  @impl true
  def handle_head(%Request{method: :PUT, body: true, path: ["uploads", name]}, _state) do
    Logger.debug("Initiating upload")
    file_handler = FileHandler.new(name)
    # Empty list here means that we're not returning anything to a client yet. The state
    # is the file handler used later to write chunks of data.
    {[], file_handler}
  end

  # Let's return 404 for all other requests.
  def handle_head(_request, _state) do
    response(:not_found)
    |> set_header("content-type", "text/plain")
    |> set_body("Not found")
  end

  # Handle chunks of data
  @impl true
  def handle_data(chunk, file_handler) do
    Logger.debug(fn -> "Received #{byte_size(chunk)} byte chunk of data" end)
    FileHandler.write_chunk(file_handler, chunk)
    # Empty list here means that we're not returning anything to the client yet. Let's
    # write each chunk to a file opened in `handle_head/2` and return the state as is.
    {[], file_handler}
  end

  # Handle end of request
  #
  # This callback receives request "trailers", which apparently are HTTP headers sent
  # at the end of the request. I had no idea one could do that.
  @impl true
  def handle_tail(_trailers, file_handler) do
    Logger.debug(fn -> "Upload completed" end)
    # We don't really need to close the file because the process will die anyway.
    FileHandler.close(file_handler)
    # We're finally returning the response. We don't need to return state here anymore
    # because no callback related to current request will be ever called again.
    response(:no_content)
  end
end
