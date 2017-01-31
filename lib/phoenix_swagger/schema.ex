defmodule PhoenixSwagger.Schema do
  @moduledoc """
  Struct and helpers for swagger schema.

  Fields should reflect the swagger SchemaObject specification http://swagger.io/specification/#schemaObject
  """

  alias PhoenixSwagger.Schema

  defstruct [
    :'$ref',
    :format,
    :title,
    :description,
    :default,
    :multipleOf,
    :maximum,
    :exclusiveMaximum,
    :minimum,
    :exclusiveMinimum,
    :maxLength,
    :minLength,
    :pattern,
    :maxItems,
    :minItems,
    :uniqueItems,
    :enum,
    :maxProperties,
    :minProperties,
    :required,
    :type,
    :items,
    :allOf,
    :properties,
    :additionalProperties]

  @doc """
  Construct a schema reference, using name of definition in this swagger document,
    or a complete path.

  ## Example

      iex> PhoenixSwagger.Schema.ref(:User)
      %PhoenixSwagger.Schema{"$ref": "#/definitions/User"}

      iex> PhoenixSwagger.Schema.ref("../common/Error.json")
      %PhoenixSwagger.Schema{"$ref": "../common/Error.json"}
  """
  def ref(name) when is_atom(name) do
    %Schema{'$ref': "#/definitions/#{name}"}
  end
  def ref(path) when is_binary(path) do
    %Schema{'$ref': path}
  end

  @doc """
  Construct an array schema, where the array items schema is a ref to the given name.

  ## Example

      iex> PhoenixSwagger.Schema.array(:User)
      %PhoenixSwagger.Schema{
        items: %PhoenixSwagger.Schema{"$ref": "#/definitions/User"},
        type: :array
      }
  """
  def array(name) when is_atom(name) do
    %Schema{
      type: :array,
      items: ref(name)
    }
  end

  @doc """
  Sets the description for the schema.

  ## Example

      iex> %PhoenixSwagger.Schema{} |> PhoenixSwagger.Schema.description("A user")
      %PhoenixSwagger.Schema{description: "A user"}
  """
  def description(model = %Schema{}, desc) do
    %{model | description: desc}
  end

  @doc """
  Sets a property of the Schema.

  ## Example

      iex> alias PhoenixSwagger.Schema
      ...> %Schema{type: :object}
      ...> |> Schema.property(:name, :string, "Full name", required: true, maxLength: 256)
      ...> |> Schema.property(:phone_number, :string, "Phone Number", required: true)
      %PhoenixSwagger.Schema{
        properties: %{
          name: %PhoenixSwagger.Schema{
            description: "Full name",
            maxLength: 256,
            type: :string,
          },
          phone_number: %PhoenixSwagger.Schema{
            description: "Phone Number",
            type: :string
          }
        },
        required: [:phone_number, :name],
        type: :object
      }
  """
  def property(model, name, type, description, opts \\ [])
  def property(model = %Schema{}, name, type, description, opts) when is_atom(type) do
    property(model, name, %Schema{type: type}, description, opts)
  end
  def property(model = %Schema{}, name, type = %Schema{}, description, opts) do
    {required?, opts} = Keyword.pop(opts, :required)
    property_schema = struct!(type, [description: description] ++ opts)
    properties = (model.properties || %{}) |> Map.put(name, property_schema)
    model = %{model | properties: properties}
    if required?, do: required(model, name), else: model
  end

  @doc """
  Adds a property name to the list of required properties for a Schema.

    ## Example
    iex> alias PhoenixSwagger.Schema
    ...> %Schema{properties: %{phone_number: %Schema{type: :string}}}
    ...> |> Schema.required(:phone_number)
    %PhoenixSwagger.Schema{
      properties: %{
        phone_number: %PhoenixSwagger.Schema{
          type: :string
        }
      },
      required: [:phone_number]
    }
  """
  def required(model = %Schema{}, property_name) do
    %{model | required: [property_name | (model.required || [])]}
  end
end
