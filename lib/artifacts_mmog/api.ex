defmodule ArtifactsMmog.API do
  @moduledoc """
  HTTP client for the ArtifactsMMO REST API.
  Base URL: https://api.artifactsmmo.com
  Auth: Bearer token via ARTIFACTS_MMOG_KEY env var.
  """

  @base_url "https://api.artifactsmmo.com"

  defp headers do
    [{"Authorization", "Bearer #{api_key()}"}, {"Content-Type", "application/json"}]
  end

  defp api_key do
    case System.get_env("ARTIFACTS_MMOG_KEY") do
      nil ->
        case ArtifactsMmog.Keystore.get() do
          {:ok, token} -> token
          _ -> ""
        end

      token ->
        token
    end
  end

  defp get(path, params \\ []) do
    case Req.get("#{@base_url}#{path}", headers: headers(), params: params, retry: false) do
      {:ok, resp} -> resp.body
      {:error, exception} -> %{"error" => Exception.message(exception)}
    end
  end

  defp post(path, body \\ %{}) do
    case Req.post("#{@base_url}#{path}", headers: headers(), json: body, retry: false) do
      {:ok, resp} -> resp.body
      {:error, exception} -> %{"error" => Exception.message(exception)}
    end
  end

  # --- Server ---

  def status, do: get("/")

  # --- My account ---

  def my_characters, do: get("/my/characters")
  def character(name), do: get("/characters/#{name}")
  def my_logs(name, opts \\ []), do: get("/my/logs/#{name}", opts)

  @doc """
  Create a new character. `name` must be 3-12 chars, `^[a-zA-Z0-9_-]+$`.
  `skin` is a required skin id (see the ArtifactsMMO docs for valid values).
  """
  def create_character(name, skin), do: post("/characters/create", %{name: name, skin: skin})

  # --- Character actions ---

  def move(name, x, y), do: post("/my/#{name}/action/move", %{x: x, y: y})
  def fight(name), do: post("/my/#{name}/action/fight")
  def gather(name), do: post("/my/#{name}/action/gathering")

  def craft(name, code, quantity \\ 1),
    do: post("/my/#{name}/action/crafting", %{code: code, quantity: quantity})

  def rest(name), do: post("/my/#{name}/action/rest")
  def equip(name, code, slot), do: post("/my/#{name}/action/equip", %{code: code, slot: slot})
  def unequip(name, slot), do: post("/my/#{name}/action/unequip", %{slot: slot})

  def use_item(name, code, quantity \\ 1),
    do: post("/my/#{name}/action/use", %{code: code, quantity: quantity})

  def recycle(name, code, quantity \\ 1),
    do: post("/my/#{name}/action/recycling", %{code: code, quantity: quantity})

  # --- Bank ---

  def bank_details, do: get("/my/bank")
  def bank_items(opts \\ []), do: get("/my/bank/items", opts)

  def bank_deposit(name, code, quantity),
    do: post("/my/#{name}/action/bank/deposit", %{code: code, quantity: quantity})

  def bank_withdraw(name, code, quantity),
    do: post("/my/#{name}/action/bank/withdraw", %{code: code, quantity: quantity})

  def bank_deposit_gold(name, quantity),
    do: post("/my/#{name}/action/bank/deposit/gold", %{quantity: quantity})

  def bank_withdraw_gold(name, quantity),
    do: post("/my/#{name}/action/bank/withdraw/gold", %{quantity: quantity})

  # --- Grand Exchange ---

  def ge_orders(opts \\ []), do: get("/my/grandexchange/orders", opts)
  def ge_history(opts \\ []), do: get("/my/grandexchange/history", opts)

  def ge_buy(name, code, quantity, price),
    do:
      post("/my/#{name}/action/grandexchange/buy", %{code: code, quantity: quantity, price: price})

  def ge_sell(name, code, quantity, price),
    do:
      post("/my/#{name}/action/grandexchange/sell", %{
        code: code,
        quantity: quantity,
        price: price
      })

  # --- Bank helpers ---

  def deposit_all(name) do
    case my_characters() do
      %{"data" => chars} when is_list(chars) ->
        char = Enum.find(chars, &(&1["name"] == name)) || %{}
        inventory = char["inventory"] || []

        results =
          inventory
          |> Enum.reject(&(is_nil(&1) or &1["code"] == nil or &1["quantity"] == 0))
          |> Enum.map(fn %{"code" => code, "quantity" => qty} ->
            bank_deposit(name, code, qty)
          end)

        %{"deposited" => length(results)}

      other ->
        %{"error" => "could not fetch character for deposit_all: #{inspect(other)}"}
    end
  end

  # --- Tasks ---

  def accept_task(name), do: post("/my/#{name}/action/task/new")
  def complete_task(name), do: post("/my/#{name}/action/task/complete")
  def task_exchange(name), do: post("/my/#{name}/action/task/exchange")

  # --- World data ---

  def maps(opts \\ []), do: get("/maps", opts)
  def items(opts \\ []), do: get("/items", opts)
  def item(code), do: get("/items/#{code}")
  def monsters(opts \\ []), do: get("/monsters", opts)
  def monster(code), do: get("/monsters/#{code}")
  def resources(opts \\ []), do: get("/resources", opts)
  def resource(code), do: get("/resources/#{code}")
end
