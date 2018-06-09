defmodule PhoenixSwagger.JsonApi do
  @moduledoc """
  This module defines a DSL for defining swagger definitions in a JSON-API conformant format.

  ## Examples
      use PhoenixSwagger

      def swagger_definitions do
        %{
          UserResource: JsonApi.resource do
            description "A user that may have one or more supporter pages."
            attributes do
              phone :string, "Users phone number"
              full_name :string, "Full name"
              user_updated_at :string, "Last update timestamp UTC", format: "ISO-8601"
              user_created_at :string, "First created timestamp UTC"
              email :string, "Email", required: true
              birthday :string, "Birthday in YYYY-MM-DD format"
              address Schema.ref(:Address), "Users address"
            end
            link :self, "The link to this user resource"
            relationship :posts
          end,
          Users: JsonApi.page(:UserResource),
          User: JsonApi.single(:UserResource)
        }
      end

      swagger_path :index do
        get "/api/v1/users"
        paging size: "page[size]", number: "page[number]"
        response 200, "OK", Schema.ref(:Users)
      end
  """

  alias PhoenixSwagger.Schema
  require PhoenixSwagger

  @doc """
  Defines a schema for a top level json-api document with an array of resources as primary data.
  The given `resource` should be the name of a JSON-API resource defined with the `resource/1` macro
  """
  def page(resource) do
    %Schema {
      type: :object,
      description: "A page of [#{resource}](##{resource |> to_string |> String.downcase}) results",
      properties: %{
        meta: %Schema {
          type: :object,
          properties: %{
            "total-pages": %Schema {
              type: :integer,
              description: "The total number of pages available"
            },
            "total-count": %Schema {
              type: :integer,
              description: "The total number of items available"
            }
          }
        },
        links: %Schema {
          type:  :object,
          properties: %{
            self: %Schema {
              type:  :string,
              description:  "Link to this page of results"
            },
            prev: %Schema {
              type:  :string,
              description:  "Link to the previous page of results"
            },
            next: %Schema {
              type:  :string,
              description:  "Link to the next page of results"
            },
            last: %Schema {
              type:  :string,
              description:  "Link to the last page of results"
            },
            first: %Schema {
              type:  :string,
              description:  "Link to the first page of results"
            }
          }
        },
        data: %Schema {
          type:  :array,
          description:  "Content with [#{resource}](##{resource |> to_string |> String.downcase}) objects",
          items: %Schema {
            "$ref": "#/definitions/#{resource}"
          }
        }
      },
      required:  [:data]
    }
    |> PhoenixSwagger.to_json()
  end

  @doc """
  Defines a schema for a top level json-api document with a single primary data resource.
  The given `resource` should be the name of a JSON-API resource defined with the `resource/1` macro
  """
  def single(resource) do
    %Schema {
      type: :object,
      description: "A JSON-API document with a single [#{resource}](##{resource |> to_string |> String.downcase}) resource",
      properties: %{
        links: %Schema {
          type:  :object,
          properties: %{
            self: %Schema {
              type:  :string,
              description:  "the link that generated the current response document."
            }
          }
        },
        data: %Schema {
          "$ref": "#/definitions/#{resource}"
        },
        included: %Schema {
          type: :array,
          description: "Included resources",
          items: %Schema {
            type:  :object,
            properties: %{
              type: %Schema{type: :string, description: "The JSON-API resource type"},
              id: %Schema{type: :string, description: "The JSON-API resource ID"},
            }
          }
        }
      },
      required:  [:data]
    }
    |> PhoenixSwagger.to_json()
  end

  @doc """
  Defines a schema for a JSON-API resource, without the enclosing top-level document.
  """
  defmacro resource([do: {:__block__, _, exprs}]) do
    schema = quote do
      %Schema {
        type: :object,
        properties: %{
          type: %Schema{type: :string, description: "The JSON-API resource type"},
          id: %Schema{type: :string, description: "The JSON-API resource ID"},
          relationships: %Schema{type: :object, properties: %{}},
          links: %Schema{type: :object, properties: %{}},
          attributes: %Schema{
            type: :object,
            properties: %{}
          }
        }
      }
    end

    body = Enum.reduce(exprs, schema, fn expr, acc ->
      quote do unquote(acc) |> unquote(expr) end
    end)

    quote do
      (fn ->
        import PhoenixSwagger.JsonApi
        import PhoenixSwagger.Schema
        unquote(body)
        |> PhoenixSwagger.to_json()
      end).()
    end
  end

  @doc """
  Defines a block of attributes for a JSON-API resource.
  Within this block, each function call will be translated into a
  call to the `PhoenixSwagger.JsonApi.attribute` function.

  ## Example

      description("A User")
      attributes do
        name :string, "Full name of the user", required: true
        dateOfBirth :string, "Date of Birth", format: "ISO-8601", required: false
      end

  translates to:

      description("A User")
      |> attribute(:name, :string, "Full name of the user", required: true)
      |> attribute(:dateOfBirth, :string, "Date of Birth", format: "ISO-8601", required: false)
  """
  defmacro attributes(model, block) do
    attrs = case block do
      [do: {:__block__, _, attrs}] -> attrs
      [do: attr] -> [attr]
    end

    attrs
    |> Enum.map(fn {name, line, args} -> {:attribute, line, [name | args]} end)
    |> Enum.reduce(model, fn next, pipeline ->
         quote do
           unquote(pipeline) |> unquote(next)
         end
       end)
  end

  @doc """
  Defines an attribute in a JSON-API schema.

  Name, type and description are accepted as positional arguments, but any other
  schema properties can be set through the trailing keyword arguments list.
  As a convenience, required: true can be passed in the keyword args, causing the
   name of this attribute to be added to the "required" list of the attributes schema.
  """
  def attribute(model, name, type, description, opts \\ [])
  def attribute(model, name, type, description, opts) when is_atom(type) or is_list(type) do
    attribute(model, name, %Schema{type: type}, description, opts)
  end
  def attribute(model = %Schema{}, name, type = %Schema{}, description, opts) do
    {required?, opts} = Keyword.pop(opts, :required)
    attr_schema = struct!(type, [description: description] ++ opts)
    model = put_in(model.properties.attributes.properties[name], attr_schema)

    required = case {model.properties.attributes.required, required?} do
      {nil, true} -> [name]
      {r, true} -> r ++ [name]
      {r, _} -> r
    end

    put_in model.properties.attributes.required, required
  end

  @doc """
  Defines a link with name and description
  """
  def link(model = %Schema{}, name, description) do
    put_in(
      model.properties.links.properties[name],
      %Schema{type: :string, description: description}
    )
  end

  @doc """
  Defines a relationship
  Optionally can pass `type: :has_many` or `type: :has_one` to determine
  whether to structure the relationship as an object or array.
  Defaults to `:has_one`
  """
  @spec relationship(%Schema{}, name :: atom, [option]) :: %Schema{}
        when option: {:type, relationship_type} | {:nullable, boolean},
             relationship_type: :has_one | :has_many
  def relationship(model = %Schema{}, name, opts \\ []) do
    type = opts[:type] || :has_one

    put_in(model.properties.relationships.properties[name], %Schema{
      type: :object,
      properties: %{
        links: %Schema{
          type: :object,
          properties: %{
            self: %Schema{type: :string, description: "Relationship link for #{name}"},
            related: %Schema{type: :string, description: "Related #{name} link"}
          }
        },
        data: relationship_data(type, name) |> Schema.nullable(opts[:nullable])
      }
    })
  end

  defp relationship_data(:has_one, name) do
    %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Related #{name} resource id"},
        type: %Schema{type: :string, description: "Type of related #{name} resource"}
      }
    }
  end

  defp relationship_data(:has_many, name) do
    %Schema{
      type: :array,
      items: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :string, description: "Related #{name} resource id"},
          type: %Schema{type: :string, description: "Type of related #{name} resource"}
        }
      }
    }
  end
end
