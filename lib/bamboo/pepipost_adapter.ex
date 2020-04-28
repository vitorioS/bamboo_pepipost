defmodule Bamboo.PepipostAdapter do
  @service_name "Pepipost"
  @default_base_uri "https://api.pepipost.com"
  @behaviour Bamboo.Adapter

  alias Bamboo.{Email, Attachment, AdapterHelper}
  import Bamboo.ApiError

  @doc false
  def handle_config(config) do
    config
    |> Map.put(:api_key, get_setting(config, :api_key))
    |> Map.put_new(:base_uri, base_uri())
  end

  defp base_uri() do
    Application.get_env(:bamboo, :pepipost_base_uri, @default_base_uri)
  end

  defp get_setting(config, key) do
    config[key]
    |> case do
      {:system, var} ->
        System.get_env(var)

      value ->
        value
    end
    |> case do
      value when value in [nil, ""] ->
        raise_missing_setting_error(config, key)

      value ->
        value
    end
  end

  defp raise_missing_setting_error(config, setting) do
    raise ArgumentError, """
    There was no #{setting} set for the Pepipost adapter.

    * Here are the config options that were passed in:

    #{inspect(config)}
    """
  end

  def deliver(email, config) do
    body = to_pepipost_body(email)
    config = handle_config(config)
    opts = Application.get_env(:bamboo, :hackney_opts, [])

    case :hackney.post(full_uri(config), headers(config), body, [:with_body | opts]) do
      {:ok, status, _headers, response} when status > 299 ->
        raise_api_error(@service_name, response, body)

      {:ok, status, headers, response} ->
        %{status_code: status, headers: headers, body: response}

      {:error, reason} ->
        raise_api_error(inspect(reason))
    end
  end

  @doc false
  def supports_attachments?, do: true

  defp full_uri(config) do
    config.base_uri <> "/v2/sendEmail"
  end

  defp headers(config) do
    [{"Content-Type", "application/json"}, {"api_key", "#{config.api_key}"}]
  end

  defp to_pepipost_body(email) do
    %{"personalizations" => build_personalizations(email)}
    |> put_from(email)
    |> put_subject(email)
    |> put_html(email)
    |> put_text(email)
    |> put_attachments(email)
    |> put_tag(email)
    |> Jason.encode_to_iodata!()
  end

  defp build_personalizations(email) do
    %{}
    |> put_to(email)
    |> put_cc(email)
    |> put_bcc(email)
    |> put_x_api_header(email)
    |> List.wrap()
  end

  defp put_to(personalization, %Email{to: to}) do
    recipients =
      normalize_address(to)
      |> Enum.map(fn
        {nil, address} -> %{"email" => address}
        {name, address} -> %{"name" => name, "email" => address}
      end)

    Map.put(personalization, :recipient, recipients)
  end

  defp put_bcc(personalization, %Email{bcc: bcc}) do
    addresses = normalize_address(bcc) |> Enum.map(&elem(&1, 1))
    Map.put(personalization, :recipient_bcc, addresses)
  end

  defp put_cc(personalization, %Email{cc: cc}) do
    addresses = normalize_address(cc) |> Enum.map(&elem(&1, 1))
    Map.put(personalization, :recipient_cc, addresses)
  end

  defp put_x_api_header(personalization, %Email{private: %{:x_apiheader => x_apiheader}}),
    do: Map.put(personalization, :"x-apiheader", x_apiheader)

  defp put_x_api_header(personalization, %Email{}), do: personalization

  defp put_from(body, %Email{from: from}) do
    from =
      case normalize_address(from) do
        address when is_binary(address) -> %{"fromEmail" => address}
        {name, address} when name in ["", nil] -> %{"fromEmail" => address}
        {name, address} -> %{"fromName" => String.trim(name, "\""), "fromEmail" => address}
      end

    Map.put(body, :from, from)
  end

  defp put_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp put_text(body, %Email{text_body: text_body}) when text_body in [nil, ""], do: body

  defp put_text(_body, %Email{text_body: _}),
    do: raise_api_error("Pepipost does not support text_body")

  defp put_html(body, %Email{html_body: nil}), do: body
  defp put_html(body, %Email{html_body: html_body}), do: Map.put(body, :content, html_body)

  defp put_tag(body, %Email{private: %{tags: tags}}) do
    Map.put(body, :tags, Enum.join(tags, ","))
  end

  defp put_tag(body, %Email{}), do: body

  defp put_attachments(body, %Email{attachments: []}), do: body

  defp put_attachments(body, %Email{attachments: attachments}) do
    attachment_data = attachments |> Enum.map(&prepare_file(&1))
    Map.put(body, :attachments, attachment_data)
  end

  defp prepare_file(%Attachment{} = attachment) do
    %{
      "fileName" => attachment.filename,
      "fileContent" => Base.encode64(attachment.data)
    }
  end

  defp normalize_address(address) when is_binary(address), do: {nil, address}
  defp normalize_address({name, address}) when name in [nil, ""], do: {nil, address}
  defp normalize_address({name, address}), do: {name, address}

  defp normalize_address(addresses) when is_list(addresses) do
    Enum.map(addresses, &normalize_address/1)
  end
end
