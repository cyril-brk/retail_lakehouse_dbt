{#
  Overriding dbt's built-in `generate_schema_name` macro.

  DEFAULT dbt behaviour concatenates the target schema + the custom schema, e.g.
  target schema "dbt_cyril" + model +schema "core" -> "dbt_cyril_core".

  Here we instead use the custom schema NAME DIRECTLY in non-default (prod)
  targets, and keep the prefixed behaviour in dev so multiple developers can
  share a catalog without clobbering each other:

    dev  -> <default_schema>_<custom>   (e.g. dbt_cyril_core)
    prod -> <custom>                    (e.g. core)

  This is the standard pattern for clean schema names in Unity Catalog.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
