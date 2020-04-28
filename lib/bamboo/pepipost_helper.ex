defmodule Bamboo.PepipostHelper do
  @moduledoc """
  Functions for using features specific to Pepipost
  (e.g. tagging).
  """

  alias Bamboo.Email

  @doc """
  Add a tags to outgoing email to help categorize traffic based on some
  criteria. Tags must be list of string.

  More details can be found in the [Pepipost documentation](https://pepipost.docs.stoplight.io/faqs/what-is-x-tags)

  ## Example

      email
      |> PepipostHelper.tags(["welcome-email"])
  """
  def tags(email, tags) when is_list(tags) do
    Email.put_private(email, :tags, tags)
  end

  @doc """
  Add an identifier to uniquely identify the email.

  More details can be found in the [Pepipost documentation](https://pepipost.docs.stoplight.io/faqs/what-is-x-apiheader)

  ## Example

      email
      |> PepipostHelper.x_apiheader("ID0001")
  """
  def x_apiheader(email, id) do
    Email.put_private(email, :x_apiheader, id)
  end
end
